class uart_tx_driver extends uvm_driver #(uart_tx_seq_item);
  `uvm_component_utils(uart_tx_driver)

  // Configuration handle
  uart_tx_config cfg;

  // Virtual interface handle
  virtual uart_tx_if vif;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build phase - get configuration and interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db#(uart_tx_config)::get(this, "", "cfg", cfg))
      `uvm_error(get_type_name(), "Failed to get configuration object")

    if(!uvm_config_db#(virtual uart_tx_if)::get(this, "", "vif", vif))
      `uvm_error(get_type_name(), "Failed to get virtual interface")
  endfunction

  // Reset phase - initialize signals
  task reset_phase(uvm_phase phase);
    super.reset_phase(phase);

    `uvm_info(get_type_name(), "Reset phase starting", UVM_MEDIUM)

    vif.cb.tx_start <= 1'b0;
    vif.cb.tx_data <= '0;
    vif.cb.cts <= 1'b1; // Default CTS to enabled
    vif.cb.tick <= 1'b0;

    `uvm_info(get_type_name(), "Reset phase complete", UVM_MEDIUM)
  endtask

  // Main driver task
  task run_phase(uvm_phase phase);
    uart_tx_seq_item tx_item;

    `uvm_info(get_type_name(), "Run phase starting", UVM_MEDIUM)

    // Wait for reset to complete
    @(posedge vif.rst_n);
    `uvm_info(get_type_name(), "Reset complete, starting transaction processing", UVM_MEDIUM)

    forever begin
      // Get next transaction from sequencer
      seq_item_port.get_next_item(tx_item);
      `uvm_info(get_type_name(), $sformatf("Received transaction: %s", tx_item.convert2string()), UVM_HIGH)

      // Drive the transaction
      drive_transaction(tx_item);

      // Notify sequencer we're done with this transaction
      seq_item_port.item_done();

      // Report transaction
      `uvm_info(get_type_name(), $sformatf("Drove transaction: %s", tx_item.convert2string()), UVM_MEDIUM)
    end
  endtask

  // Task to drive a single transaction
  virtual task drive_transaction(uart_tx_seq_item item);
    // Apply any initial delay
    repeat(item.tick_delay) begin
      @(vif.cb);
    end

    // Drive the data and control signals
    vif.cb.tx_data <= item.tx_data;
    vif.cb.cts <= item.cts;

    // Start transmission
    if(item.tx_start) begin
      `uvm_info(get_type_name(), $sformatf("Starting TX with data 0x%0h", item.tx_data), UVM_MEDIUM)
      vif.cb.tx_start <= 1'b1;
      @(vif.cb);
      vif.cb.tx_start <= 1'b0; // Pulse tx_start for one clock cycle
    end

    // Wait for transmission to complete by monitoring tx_done
    wait_for_tx_done();

    // Apply inter-frame delay
    repeat(item.inter_frame_delay) begin
      @(vif.cb);
    end
  endtask

  // Helper task to wait for transmission completion
  virtual task wait_for_tx_done();
    int timeout_counter = 0;
    int max_timeout = cfg.data_bits * 20; // Reasonable timeout based on data bits

    `uvm_info(get_type_name(), "Waiting for TX completion", UVM_HIGH)

    // Wait until the tx_done signal is asserted
    do begin
      // Generate baud rate ticks to keep the transmission moving
      vif.cb.tick <= 1'b1;
      @(vif.cb);
      vif.cb.tick <= 1'b0;
      @(vif.cb);

      // Check for timeout
      timeout_counter++;
      if (timeout_counter > max_timeout) begin
        `uvm_error(get_type_name(), $sformatf("Timeout waiting for tx_done after %0d ticks", timeout_counter))
        break;
      end
    end
    while(!vif.cb.tx_done);

    `uvm_info(get_type_name(), $sformatf("TX completed after %0d ticks", timeout_counter), UVM_MEDIUM)

    // Capture results back to the transaction if needed
    // This would be done if you want to return results to the sequence
  endtask
endclass
