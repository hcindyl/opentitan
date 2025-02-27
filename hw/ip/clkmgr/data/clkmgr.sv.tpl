// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// The overall clock manager

<%
from topgen.lib import Name
%>\

`include "prim_assert.sv"

  module clkmgr
    import clkmgr_pkg::*;
    import clkmgr_reg_pkg::*;
    import lc_ctrl_pkg::lc_tx_t;
    import prim_mubi_pkg::mubi4_t;
#(
  parameter logic [NumAlerts-1:0] AlertAsyncOn = {NumAlerts{1'b1}}
) (
  // Primary module control clocks and resets
  // This drives the register interface
  input clk_i,
  input rst_ni,
  input rst_shadowed_ni,

  // System clocks and resets
  // These are the source clocks for the system
% for src in clocks.srcs.values():
  input clk_${src.name}_i,
  input rst_${src.name}_ni,
% endfor

  // Resets for derived clocks
  // clocks are derived locally
% for src_name in clocks.derived_srcs:
  input rst_${src_name}_ni,
% endfor

  // Bus Interface
  input tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,

  // pwrmgr interface
  input pwrmgr_pkg::pwr_clk_req_t pwr_i,
  output pwrmgr_pkg::pwr_clk_rsp_t pwr_o,

  // dft interface
  input prim_mubi_pkg::mubi4_t scanmode_i,

  // idle hints
  // SEC_CM: IDLE.INTERSIG.MUBI
  input prim_mubi_pkg::mubi4_t [${len(typed_clocks.hint_clks)-1}:0] idle_i,

  // life cycle state output
  // SEC_CM: LC_CTRL.INTERSIG.MUBI
  input lc_tx_t lc_hw_debug_en_i,

  // clock bypass control with lc_ctrl
  // SEC_CM: LC_CTRL_CLK_HANDSHAKE.INTERSIG.MUBI
  input lc_tx_t lc_clk_byp_req_i,
  output lc_tx_t lc_clk_byp_ack_o,

  // clock bypass control with ast
  // SEC_CM: CLK_HANDSHAKE.INTERSIG.MUBI
  output mubi4_t io_clk_byp_req_o,
  input mubi4_t io_clk_byp_ack_i,
  output mubi4_t all_clk_byp_req_o,
  input mubi4_t all_clk_byp_ack_i,
  output mubi4_t hi_speed_sel_o,

  // jittery enable to ast
  output mubi4_t jitter_en_o,

  // external indication for whether dividers should be stepped down
  // SEC_CM: DIV.INTERSIG.MUBI
  input mubi4_t div_step_down_req_i,

  // clock gated indications going to alert handlers
  output clkmgr_cg_en_t cg_en_o,

  // clock output interface
% for intf in cfg['exported_clks']:
  output clkmgr_${intf}_out_t clocks_${intf}_o,
% endfor
  output clkmgr_out_t clocks_o

);

  import prim_mubi_pkg::MuBi4False;
  import prim_mubi_pkg::MuBi4True;
  import prim_mubi_pkg::mubi4_test_true_strict;

  ////////////////////////////////////////////////////
  // Divided clocks
  ////////////////////////////////////////////////////

  logic [${len(clocks.derived_srcs)-1}:0] step_down_acks;

% for src_name in clocks.derived_srcs:
  logic clk_${src_name}_i;
% endfor

% for src_name in clocks.all_derived_srcs():
  mubi4_t ${src_name}_step_down_req;
  prim_mubi4_sync #(
    .NumCopies(1),
    .AsyncOn(1),
    .StabilityCheck(1),
    .ResetValue(MuBi4False)
  ) u_${src_name}_step_down_req_sync (
    .clk_i(clk_${src_name}_i),
    .rst_ni(rst_${src_name}_ni),
    .mubi_i(div_step_down_req_i),
    .mubi_o(${src_name}_step_down_req)
  );

% endfor
% for src in clocks.derived_srcs.values():

  // Declared as size 1 packed array to avoid FPV warning.
  prim_mubi_pkg::mubi4_t [0:0] ${src.name}_div_scanmode;
  prim_mubi4_sync #(
    .NumCopies(1),
    .AsyncOn(0)
  ) u_${src.name}_div_scanmode_sync  (
    .clk_i(1'b0),  //unused
    .rst_ni(1'b1), //unused
    .mubi_i(scanmode_i),
    .mubi_o(${src.name}_div_scanmode)
  );

  prim_clock_div #(
    .Divisor(${src.div})
  ) u_no_scan_${src.name}_div (
    .clk_i(clk_${src.src.name}_i),
    .rst_ni(rst_${src.src.name}_ni),
    .step_down_req_i(mubi4_test_true_strict(${src.src.name}_step_down_req)),
    .step_down_ack_o(step_down_acks[${loop.index}]),
    .test_en_i(mubi4_test_true_strict(${src.name}_div_scanmode[0])),
    .clk_o(clk_${src.name}_i)
  );
% endfor

  ////////////////////////////////////////////////////
  // Register Interface
  ////////////////////////////////////////////////////

  logic [NumAlerts-1:0] alert_test, alerts;
  clkmgr_reg_pkg::clkmgr_reg2hw_t reg2hw;
  clkmgr_reg_pkg::clkmgr_hw2reg_t hw2reg;

  // SEC_CM: MEAS.CONFIG.REGWEN
  // SEC_CM: CLK_CTRL.CONFIG.REGWEN
  clkmgr_reg_top u_reg (
    .clk_i,
    .rst_ni,
    .rst_shadowed_ni,
% for src in typed_clocks.rg_srcs:
    .clk_${src}_i,
    .rst_${src}_ni,
% endfor
    .tl_i,
    .tl_o,
    .reg2hw,
    .hw2reg,
    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(hw2reg.fatal_err_code.reg_intg.de),
    .devmode_i(1'b1)
  );
  assign hw2reg.fatal_err_code.reg_intg.d = 1'b1;


  ////////////////////////////////////////////////////
  // Alerts
  ////////////////////////////////////////////////////

  assign alert_test = {
    reg2hw.alert_test.fatal_fault.q & reg2hw.alert_test.fatal_fault.qe,
    reg2hw.alert_test.recov_fault.q & reg2hw.alert_test.recov_fault.qe
  };

  logic recov_alert;
  assign recov_alert =
% for src in typed_clocks.rg_srcs:
    hw2reg.recov_err_code.${src}_update_err.de |
    hw2reg.recov_err_code.${src}_measure_err.de |
    hw2reg.recov_err_code.${src}_timeout_err.de${";" if loop.last else " |"}
% endfor

  assign alerts = {
    |reg2hw.fatal_err_code,
    recov_alert
  };

  localparam logic [NumAlerts-1:0] AlertFatal = {1'b1, 1'b0};

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(AlertAsyncOn[i]),
      .IsFatal(AlertFatal[i])
    ) u_prim_alert_sender (
      .clk_i,
      .rst_ni,
      .alert_test_i  ( alert_test[i] ),
      .alert_req_i   ( alerts[i]     ),
      .alert_ack_o   (               ),
      .alert_state_o (               ),
      .alert_rx_i    ( alert_rx_i[i] ),
      .alert_tx_o    ( alert_tx_o[i] )
    );
  end

  ////////////////////////////////////////////////////
  // Clock bypass request
  ////////////////////////////////////////////////////

  clkmgr_byp #(
    .NumDivClks(${len(clocks.derived_srcs)})
  ) u_clkmgr_byp (
    .clk_i,
    .rst_ni,
    .en_i(lc_hw_debug_en_i),
    .lc_clk_byp_req_i,
    .lc_clk_byp_ack_o,
    .byp_req_i(mubi4_t'(reg2hw.extclk_ctrl.sel.q)),
    .hi_speed_sel_i(mubi4_t'(reg2hw.extclk_ctrl.hi_speed_sel.q)),
    .all_clk_byp_req_o,
    .all_clk_byp_ack_i,
    .io_clk_byp_req_o,
    .io_clk_byp_ack_i,
    .hi_speed_sel_o,

    // divider step down controls
    .step_down_acks_i(step_down_acks)
  );

  ////////////////////////////////////////////////////
  // Feed through clocks
  // Feed through clocks do not actually need to be in clkmgr, as they are
  // completely untouched. The only reason they are here is for easier
  // bundling management purposes through clocks_o
  ////////////////////////////////////////////////////
% for k,v in typed_clocks.ft_clks.items():
  prim_clock_buf u_${k}_buf (
    .clk_i(clk_${v.src.name}_i),
    .clk_o(clocks_o.${k})
  );

  // clock gated indication for alert handler: these clocks are never gated.
  assign cg_en_o.${k.split('clk_')[-1]} = MuBi4False;
% endfor

  ////////////////////////////////////////////////////
  // Distribute pwrmgr ip_clk_en requests to each family
  ////////////////////////////////////////////////////
% for root, clk_family in typed_clocks.parent_child_clks.items():
  // clk_${root} family
  % for clk in clk_family:
  logic pwrmgr_${clk}_en;
  % endfor
  % for clk in clk_family:
  assign pwrmgr_${clk}_en = pwr_i.${root}_ip_clk_en;
  % endfor

% endfor

  ////////////////////////////////////////////////////
  // Root gating
  ////////////////////////////////////////////////////

% for root, clk_family in typed_clocks.parent_child_clks.items():
  // clk_${root} family
  logic [${len(clk_family)-1}:0] ${root}_ens;

  % for src in clk_family:
  logic clk_${src}_en;
  logic clk_${src}_root;
  clkmgr_root_ctrl u_${src}_root_ctrl (
    .clk_i(clk_${src}_i),
    .rst_ni(rst_${src}_ni),
    .scanmode_i,
    .async_en_i(pwrmgr_${src}_en),
    .en_o(clk_${src}_en),
    .clk_o(clk_${src}_root)
  );
  assign ${root}_ens[${loop.index}] = clk_${src}_en;

  % endfor
  // create synchronized status
  clkmgr_clk_status #(
    .NumClocks(${len(clk_family)})
  ) u_${root}_status (
    .clk_i,
    .rst_ni,
    .ens_i(${root}_ens),
    .status_o(pwr_o.${root}_status)
  );

% endfor
  ////////////////////////////////////////////////////
  // Clock Measurement for the roots
  // SEC_CM: TIMEOUT.CLK.BKGN_CHK, MEAS.CLK.BKGN_CHK
  ////////////////////////////////////////////////////

<% aon_freq = clocks.all_srcs['aon'].freq %>\
% for src in typed_clocks.rg_srcs:
  logic ${src}_fast_err;
  logic ${src}_slow_err;
  logic ${src}_timeout_err;
  <%
   freq = clocks.all_srcs[src].freq
   cnt = int(freq*2 / aon_freq)
  %>\
  prim_clock_meas #(
    .Cnt(${cnt}),
    .RefCnt(1),
    .ClkTimeOutChkEn(1'b1),
    .RefTimeOutChkEn(1'b0)
  ) u_${src}_meas (
    .clk_i(clk_${src}_i),
    .rst_ni(rst_${src}_ni),
    .clk_ref_i(clk_aon_i),
    .rst_ref_ni(rst_aon_ni),
    .en_i(clk_${src}_en & reg2hw.${src}_meas_ctrl_shadowed.en.q),
    .max_cnt(reg2hw.${src}_meas_ctrl_shadowed.hi.q),
    .min_cnt(reg2hw.${src}_meas_ctrl_shadowed.lo.q),
    .valid_o(),
    .fast_o(${src}_fast_err),
    .slow_o(${src}_slow_err),
    .timeout_clk_ref_o(),
    .ref_timeout_clk_o(${src}_timeout_err)
  );

  logic synced_${src}_err;
  prim_pulse_sync u_${src}_err_sync (
    .clk_src_i(clk_${src}_i),
    .rst_src_ni(rst_${src}_ni),
    .src_pulse_i(${src}_fast_err | ${src}_slow_err),
    .clk_dst_i(clk_i),
    .rst_dst_ni(rst_ni),
    .dst_pulse_o(synced_${src}_err)
  );

  logic synced_${src}_timeout_err;
  prim_edge_detector #(
    .Width(1),
    .ResetValue('0),
    .EnSync(1'b1)
  ) u_${src}_timeout_err_sync (
    .clk_i,
    .rst_ni,
    .d_i(${src}_timeout_err),
    .q_sync_o(),
    .q_posedge_pulse_o(synced_${src}_timeout_err),
    .q_negedge_pulse_o()
  );

  assign hw2reg.recov_err_code.${src}_measure_err.d = 1'b1;
  assign hw2reg.recov_err_code.${src}_measure_err.de = synced_${src}_err;
  assign hw2reg.recov_err_code.${src}_timeout_err.d = 1'b1;
  assign hw2reg.recov_err_code.${src}_timeout_err.de = synced_${src}_timeout_err;
  assign hw2reg.recov_err_code.${src}_update_err.d = 1'b1;
  assign hw2reg.recov_err_code.${src}_update_err.de =
    reg2hw.${src}_meas_ctrl_shadowed.en.err_update |
    reg2hw.${src}_meas_ctrl_shadowed.hi.err_update |
    reg2hw.${src}_meas_ctrl_shadowed.lo.err_update;
  assign hw2reg.fatal_err_code.${src}_storage_err.d = 1'b1;
  assign hw2reg.fatal_err_code.${src}_storage_err.de =
    reg2hw.${src}_meas_ctrl_shadowed.en.err_storage |
    reg2hw.${src}_meas_ctrl_shadowed.hi.err_storage |
    reg2hw.${src}_meas_ctrl_shadowed.lo.err_storage;

% endfor

  ////////////////////////////////////////////////////
  // Clocks with only root gate
  ////////////////////////////////////////////////////
% for k,v in typed_clocks.rg_clks.items():
  assign clocks_o.${k} = clk_${v.src.name}_root;

  // clock gated indication for alert handler
  prim_mubi4_sender #(
    .ResetValue(MuBi4True)
  ) u_prim_mubi4_sender_${k} (
    .clk_i(clk_${v.src.name}_i),
    .rst_ni(rst_${v.src.name}_ni),
    .mubi_i(((clk_${v.src.name}_en) ? MuBi4False : MuBi4True)),
    .mubi_o(cg_en_o.${k.split('clk_')[-1]})
  );
% endfor

  ////////////////////////////////////////////////////
  // Software direct control group
  ////////////////////////////////////////////////////

% for k in typed_clocks.sw_clks:
  logic ${k}_sw_en;
% endfor

% for k,v in typed_clocks.sw_clks.items():
  prim_flop_2sync #(
    .Width(1)
  ) u_${k}_sw_en_sync (
    .clk_i(clk_${v.src.name}_i),
    .rst_ni(rst_${v.src.name}_ni),
    .d_i(reg2hw.clk_enables.${k}_en.q),
    .q_o(${k}_sw_en)
  );

  // Declared as size 1 packed array to avoid FPV warning.
  prim_mubi_pkg::mubi4_t [0:0] ${k}_scanmode;
  prim_mubi4_sync #(
    .NumCopies(1),
    .AsyncOn(0)
  ) u_${k}_scanmode_sync  (
    .clk_i(1'b0),  //unused
    .rst_ni(1'b1), //unused
    .mubi_i(scanmode_i),
    .mubi_o(${k}_scanmode)
  );

  logic ${k}_combined_en;
  assign ${k}_combined_en = ${k}_sw_en & clk_${v.src.name}_en;
  prim_clock_gating #(
    .FpgaBufGlobal(1'b1) // This clock spans across multiple clock regions.
  ) u_${k}_cg (
    .clk_i(clk_${v.src.name}_root),
    .en_i(${k}_combined_en),
    .test_en_i(mubi4_test_true_strict(${k}_scanmode[0])),
    .clk_o(clocks_o.${k})
  );

  // clock gated indication for alert handler
  prim_mubi4_sender #(
    .ResetValue(MuBi4True)
  ) u_prim_mubi4_sender_${k} (
    .clk_i(clk_${v.src.name}_i),
    .rst_ni(rst_${v.src.name}_ni),
    .mubi_i(((${k}_combined_en) ? MuBi4False : MuBi4True)),
    .mubi_o(cg_en_o.${k.split('clk_')[-1]})
  );

% endfor

  ////////////////////////////////////////////////////
  // Software hint group
  // The idle hint feedback is assumed to be synchronous to the
  // clock target
  ////////////////////////////////////////////////////

  logic [${len(typed_clocks.hint_clks)-1}:0] idle_cnt_err;
% for clk, sig in typed_clocks.hint_clks.items():
<%assert_name = Name.from_snake_case(clk)
%>
  clkmgr_trans #(
% if clk == "clk_main_kmac":
    .FpgaBufGlobal(1'b1) // KMAC is getting too big for a single clock region.
% else:
    .FpgaBufGlobal(1'b0) // This clock is used primarily locally.
% endif
  ) u_${clk}_trans (
    .clk_i(clk_${sig.src.name}_i),
    .rst_ni(rst_${sig.src.name}_ni),
    .clk_root_i(clk_${sig.src.name}_root),
    .clk_root_en_i(clk_${sig.src.name}_en),
    .idle_i(idle_i[${hint_names[clk]}]),
    .sw_hint_i(reg2hw.clk_hints.${clk}_hint.q),
    .scanmode_i,
    .alert_cg_en_o(cg_en_o.${clk.split('clk_')[-1]}),
    .clk_o(clocks_o.${clk}),
    .clk_en_o(hw2reg.clk_hints_status.${clk}_val.d),
    .cnt_err_o(idle_cnt_err[${hint_names[clk]}])
  );
  `ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(
    ${assert_name.as_camel_case()}CountCheck_A,
    u_${clk}_trans.u_idle_cnt,
    alert_tx_o[0])
