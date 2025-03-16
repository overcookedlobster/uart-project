module uvm_check;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  initial begin
    uvm_config_db#(int)::set(null, "*", "dummy", 1);
    $display("UVM is available");
  end
endmodule
