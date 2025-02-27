// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//############################################################################
// *Name: usb_osc
// *Module Description: USB Clock Oscilator
//############################################################################

module usb_osc (
  input vcore_pok_h_i,    // VCORE POK @3.3V
  input usb_en_i,         // USB Source Clock Enable
  input usb_ref_val_i,    // USB Reference Valid
  input usb_osc_cal_i,    // USB Oscillator Calibrated
`ifdef AST_BYPASS_CLK
  input clk_usb_ext_i,    // FPGA/VERILATOR Clock input
`endif
  output logic usb_clk_o  // USB Clock Output
);

`ifndef AST_BYPASS_CLK
`ifndef SYNTHESIS
// Behavioral Model
////////////////////////////////////////
timeunit 1ns / 1ps;
import ast_bhv_pkg::* ;

real CLK_PERIOD;
integer rand32;

reg init_start = 1'b0;
initial init_start = 1'b0;

initial begin
  #1; init_start  = 1'b1;
  $display("\nUSB Power-up Clock Frequency: %0d Hz", $rtoi(10**9/CLK_PERIOD));
  rand32 = $urandom_range((9'd416), -(9'd416));  // +/-416ps (+/-2% max)
  $display("USB Clock Drift: %0dps", rand32);
end

// Enable 5us RC Delay on rise
wire en_osc_re_buf, en_osc_re;
buf #(IO_EN_RDLY, 0) b0 (en_osc_re_buf, (vcore_pok_h_i && usb_en_i));
assign en_osc_re = en_osc_re_buf && init_start;

logic ref_val_buf, ref_val;
buf #(USB_VAL_RDLY, USB_VAL_FDLY) b1 (ref_val_buf, (vcore_pok_h_i && usb_ref_val_i));
assign ref_val = ref_val_buf && init_start;

// Clock Oscillator
////////////////////////////////////////
real CalUsbClkPeriod, UncUsbClkPeriod, UsbClkPeriod, drift;

initial CalUsbClkPeriod = $itor( 1000000/48 );                    // ~20833.33333ps (48MHz)
initial UncUsbClkPeriod = $itor( $urandom_range(55555, 25000) );  // 55555-25000ps (18-40MHz)

assign drift = ref_val ? 0.0 : $itor(rand32);
assign UsbClkPeriod = (usb_osc_cal_i && init_start) ? CalUsbClkPeriod : UncUsbClkPeriod;
assign CLK_PERIOD = (UsbClkPeriod + drift)/1000;

// Free running oscillator
reg clk_osc;
initial clk_osc = 1'b1;

always begin
  #(CLK_PERIOD/2) clk_osc = ~clk_osc;
end

logic en_osc;

// HDL Clock Gate
logic en_clk, clk;

always_latch begin
  if ( !clk_osc ) en_clk <= en_osc;
end

assign clk = clk_osc && en_clk;
`else  // of SYBTHESIS
// SYNTHESIS/LINTER
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && usb_en_i;

logic clk, en_osc;
assign clk = 1'b0;
`endif  // of SYBTHESIS
`else  // of AST_BYPASS_CLK
// VERILATOR/FPGA
///////////////////////////////////////
logic en_osc_re;
assign en_osc_re = vcore_pok_h_i && usb_en_i;

// Clock Oscillator
////////////////////////////////////////
logic clk, en_osc;

prim_clock_gating #(
  .NoFpgaGate ( 1'b1 )
) u_clk_ckgt (
  .clk_i ( clk_usb_ext_i ),
  .en_i ( en_osc ),
  .test_en_i ( 1'b0 ),
  .clk_o ( clk )
);
`endif

logic en_osc_fe;

// Syncronize en_osc to clk FE for glitch free disable
always_ff @( negedge clk, negedge vcore_pok_h_i ) begin
  if ( !vcore_pok_h_i ) begin
    en_osc_fe <= 1'b0;
  end else begin
    en_osc_fe <= en_osc_re;
  end
end

assign en_osc = en_osc_re || en_osc_fe;  // EN -> 1 || EN -> 0

// Clock Output Buffer
////////////////////////////////////////
prim_clock_buf #(
  .NoFpgaBuf ( 1'b1 )
) u_buf (
  .clk_i ( clk ),
  .clk_o ( usb_clk_o )
);


`ifdef SYNTHESIS
///////////////////////
// Unused Signals
///////////////////////
logic unused_sigs;
assign unused_sigs = ^{ usb_osc_cal_i, usb_ref_val_i };
`endif

endmodule : usb_osc