% endfor
  assign hw2reg.fatal_err_code.idle_cnt.d = 1'b1;
  assign hw2reg.fatal_err_code.idle_cnt.de = |idle_cnt_err;

  // state readback
% for clk in typed_clocks.hint_clks.keys():
  assign hw2reg.clk_hints_status.${clk}_val.de = 1'b1;
% endfor

  // SEC_CM: JITTER.CONFIG.MUBI
  assign jitter_en_o = mubi4_t'(reg2hw.jitter_enable.q);

  ////////////////////////////////////////////////////
  // Exported clocks
  ////////////////////////////////////////////////////

% for intf, eps in cfg['exported_clks'].items():
  % for ep, clks in eps.items():
    % for clk in clks:
  assign clocks_${intf}_o.clk_${intf}_${ep}_${clk} = clocks_o.clk_${clk};
    % endfor
  % endfor
% endfor

  ////////////////////////////////////////////////////
  // Assertions
  ////////////////////////////////////////////////////

  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(AlertsKnownO_A,   alert_tx_o)
  `ASSERT_KNOWN(PwrMgrKnownO_A, pwr_o)
  `ASSERT_KNOWN(AllClkBypReqKnownO_A, all_clk_byp_req_o)
  `ASSERT_KNOWN(IoClkBypReqKnownO_A, io_clk_byp_req_o)
  `ASSERT_KNOWN(LcCtrlClkBypAckKnownO_A, lc_clk_byp_ack_o)
  `ASSERT_KNOWN(JitterEnableKnownO_A, jitter_en_o)
% for intf in cfg['exported_clks']:
  `ASSERT_KNOWN(ExportClocksKownO_A, clocks_${intf}_o)
% endfor
  `ASSERT_KNOWN(ClocksKownO_A, clocks_o)
  `ASSERT_KNOWN(CgEnKnownO_A, cg_en_o)

endmodule // clkmgr
