// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Top-level debug module (DM)
//
// This module implements the RISC-V debug specification version 0.13,
//
// This toplevel wraps the PULP debug module available from
// https://github.com/pulp-platform/riscv-dbg to match the needs of
// the TL-UL-based lowRISC chip design.

`include "prim_assert.sv"

module rv_dm
  import rv_dm_reg_pkg::*;
#(
  parameter logic [NumAlerts-1:0] AlertAsyncOn = {NumAlerts{1'b1}},
  parameter logic [31:0]          IdcodeValue  = 32'h 0000_0001
) (
  input  logic                clk_i,       // clock
  input  logic                rst_ni,      // asynchronous reset active low, connect PoR
                                           // here, not the system reset
  // SEC_CM: LC_HW_DEBUG_EN.INTERSIG.MUBI
  input  lc_ctrl_pkg::lc_tx_t lc_hw_debug_en_i, // Debug module lifecycle enable/disable
  input  prim_mubi_pkg::mubi4_t scanmode_i,
  input                       scan_rst_ni,
  output logic                ndmreset_req_o,  // non-debug module reset
  output logic                dmactive_o,  // debug module is active
  output logic [NrHarts-1:0]  debug_req_o, // async debug request
  input  logic [NrHarts-1:0]  unavailable_i, // communicate whether the hart is unavailable
                                             // (e.g.: power down)

  // bus device for comportable CSR access
  input  tlul_pkg::tl_h2d_t  regs_tl_d_i,
  output tlul_pkg::tl_d2h_t  regs_tl_d_o,

  // bus device with debug memory, for an execution based technique
  input  tlul_pkg::tl_h2d_t  rom_tl_d_i,
  output tlul_pkg::tl_d2h_t  rom_tl_d_o,

  // bus host, for system bus accesses
  output tlul_pkg::tl_h2d_t  sba_tl_h_o,
  input  tlul_pkg::tl_d2h_t  sba_tl_h_i,

  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,

  input  jtag_pkg::jtag_req_t jtag_i,
  output jtag_pkg::jtag_rsp_t jtag_o
);

  import prim_mubi_pkg::mubi4_bool_to_mubi;
  import prim_mubi_pkg::mubi4_test_true_strict;
  import lc_ctrl_pkg::lc_tx_test_true_strict;

  `ASSERT_INIT(paramCheckNrHarts, NrHarts > 0)

  // Currently only 32 bit busses are supported by our TL-UL IP
  localparam int BusWidth = 32;
  // all harts have contiguous IDs
  localparam logic [NrHarts-1:0] SelectableHarts = {NrHarts{1'b1}};

  // CSR Nodes
  tlul_pkg::tl_h2d_t rom_tl_win_h2d;
  tlul_pkg::tl_d2h_t rom_tl_win_d2h;
  rv_dm_reg_pkg::rv_dm_regs_reg2hw_t regs_reg2hw;
  logic regs_intg_error, rom_intg_error;

  rv_dm_regs_reg_top u_reg_regs (
    .clk_i,
    .rst_ni,
    .tl_i      (regs_tl_d_i    ),
    .tl_o      (regs_tl_d_o    ),
    .reg2hw    (regs_reg2hw    ),
    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(regs_intg_error),
    .devmode_i (1'b1           )
  );

  rv_dm_rom_reg_top u_reg_rom (
    .clk_i,
    .rst_ni,
    .tl_i      (rom_tl_d_i    ),
    .tl_o      (rom_tl_d_o    ),
    .tl_win_o  (rom_tl_win_h2d),
    .tl_win_i  (rom_tl_win_d2h),
    .intg_err_o(),
    .devmode_i (1'b1          )
  );

  // Alerts
  logic [NumAlerts-1:0] alert_test, alerts;

  assign alerts[0] = regs_intg_error | rom_intg_error;

  assign alert_test = {
    regs_reg2hw.alert_test.q &
    regs_reg2hw.alert_test.qe
  };

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(AlertAsyncOn[i]),
      .IsFatal(1'b1)
    ) u_prim_alert_sender (
      .clk_i,
      .rst_ni,
      .alert_test_i  ( alert_test[i] ),
      .alert_req_i   ( alerts[0]     ),
      .alert_ack_o   (               ),
      .alert_state_o (               ),
      .alert_rx_i    ( alert_rx_i[i] ),
      .alert_tx_o    ( alert_tx_o[i] )
    );
  end

  // debug enable gating
  typedef enum logic [3:0] {
    EnFetch,
    EnRom,
    EnSba,
    EnDebugReq,
    EnResetReq,
    EnDmiReq,
    EnJtagIn,
    EnJtagOut,
    EnLastPos
  } rv_dm_en_e;

  lc_ctrl_pkg::lc_tx_t [EnLastPos-1:0] lc_hw_debug_en;
  prim_lc_sync #(
    .NumCopies(int'(EnLastPos))
  ) u_lc_en_sync (
    .clk_i,
    .rst_ni,
    .lc_en_i(lc_hw_debug_en_i),
    .lc_en_o(lc_hw_debug_en)
  );


  // Debug CSRs
  dm::hartinfo_t [NrHarts-1:0]      hartinfo;
  logic [NrHarts-1:0]               halted;
  // logic [NrHarts-1:0]               running;
  logic [NrHarts-1:0]               resumeack;
  logic [NrHarts-1:0]               haltreq;
  logic [NrHarts-1:0]               resumereq;
  logic                             clear_resumeack;
  logic                             cmd_valid;
  dm::command_t                     cmd;

  logic                             cmderror_valid;
  dm::cmderr_e                      cmderror;
  logic                             cmdbusy;
  logic [dm::ProgBufSize-1:0][31:0] progbuf;
  logic [dm::DataCount-1:0][31:0]   data_csrs_mem;
  logic [dm::DataCount-1:0][31:0]   data_mem_csrs;
  logic                             data_valid;
  logic [19:0]                      hartsel;
  // System Bus Access Module
  logic [BusWidth-1:0]              sbaddress_csrs_sba;
  logic [BusWidth-1:0]              sbaddress_sba_csrs;
  logic                             sbaddress_write_valid;
  logic                             sbreadonaddr;
  logic                             sbautoincrement;
  logic [2:0]                       sbaccess;
  logic                             sbreadondata;
  logic [BusWidth-1:0]              sbdata_write;
  logic                             sbdata_read_valid;
  logic                             sbdata_write_valid;
  logic [BusWidth-1:0]              sbdata_read;
  logic                             sbdata_valid;
  logic                             sbbusy;
  logic                             sberror_valid;
  logic [2:0]                       sberror;

  dm::dmi_req_t  dmi_req;
  dm::dmi_resp_t dmi_rsp;
  logic dmi_req_valid, dmi_req_ready;
  logic dmi_rsp_valid, dmi_rsp_ready;
  logic dmi_rst_n;
  logic testmode;

  // Decode multibit scanmode enable
  assign testmode = mubi4_test_true_strict(scanmode_i);

  // static debug hartinfo
  localparam dm::hartinfo_t DebugHartInfo = '{
    zero1:      '0,
    nscratch:   2, // Debug module needs at least two scratch regs
    zero0:      0,
    dataaccess: 1'b1, // data registers are memory mapped in the debugger
    datasize:   dm::DataCount,
    dataaddr:   dm::DataAddr
  };
  for (genvar i = 0; i < NrHarts; i++) begin : gen_dm_hart_ctrl
    assign hartinfo[i] = DebugHartInfo;
  end

  logic reset_req_en;
  logic ndmreset_req;
  // SEC_CM: DM_EN.CTRL.LC_GATED
  assign reset_req_en = lc_tx_test_true_strict(lc_hw_debug_en[EnResetReq]);
  assign ndmreset_req_o = ndmreset_req & reset_req_en;

  logic dmi_en;
  // SEC_CM: DM_EN.CTRL.LC_GATED
  assign dmi_en = lc_tx_test_true_strict(lc_hw_debug_en[EnDmiReq]);

  dm_csrs #(
    .NrHarts(NrHarts),
    .BusWidth(BusWidth),
    .SelectableHarts(SelectableHarts)
  ) i_dm_csrs (
    .clk_i                   ( clk_i                 ),
    .rst_ni                  ( rst_ni                ),
    .testmode_i              ( testmode              ),
    .dmi_rst_ni              ( dmi_rst_n             ),
    .dmi_req_valid_i         ( dmi_req_valid & dmi_en),
    .dmi_req_ready_o         ( dmi_req_ready         ),
    .dmi_req_i               ( dmi_req               ),
    .dmi_resp_valid_o        ( dmi_rsp_valid         ),
    .dmi_resp_ready_i        ( dmi_rsp_ready & dmi_en),
    .dmi_resp_o              ( dmi_rsp               ),
    .ndmreset_o              ( ndmreset_req          ),
    .dmactive_o              ( dmactive_o            ),
    .hartsel_o               ( hartsel               ),
    .hartinfo_i              ( hartinfo              ),
    .halted_i                ( halted                ),
    .unavailable_i,
    .resumeack_i             ( resumeack             ),
    .haltreq_o               ( haltreq               ),
    .resumereq_o             ( resumereq             ),
    .clear_resumeack_o       ( clear_resumeack       ),
    .cmd_valid_o             ( cmd_valid             ),
    .cmd_o                   ( cmd                   ),
    .cmderror_valid_i        ( cmderror_valid        ),
    .cmderror_i              ( cmderror              ),
    .cmdbusy_i               ( cmdbusy               ),
    .progbuf_o               ( progbuf               ),
    .data_i                  ( data_mem_csrs         ),
    .data_valid_i            ( data_valid            ),
    .data_o                  ( data_csrs_mem         ),
    .sbaddress_o             ( sbaddress_csrs_sba    ),
    .sbaddress_i             ( sbaddress_sba_csrs    ),
    .sbaddress_write_valid_o ( sbaddress_write_valid ),
    .sbreadonaddr_o          ( sbreadonaddr          ),
    .sbautoincrement_o       ( sbautoincrement       ),
    .sbaccess_o              ( sbaccess              ),
    .sbreadondata_o          ( sbreadondata          ),
    .sbdata_o                ( sbdata_write          ),
    .sbdata_read_valid_o     ( sbdata_read_valid     ),
    .sbdata_write_valid_o    ( sbdata_write_valid    ),
    .sbdata_i                ( sbdata_read           ),
    .sbdata_valid_i          ( sbdata_valid          ),
    .sbbusy_i                ( sbbusy                ),
    .sberror_valid_i         ( sberror_valid         ),
    .sberror_i               ( sberror               )
  );

  logic                   host_req;
  logic   [BusWidth-1:0]  host_add;
  logic                   host_we;
  logic   [BusWidth-1:0]  host_wdata;
  logic [BusWidth/8-1:0]  host_be;
  logic                   host_gnt;
  logic                   host_r_valid;
  logic   [BusWidth-1:0]  host_r_rdata;
  logic                   host_r_err;

  dm_sba #(
    .BusWidth(BusWidth)
  ) i_dm_sba (
    .clk_i                   ( clk_i                 ),
    .rst_ni                  ( rst_ni                ),
    .master_req_o            ( host_req              ),
    .master_add_o            ( host_add              ),
    .master_we_o             ( host_we               ),
    .master_wdata_o          ( host_wdata            ),
    .master_be_o             ( host_be               ),
    .master_gnt_i            ( host_gnt              ),
    .master_r_valid_i        ( host_r_valid          ),
    .master_r_rdata_i        ( host_r_rdata          ),
    .dmactive_i              ( dmactive_o            ),
    .sbaddress_i             ( sbaddress_csrs_sba    ),
    .sbaddress_o             ( sbaddress_sba_csrs    ),
    .sbaddress_write_valid_i ( sbaddress_write_valid ),
    .sbreadonaddr_i          ( sbreadonaddr          ),
    .sbautoincrement_i       ( sbautoincrement       ),
    .sbaccess_i              ( sbaccess              ),
    .sbreadondata_i          ( sbreadondata          ),
    .sbdata_i                ( sbdata_write          ),
    .sbdata_read_valid_i     ( sbdata_read_valid     ),
    .sbdata_write_valid_i    ( sbdata_write_valid    ),
    .sbdata_o                ( sbdata_read           ),
    .sbdata_valid_o          ( sbdata_valid          ),
    .sbbusy_o                ( sbbusy                ),
    .sberror_valid_o         ( sberror_valid         ),
    .sberror_o               ( sberror               )
  );

  // SEC_CM: DM_EN.CTRL.LC_GATED
  tlul_pkg::tl_h2d_t  sba_tl_h_o_int;
  tlul_pkg::tl_d2h_t  sba_tl_h_i_int;
  tlul_lc_gate #(
    .NumGatesPerDirection(2)
  ) u_tlul_lc_gate_sba (
    .clk_i,
    .rst_ni,
    .tl_h2d_i(sba_tl_h_o_int),
    .tl_d2h_o(sba_tl_h_i_int),
    .tl_h2d_o(sba_tl_h_o),
    .tl_d2h_i(sba_tl_h_i),
    .lc_en_i (lc_hw_debug_en[EnSba])
  );

  tlul_adapter_host #(
    .EnableDataIntgGen(1),
    .MAX_REQS(1)
  ) tl_adapter_host_sba (
    .clk_i,
    .rst_ni,
    .req_i        (host_req),
    .instr_type_i (prim_mubi_pkg::MuBi4False),
    .gnt_o        (host_gnt),
    .addr_i       (host_add),
    .we_i         (host_we),
    .wdata_i      (host_wdata),
    .wdata_intg_i ('0),
    .be_i         (host_be),
    .valid_o      (host_r_valid),
    .rdata_o      (host_r_rdata),
    .rdata_intg_o (),
    .err_o        (host_r_err),
    // Note: This bus integrity error is not connected to the alert due to a few reasons:
    // 1) the SBA module is not active in production life cycle states.
    // 2) there may be value in being able to accept incoming transactions with integrity
    //    errors during test / debug life cycle states so that the system can be debugged
    //    without triggering alerts.
    .intg_err_o   (),
    .tl_o         (sba_tl_h_o_int),
    .tl_i         (sba_tl_h_i_int)
  );

  // DBG doesn't handle error responses - we silently drop it.

  logic unused_host_r_err;
  assign unused_host_r_err = host_r_err;

  localparam int unsigned AddressWidthWords = BusWidth - $clog2(BusWidth/8);

  logic                         req;
  logic                         we;
  logic [BusWidth/8-1:0]        be;
  logic   [BusWidth-1:0]        wmask;
  logic   [BusWidth-1:0]        wdata;
  logic   [BusWidth-1:0]        rdata;
  logic                         rvalid;

  logic [BusWidth-1:0]          addr_b;
  logic [AddressWidthWords-1:0] addr_w;

  // Bit-write masks are byte-aligned, so we can reduce them to byte-write enables here.
  for (genvar k = 0; k < BusWidth/8; k++) begin : gen_byte_write
    assign be[k] = &wmask[8*k +: 8];
  end

  assign addr_b = {addr_w, {$clog2(BusWidth/8){1'b0}}};

  logic debug_req_en;
  logic debug_req;
  // SEC_CM: DM_EN.CTRL.LC_GATED
  assign debug_req_en = lc_tx_test_true_strict(lc_hw_debug_en[EnDebugReq]);
  assign debug_req_o = debug_req & debug_req_en;


  dm_mem #(
    .NrHarts(NrHarts),
    .BusWidth(BusWidth),
    .SelectableHarts(SelectableHarts),
    // The debug module provides a simplified ROM for systems that map the debug ROM to offset 0x0
    // on the system bus. In that case, only one scratch register has to be implemented in the core.
    // However, we require that the DM can be placed at arbitrary offsets in the system, which
    // requires the generalized debug ROM implementation and two scratch registers. We hence set
    // this parameter to a non-zero value (inside dm_mem, this just feeds into a comparison with 0).
    .DmBaseAddress(1)
  ) i_dm_mem (
    .clk_i                   ( clk_i                 ),
    .rst_ni                  ( rst_ni                ),
    .debug_req_o             ( debug_req             ),
    .hartsel_i               ( hartsel               ),
    .haltreq_i               ( haltreq               ),
    .resumereq_i             ( resumereq             ),
    .clear_resumeack_i       ( clear_resumeack       ),
    .halted_o                ( halted                ),
    .resuming_o              ( resumeack             ),
    .cmd_valid_i             ( cmd_valid             ),
    .cmd_i                   ( cmd                   ),
    .cmderror_valid_o        ( cmderror_valid        ),
    .cmderror_o              ( cmderror              ),
    .cmdbusy_o               ( cmdbusy               ),
    .progbuf_i               ( progbuf               ),
    .data_i                  ( data_csrs_mem         ),
    .data_o                  ( data_mem_csrs         ),
    .data_valid_o            ( data_valid            ),
    .req_i                   ( req                   ),
    .we_i                    ( we                    ),
    .addr_i                  ( addr_b                ),
    .wdata_i                 ( wdata                 ),
    .be_i                    ( be                    ),
    .rdata_o                 ( rdata                 )
  );

  // Gating of JTAG signals
  jtag_pkg::jtag_req_t jtag_in_int;
  jtag_pkg::jtag_rsp_t jtag_out_int;

  assign jtag_in_int = (lc_tx_test_true_strict(lc_hw_debug_en[EnJtagIn]))  ? jtag_i       : '0;
  assign jtag_o      = (lc_tx_test_true_strict(lc_hw_debug_en[EnJtagOut])) ? jtag_out_int : '0;

  // Bound-in DPI module replaces the TAP
`ifndef DMIDirectTAP

  logic tck_muxed;
  logic trst_n_muxed;
  prim_clock_mux2 #(
    .NoFpgaBufG(1'b1)
  ) u_prim_clock_mux2 (
    .clk0_i(jtag_in_int.tck),
    .clk1_i(clk_i),
    .sel_i (testmode),
    .clk_o (tck_muxed)
  );

  prim_clock_mux2 #(
    .NoFpgaBufG(1'b1)
  ) u_prim_rst_n_mux2 (
    .clk0_i(jtag_in_int.trst_n),
    .clk1_i(scan_rst_ni),
    .sel_i (testmode),
    .clk_o (trst_n_muxed)
  );

  // JTAG TAP
  dmi_jtag #(
    .IdcodeValue    (IdcodeValue)
  ) dap (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .testmode_i       (testmode),

    .dmi_rst_no       (dmi_rst_n),
    .dmi_req_o        (dmi_req),
    .dmi_req_valid_o  (dmi_req_valid),
    .dmi_req_ready_i  (dmi_req_ready & dmi_en),

    .dmi_resp_i       (dmi_rsp      ),
    .dmi_resp_ready_o (dmi_rsp_ready),
    .dmi_resp_valid_i (dmi_rsp_valid & dmi_en),

    //JTAG
    .tck_i            (tck_muxed),
    .tms_i            (jtag_in_int.tms),
    .trst_ni          (trst_n_muxed),
    .td_i             (jtag_in_int.tdi),
    .td_o             (jtag_out_int.tdo),
    .tdo_oe_o         (jtag_out_int.tdo_oe)
  );
`endif

  // SEC_CM: DM_EN.CTRL.LC_GATED
  tlul_pkg::tl_h2d_t rom_tl_win_h2d_gated;
  tlul_pkg::tl_d2h_t rom_tl_win_d2h_gated;
  tlul_lc_gate #(
    .NumGatesPerDirection(2)
  ) u_tlul_lc_gate_rom (
    .clk_i,
    .rst_ni,
    .tl_h2d_i(rom_tl_win_h2d),
    .tl_d2h_o(rom_tl_win_d2h),
    .tl_h2d_o(rom_tl_win_h2d_gated),
    .tl_d2h_i(rom_tl_win_d2h_gated),
    .lc_en_i (lc_hw_debug_en[EnRom])
  );

  prim_mubi_pkg::mubi4_t en_ifetch;
  // SEC_CM: DM_EN.CTRL.LC_GATED, EXEC.CTRL.MUBI
  assign en_ifetch = mubi4_bool_to_mubi(lc_tx_test_true_strict(lc_hw_debug_en[EnFetch]));

  tlul_adapter_sram #(
    .SramAw(AddressWidthWords),
    .SramDw(BusWidth),
    .Outstanding(1),
    .ByteAccess(1),
    .CmdIntgCheck(1),
    .EnableRspIntgGen(1)
  ) tl_adapter_device_mem (
    .clk_i,
    .rst_ni,
    // SEC_CM: EXEC.CTRL.MUBI
    .en_ifetch_i (en_ifetch),
    .req_o       (req),
    .req_type_o  (),
    .gnt_i       (1'b1),
    .we_o        (we),
    .addr_o      (addr_w),
    .wdata_o     (wdata),
    .wmask_o     (wmask),
    // SEC_CM: BUS.INTEGRITY
    .intg_error_o(rom_intg_error),
    .rdata_i     (rdata),
    .rvalid_i    (rvalid),
    .rerror_i    ('0),

    .tl_o        (rom_tl_win_d2h_gated),
    .tl_i        (rom_tl_win_h2d_gated)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= '0;
    end else begin
      rvalid <= req & ~we;
    end
  end

  `ASSERT_KNOWN(TlRegsDValidKnown_A, regs_tl_d_o.d_valid)
  `ASSERT_KNOWN(TlRegsAReadyKnown_A, regs_tl_d_o.a_ready)

  `ASSERT_KNOWN(TlRomDValidKnown_A, rom_tl_d_o.d_valid)
  `ASSERT_KNOWN(TlRomAReadyKnown_A, rom_tl_d_o.a_ready)

  `ASSERT_KNOWN(TlSbaAValidKnown_A, sba_tl_h_o.a_valid)
  `ASSERT_KNOWN(TlSbaDReadyKnown_A, sba_tl_h_o.d_ready)

  `ASSERT_KNOWN(NdmresetOKnown_A, ndmreset_req_o)
  `ASSERT_KNOWN(DmactiveOKnown_A, dmactive_o)
  `ASSERT_KNOWN(DebugReqOKnown_A, debug_req_o)

  // JTAG TDO is driven by an inverted TCK in dmi_jtag_tap.sv
  `ASSERT_KNOWN(JtagRspOTdoKnown_A, jtag_o.tdo, !jtag_i.tck, !jtag_i.trst_n)
  `ASSERT_KNOWN(JtagRspOTdoOeKnown_A, jtag_o.tdo_oe, !jtag_i.tck, !jtag_i.trst_n)

endmodule
