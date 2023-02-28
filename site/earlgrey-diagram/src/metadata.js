// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

export default {
    "opentitan-logo": {
        title: "opentitan",
        href: "/",
    },
    "high-speed-crossbar": {
        title: "high-speed-crossbar",
        metrics: "tlul",
        href: "/hw/ip/tlul#top",
        report: "/hw/top_earlgrey/ip/xbar_main/dv/autogen",
    },
    "ibex": {
        title: "ibex",
        metrics: "rv_core_ibex",
        href: "/hw/ip/rv_core_ibex#top",
        report: null,
    },
    "interrupt-controller": {
        title: "interrupt-controller",
        metrics: "rv_plic",
        href: "/hw/top_earlgrey/ip_autogen/rv_plic#top",
        report: null,
    },
    "debug-module": {
        title: "debug-module",
        metrics: "rv_dm",
        href: "/hw/ip/rv_dm#top",
        report: "/hw/ip/rv_dm/dv",
    },
    "rom": {
        title: "rom",
        metrics: "rom_ctrl",
        href: "/hw/ip/rom_ctrl#top",
        report: "/hw/ip/rom_ctrl/dv",
    },
    "main-sram": {
        title: "main-sram",
        metrics: "sram_ctrl",
        href: "/hw/ip/sram_ctrl#top",
        report: "/hw/ip/sram_ctrl_main/dv",
    },
    "key-manager": {
        title: "key-manager",
        metrics: "keymgr",
        href: "/hw/ip/keymgr#top",
        report: "/hw/ip/keymgr/dv",
    },
    "otbn": {
        title: "otbn",
        metrics: "otbn",
        href: "/hw/ip/otbn#top",
        report: "/hw/ip/otbn/dv/uvm",
    },
    "aes": {
        title: "aes",
        metrics: "aes",
        href: "/hw/ip/aes#top",
        report: "/hw/ip/aes_unmasked/dv",
    },
    "kmac": {
        title: "kmac",
        metrics: "kmac",
        href: "/hw/ip/kmac#top",
        report: "/hw/ip/kmac_unmasked/dv",
    },
    "hmac": {
        title: "hmac",
        metrics: "hmac",
        href: "/hw/ip/hmac#top",
        report: "/hw/ip/hmac/dv",
    },
    "flash": {
        title: "flash",
        metrics: "flash_ctrl",
        href: "/hw/ip/flash_ctrl#top",
        report: "/hw/ip/flash_ctrl/dv",
    },
    "edn": {
        title: "edn",
        metrics: "edn",
        href: "/hw/ip/edn#top",
        report: "/hw/ip/edn/dv",
    },
    "csrng": {
        title: "csrng",
        metrics: "csrng",
        href: "/hw/ip/csrng#top",
        report: "/hw/ip/csrng/dv",
    },
    "entropy-source": {
        title: "entropy-source",
        metrics: "entropy_src",
        href: "/hw/ip/entropy_src#top",
        report: "/hw/ip/entropy_src/dv",
    },
    "spi-host-0": {
        title: "spi-host",
        metrics: "spi_host",
        href: "/hw/ip/spi_host#top",
        report: "/hw/ip/spi_host/dv",
    },
    "spi-host-1": {
        title: "spi-host",
        metrics: "spi_host",
        href: "/hw/ip/spi_host#top",
        report: "/hw/ip/spi_host/dv",
    },
    "usb": {
        title: "usb",
        metrics: "usbdev",
        href: "/hw/ip/usbdev#top",
        report: "/hw/ip/usbdev/dv",
    },
    "peripheral-crossbar": {
        title: "peripheral-crossbar",
        metrics: "tlul",
        href: "/hw/ip/tlul#top",
        report: "/hw/top_earlgrey/ip/xbar_peri/dv/autogen",
    },
    "otp-fuse-controller": {
        title: "otp-fuse-controller",
        metrics: "otp_ctrl",
        href: "/hw/ip/otp_ctrl#top",
        report: "/hw/ip/otp_ctrl/dv",
    },
    "life-cycle": {
        title: "life-cycle",
        metrics: "lc_ctrl",
        href: "/hw/ip/lc_ctrl#top",
        report: "/hw/ip/lc_ctrl/dv",
    },
    "alert-handler": {
        title: "alert-handler",
        metrics: "alert_handler",
        href: "/hw/top_earlgrey/ip_autogen/alert_handler#top",
        report: "/hw/top_earlgrey/ip_autogen/alert_handler/dv",
    },
    "uart": {
        title: "uart",
        metrics: "uart",
        href: "/hw/ip/uart#top",
        report: "/hw/ip/uart/dv",
    },
    "timers": {
        title: "timers",
        metrics: "rv_timer",
        href: "/hw/ip/rv_timer#top",
        report: "/hw/ip/rv_timer/dv",
    },
    "gpio": {
        title: "gpio",
        metrics: "gpio",
        href: "/hw/ip/gpio#top",
        report: "/hw/ip/gpio/dv",
    },
    "i2c": {
        title: "i2c",
        metrics: "i2c",
        href: "/hw/ip/i2c#top",
        report: "/hw/ip/i2c/dv",
    },
    "spi-device": {
        title: "spi-device",
        metrics: "spi_device",
        href: "/hw/ip/spi_device#top",
        report: "/hw/ip/spi_device/dv",
    },
    "pattern-generators": {
        title: "pattern-generators",
        metrics: "pattgen",
        href: "/hw/ip/pattgen#top",
        report: "/hw/ip/pattgen/dv",
    },
    "pwm": {
        title: "pwm",
        metrics: "pwm",
        href: "/hw/ip/pwm#top",
        report: "/hw/ip/pwm/dv",
    },
    "retention-sram": {
        title: "retention-sram",
        metrics: "sram_ctrl",
        href: "/hw/ip/sram_ctrl#top",
        report: "/hw/ip/sram_ctrl_ret/dv",
    },
    "power-manager": {
        title: "power-manager",
        metrics: "pwrmgr",
        href: "/hw/ip/pwrmgr#top",
        report: "/hw/ip/pwrmgr/dv",
    },
    "sysrst-controller": {
        title: "sysrst-controller",
        metrics: "sysrst_ctrl",
        href: "/hw/ip/sysrst_ctrl#top",
        report: "/hw/ip/sysrst_ctrl/dv",
    },
    "aon-timers": {
        title: "aon-timers",
        metrics: "aon_timer",
        href: "/hw/ip/aon_timer#top",
        report: "/hw/ip/aon_timer/dv",
    },
    "clkrst-managers": {
        title: "clkrst-managers",
        metrics: "clkmgr",
        href: "/hw/ip/clkmgr#top",
        report: "/hw/ip/clkmgr/dv",
    },
    "pinmux-padctrl": {
        title: "pinmux-padctrl",
        metrics: "pinmux",
        href: "/hw/ip/pinmux#top",
        report: null,
    },
    "adc-controller": {
        title: "adc-controller",
        metrics: "adc_ctrl",
        href: "/hw/ip/adc_ctrl#top",
        report: "/hw/ip/adc_ctrl/dv",
    },
    "sensor-control": {
        title: "sensor-control",
        metrics: "sensor_ctrl",
        href: "/hw/top_earlgrey/ip/sensor_ctrl#top",
        report: null,
    },
    "analog-sensor-top": {
        title: "analog-sensor-top",
        metrics: "ast",
        href: "/hw/top_earlgrey/ip/ast#top",
        report: null,
    },
    "padding": {
        title: "padding",
        href: "/hw/top_earlgrey/ip/pinmux/doc/autogen/pinout_asic/",
        report: null,
    }
};
