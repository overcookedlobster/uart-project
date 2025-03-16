class uart_tx_base_sequence extends uvm_sequence #(uart_tx_seq_item);
  `uvm_object_utils(uart_tx_base_sequence)

  function new (string name="uart_tx_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    uart_tx_seq_item tx_item;
    tx_item = uart_tx_seq_item::type_id::create("tx_item");
    start_item(tx_item);
    if(!tx_item.randomize()) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(tx_item);
  endtask
endclass
