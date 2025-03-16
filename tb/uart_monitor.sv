class uart_tx_monitor extends uvm_monitor;
  `uvm_component_utils(uart_tx_monitor)

  // Configuration handle
  uart_tx_config cfg;

  // Virtual interface handle
  virtual uart_tx_if vif;

  // Analysis port to send transactions to scoreboard/subscribers
  uvm_analysis_port #(uart_tx_seq_item) item_collected_port;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  // Build phase - get configuration and interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db#(uart_tx_config)::get(this, "", "cfg", cfg))
      `uvm_error(get_type_name(), "Failed to get configuration object")

    if(!uvm_config_db#(virtual uart_tx_if)::get(this, "", "vif", vif))
      `uvm_error(get_type_name(), "Failed to get virtual interface")
  endfunction

  // Run phase - main monitoring process
  task run_phase(uvm_phase phase);
    uart_tx_seq_item tx_item;

    // Wait for reset to complete
    @(posedge vif.rst_n);

    `uvm_info(get_type_name(), "Monitor starting", UVM_MEDIUM)

    forever begin
      // Create a new transaction item
      tx_item = uart_tx_seq_item::type_id::create("tx_item");

      // Collect a transaction
      collect_transaction(tx_item);

      // Send the transaction to subscribers via the analysis port
      item_collected_port.write(tx_item);
    end
  endtask

  // Task to collect a single transaction
  virtual task collect_transaction(uart_tx_seq_item item);
    // Wait for the start of a transaction
    wait_for_tx_start(item);

    // Monitor the transaction progress
    monitor_tx_progress(item);

    // Optional protocol-level monitoring
    if(cfg.has_checks) begin
      monitor_serial_protocol(item);
    end

    `uvm_info(get_type_name(), $sformatf("Collected transaction: %s", item.convert2string()), UVM_MEDIUM)
  endtask

  // Wait for the start of a transaction
  virtual task wait_for_tx_start(uart_tx_seq_item item);
    // Wait for tx_start assertion - access signal directly, not through clocking block
    @(posedge vif.tx_start);

    // Capture initial state - direct signal access
    item.tx_data = vif.tx_data;
    item.tx_start = 1'b1;
    item.cts = vif.cts;

    `uvm_info(get_type_name(), $sformatf("Detected transaction start, data=0x%h", item.tx_data), UVM_HIGH)
  endtask

  // Monitor transaction progress through the control signals
  virtual task monitor_tx_progress(uart_tx_seq_item item);
    // Wait for TX to become busy - using sampled input
    wait(vif.cb.tx_busy);
    item.tx_busy = 1'b1;

    // Wait for transmission to complete
    fork
      begin
        wait(vif.cb.tx_done);
        item.tx_done = 1'b1;
      end
      begin
        // Safety timeout in case tx_done is never asserted
        repeat(cfg.data_bits * 20) @(vif.cb);
        if(!item.tx_done) begin
          `uvm_error(get_type_name(), "Timeout waiting for tx_done")
        end
      end
    join_any
    disable fork;

    // Wait for tx_busy to deassert
    wait(!vif.cb.tx_busy);
    @(vif.cb);
  endtask

  // Monitor the actual serial protocol on tx_out (for verification)
  virtual task monitor_serial_protocol(uart_tx_seq_item item);
    logic [7:0] received_data; // Use fixed width to match item width
    logic parity_bit, expected_parity;
    logic prev_tx_out = 1'b1;
    int bit_counter = 0;

    // Detect start bit (falling edge on tx_out)
    while(1) begin
      @(vif.cb);
      if(prev_tx_out == 1'b1 && vif.cb.tx_out == 1'b0) begin
        break; // Found start bit
      end
      prev_tx_out = vif.cb.tx_out;
    end

    `uvm_info(get_type_name(), "Start bit detected on serial output", UVM_HIGH)

    // Sample data bits (using tick for timing)
    received_data = '0;
    // Use cfg.data_bits instead of DATA_BITS
    for(int i=0; i<cfg.data_bits; i++) begin
      wait_for_baud_tick();
      received_data[i] = vif.cb.tx_out; // LSB first
      `uvm_info(get_type_name(), $sformatf("Sampled data bit %0d = %b", i, vif.cb.tx_out), UVM_HIGH)
    end

    // Verify sampled data matches expected data
    if(received_data != item.tx_data) begin
      `uvm_warning(get_type_name(),
        $sformatf("Data mismatch: Expected 0x%h, Received 0x%h", item.tx_data, received_data))
    end

    // Check parity bit if enabled
    if(cfg.parity_enable) begin
      wait_for_baud_tick();
      parity_bit = vif.cb.tx_out;
      expected_parity = calculate_parity(item.tx_data);

      if(parity_bit != expected_parity) begin
        `uvm_warning(get_type_name(),
          $sformatf("Parity error: Expected %b, Received %b", expected_parity, parity_bit))
      end
    end

    // Check stop bit(s)
    for(int i=0; i<cfg.stop_bits; i++) begin
      wait_for_baud_tick();
      if(vif.cb.tx_out != 1'b1) begin
        `uvm_warning(get_type_name(), "Stop bit not high - framing error")
      end
    end

    `uvm_info(get_type_name(), "Serial protocol verification complete", UVM_HIGH)
  endtask

  // Helper function to calculate expected parity
  function logic calculate_parity(logic [7:0] data);
    logic parity = ^data; // XOR all bits
    return cfg.parity_type ? ~parity : parity; // Invert for odd parity
  endfunction

  // Helper task to wait for a baud tick
  task wait_for_baud_tick();
    // Access tick directly, not through clocking block
    @(posedge vif.tick);
  endtask
endclass
