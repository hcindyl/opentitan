// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class clkmgr_common_vseq extends clkmgr_base_vseq;
  `uvm_object_utils(clkmgr_common_vseq)

  constraint num_trans_c {num_trans inside {[1 : 2]};}
  `uvm_object_new

  virtual task check_sec_cm_fi_resp(sec_cm_base_if_proxy if_proxy);
    super.check_sec_cm_fi_resp(if_proxy);

    case (if_proxy.sec_cm_type)
      SecCmPrimCount: begin
        csr_rd_check(.ptr(ral.fatal_err_code.idle_cnt), .compare_value(1));
      end
      default: begin
        `uvm_error(`gfn, $sformatf("Unexpected sec_cm_type %0s", if_proxy.sec_cm_type.name))
      end
    endcase
  endtask

  virtual task body();
    run_common_vseq_wrapper(num_trans);
  endtask : body

endclass
