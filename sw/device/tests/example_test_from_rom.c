// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_uart.h"
#include "sw/device/lib/pinmux.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/check.h"
#include "sw/device/lib/testing/test_framework/test_status.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"  // Generated.

static dif_uart_t uart0;

void _boot_start(void) {
  // We need to set the test status as "in test" to indicate to the test code
  // has been reached, even though this test is also in the "boot ROM".
  test_status_set(kTestStatusInTest);
  pinmux_init();

  // We need to initialize the UART regardless if we LOG any messages, since
  // Verilator and FPGA platforms use the UART to communicate the test results.
  if (kDeviceType != kDeviceSimDV) {
    CHECK_DIF_OK(dif_uart_init(
        mmio_region_from_addr(TOP_EARLGREY_UART0_BASE_ADDR), &uart0));
    CHECK_DIF_OK(
        dif_uart_configure(&uart0, (dif_uart_config_t){
                                       .baudrate = kUartBaudrate,
                                       .clk_freq_hz = kClockFreqPeripheralHz,
                                       .parity_enable = kDifToggleDisabled,
                                       .parity = kDifUartParityEven,
                                   }));
    base_uart_stdout(&uart0);
  }

  bool result = false;

  /**
   * Place test code here.
   */

  /**
   * Set test result to true if the test succeeds. Otherwise, set to false.
   */
  result = true;

  // Report test status.
  test_status_set(result ? kTestStatusPassed : kTestStatusFailed);

  // Unreachable.
  abort();
}
