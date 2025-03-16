class uart_tx_sequencer extends uvm_sequencer #(uart_tx_seq_item);
  `uvm_component_utils(uart_tx_sequencer)
  // Configuration object handle
  uart_tx_config cfg;

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration if available
    if(!uvm_config_db#(uart_tx_config)::get(this, "", "cfg", cfg))
      `uvm_error(get_type_name(), "Failed to get configuration object")
  endfunction
endclass

