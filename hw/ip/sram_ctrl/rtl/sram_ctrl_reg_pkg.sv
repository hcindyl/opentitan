// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package sram_ctrl_reg_pkg;

  // Param list
  parameter int NumAlerts = 1;

  // Address widths within the block
  parameter int RegsAw = 5;
  parameter int RamAw = 1;

  ///////////////////////////////////////////////
  // Typedefs for registers for regs interface //
  ///////////////////////////////////////////////

  typedef struct packed {
    logic        q;
    logic        qe;
  } sram_ctrl_reg2hw_alert_test_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } bus_integ_error;
    struct packed {
      logic        q;
    } init_error;
    struct packed {
      logic        q;
    } escalated;
    struct packed {
      logic        q;
    } scr_key_seed_valid;
    struct packed {
      logic        q;
    } init_done;
  } sram_ctrl_reg2hw_status_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } sram_ctrl_reg2hw_exec_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
      logic        qe;
    } renew_scr_key;
    struct packed {
      logic        q;
      logic        qe;
    } init;
  } sram_ctrl_reg2hw_ctrl_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } bus_integ_error;
    struct packed {
      logic        d;
      logic        de;
    } init_error;
    struct packed {
      logic        d;
      logic        de;
    } escalated;
    struct packed {
      logic        d;
      logic        de;
    } scr_key_valid;
    struct packed {
      logic        d;
      logic        de;
    } scr_key_seed_valid;
    struct packed {
      logic        d;
      logic        de;
    } init_done;
  } sram_ctrl_hw2reg_status_reg_t;

  // Register -> HW type for regs interface
  typedef struct packed {
    sram_ctrl_reg2hw_alert_test_reg_t alert_test; // [14:13]
    sram_ctrl_reg2hw_status_reg_t status; // [12:8]
    sram_ctrl_reg2hw_exec_reg_t exec; // [7:4]
    sram_ctrl_reg2hw_ctrl_reg_t ctrl; // [3:0]
  } sram_ctrl_regs_reg2hw_t;

  // HW -> register type for regs interface
  typedef struct packed {
    sram_ctrl_hw2reg_status_reg_t status; // [11:0]
  } sram_ctrl_regs_hw2reg_t;

  // Register offsets for regs interface
  parameter logic [RegsAw-1:0] SRAM_CTRL_ALERT_TEST_OFFSET = 5'h 0;
  parameter logic [RegsAw-1:0] SRAM_CTRL_STATUS_OFFSET = 5'h 4;
  parameter logic [RegsAw-1:0] SRAM_CTRL_EXEC_REGWEN_OFFSET = 5'h 8;
  parameter logic [RegsAw-1:0] SRAM_CTRL_EXEC_OFFSET = 5'h c;
  parameter logic [RegsAw-1:0] SRAM_CTRL_CTRL_REGWEN_OFFSET = 5'h 10;
  parameter logic [RegsAw-1:0] SRAM_CTRL_CTRL_OFFSET = 5'h 14;

  // Reset values for hwext registers and their fields for regs interface
  parameter logic [0:0] SRAM_CTRL_ALERT_TEST_RESVAL = 1'h 0;
  parameter logic [0:0] SRAM_CTRL_ALERT_TEST_FATAL_ERROR_RESVAL = 1'h 0;

  // Register index for regs interface
  typedef enum int {
    SRAM_CTRL_ALERT_TEST,
    SRAM_CTRL_STATUS,
    SRAM_CTRL_EXEC_REGWEN,
    SRAM_CTRL_EXEC,
    SRAM_CTRL_CTRL_REGWEN,
    SRAM_CTRL_CTRL
  } sram_ctrl_regs_id_e;

  // Register width information to check illegal writes for regs interface
  parameter logic [3:0] SRAM_CTRL_REGS_PERMIT [6] = '{
    4'b 0001, // index[0] SRAM_CTRL_ALERT_TEST
    4'b 0001, // index[1] SRAM_CTRL_STATUS
    4'b 0001, // index[2] SRAM_CTRL_EXEC_REGWEN
    4'b 0001, // index[3] SRAM_CTRL_EXEC
    4'b 0001, // index[4] SRAM_CTRL_CTRL_REGWEN
    4'b 0001  // index[5] SRAM_CTRL_CTRL
  };

endpackage

