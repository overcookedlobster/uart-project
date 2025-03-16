class uart_tx_config extends uvm_object;
  `uvm_object_utils(uart_tx_config)

  // DUT Configuration parameters
  int data_bits = 8;
  bit parity_enable = 1;
  bit parity_type = 0; // 0=even, 1=odd
  int stop_bits = 1;

  // Testbench control parameters
  bit has_coverage = 1;
  bit has_checks = 1;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Virtual interface reference
  virtual uart_tx_if vif;

  function new (string name = "uart_tx_config");
    super.new(name);
  endfunction

endclass
