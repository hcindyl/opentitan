// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Filters interrupt & wakeup together test sequence
class adc_ctrl_filters_both_vseq extends adc_ctrl_filters_polled_vseq;

  `uvm_object_utils(adc_ctrl_filters_both_vseq)

  `uvm_object_new

  virtual task configure_adc_ctrl();
    adc_ctrl_testmode_e testmode;
    bit [ADC_CTRL_NUM_FILTERS:0] adc_intr_ctl;
    bit [ADC_CTRL_NUM_FILTERS-1:0] adc_wakeup_ctl;

    super.configure_adc_ctrl();
    // Normal or low power
    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(
        testmode, testmode inside {AdcCtrlTestmodeNormal, AdcCtrlTestmodeLowpower};)
    // Enable interrupts and wakeup
    `DV_CHECK_STD_RANDOMIZE_FATAL(adc_intr_ctl)
    `DV_CHECK_STD_RANDOMIZE_FATAL(adc_wakeup_ctl)
    cfg.testmode = testmode;
    cfg.adc_intr_ctl = adc_intr_ctl;
    cfg.adc_wakeup_ctl = adc_wakeup_ctl;

    csr_wr(ral.adc_wakeup_ctl, cfg.adc_wakeup_ctl);
    csr_wr(ral.adc_intr_ctl, cfg.adc_intr_ctl);
    csr_wr(ral.intr_enable, 'h1);
  endtask

  // Check the ADC CTRL status after every ADC sample (all channels)
  virtual task check_adc_ctrl_status();
    uvm_reg_data_t rdata;
    forever begin
      // Wait for all channels
      wait_all_rx();
      // Delay to allow register to be updated
      cfg.clk_aon_rst_vif.wait_clks(10);
      csr_rd(ral.intr_state, rdata);
      csr_rd(ral.adc_intr_status, rdata);
      csr_rd(ral.filter_status, rdata);
      // Randomly erase intr_status/state
      if ($urandom_range(0, 10) > 9) begin
        csr_wr(ral.adc_intr_status, $urandom());
        csr_wr(ral.filter_status, $urandom());
        csr_wr(ral.intr_state, $urandom());
      end
    end
  endtask

endclass : adc_ctrl_filters_both_vseq
