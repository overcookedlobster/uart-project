// UART TX Base Test
class uart_tx_base_test extends uvm_test;
  `uvm_component_utils(uart_tx_base_test)

  // The environment
  uart_tx_env env;

  // Configuration
  uart_tx_config cfg;

  // Virtual interface
  virtual uart_tx_if vif;

  // UVM test timeout
  time test_timeout = 1000us;

  // Constructor
  function new(string name = "uart_tx_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), "Building test...", UVM_LOW)

    // Create the configuration
    cfg = uart_tx_config::type_id::create("cfg");

    // Get the virtual interface
    if (!uvm_config_db#(virtual uart_tx_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Failed to get virtual interface")
    end

    // Store the interface in the config
    cfg.vif = vif;

    // Default configuration settings
    cfg.has_checks = 1;
    cfg.has_coverage = 1;
    cfg.is_active = UVM_ACTIVE;

    // Make configuration available to the environment
    uvm_config_db#(uart_tx_config)::set(this, "env", "cfg", cfg);

    // Make the virtual interface available to lower levels
    uvm_config_db#(virtual uart_tx_if)::set(this, "env.agent.*", "vif", vif);

    // Create the environment
    env = uart_tx_env::type_id::create("env", this);
  endfunction

  // Connect phase
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), "Connect phase completed", UVM_LOW)
  endfunction

  // End of elaboration phase
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);

    // Print the test topology
    `uvm_info(get_type_name(), "Printing the test topology:", UVM_LOW)
    uvm_top.print_topology();

    // Removed factory.print() call that was causing issues
  endfunction

  // Run phase
  virtual task run_phase(uvm_phase phase);
    // Set a timeout for the test
    phase.phase_done.set_drain_time(this, test_timeout);

    `uvm_info(get_type_name(), $sformatf("Starting test with timeout of %0t", test_timeout), UVM_LOW)

    super.run_phase(phase);
  endtask

  // Report phase - print summary
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    // Fix string concatenation using curly braces instead of + operator
    `uvm_info(get_type_name(),
              {"\n----- UART TX Test Summary -----\n",
               $sformatf("  Test completed: %s\n", get_name()),
               "---------------------------------"},
              UVM_LOW)
  endfunction
endclass

// Basic transaction test - sends a sequence of random transactions
class uart_tx_basic_test extends uart_tx_base_test;
  `uvm_component_utils(uart_tx_basic_test)

  // Constructor
  function new(string name = "uart_tx_basic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase - override configuration as needed
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Specific test configuration overrides can go here
    cfg.data_bits = 8;
    cfg.parity_enable = 1;
    cfg.parity_type = 0; // Even parity
    cfg.stop_bits = 1;
  endfunction

  // Run phase - start sequences
  virtual task run_phase(uvm_phase phase);
    uart_tx_base_sequence seq;

    // Call the base run_phase
    super.run_phase(phase);

    // Create the sequence
    seq = uart_tx_base_sequence::type_id::create("seq");

    // Raise objection - this prevents the test from ending until sequence is done
    phase.raise_objection(this, "Starting UART TX basic test sequence");

    `uvm_info(get_type_name(), "Starting basic transaction sequence", UVM_LOW)

    // Start the sequence on the sequencer
    seq.start(env.agent.sequencer);

    // Wait a bit to allow completion
    #1000ns;

    // Drop objection - allows the test to finish
    phase.drop_objection(this, "Completed UART TX basic test sequence");
  endtask
endclass

// Multiple transaction test - sends multiple back-to-back transactions
class uart_tx_multi_transaction_test extends uart_tx_base_test;
  `uvm_component_utils(uart_tx_multi_transaction_test)

  // Number of transactions to send
  int num_transactions = 10;

  // Constructor
  function new(string name = "uart_tx_multi_transaction_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Run phase - start multiple transactions
  virtual task run_phase(uvm_phase phase);
    uart_tx_base_sequence seq;

    // Call the base run_phase
    super.run_phase(phase);

    // Raise objection
    phase.raise_objection(this, "Starting UART TX multi-transaction test");

    `uvm_info(get_type_name(), $sformatf("Starting %0d transactions", num_transactions), UVM_LOW)

    // Run multiple transactions
    repeat (num_transactions) begin
      seq = uart_tx_base_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);

      // Small delay between transactions
      #100ns;
    end

    // Wait a bit for completion
    #1000ns;

    // Drop objection
    phase.drop_objection(this, "Completed UART TX multi-transaction test");
  endtask

  // Report phase
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info(get_type_name(), $sformatf("Completed %0d UART transactions", num_transactions), UVM_LOW)
  endfunction
endclass

// Flow control test - verifies CTS behavior
class uart_tx_flow_control_test extends uart_tx_base_test;
  `uvm_component_utils(uart_tx_flow_control_test)

  // Constructor
  function new(string name = "uart_tx_flow_control_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Run phase - test flow control
  virtual task run_phase(uvm_phase phase);
    uart_tx_seq_item tx_item;

    // Call the base run_phase
    super.run_phase(phase);

    // Raise objection
    phase.raise_objection(this, "Starting UART TX flow control test");

    `uvm_info(get_type_name(), "Testing flow control (CTS) behavior", UVM_LOW)

    // Create a transaction with controlled CTS behavior
    tx_item = uart_tx_seq_item::type_id::create("tx_item");

    // First transaction with CTS high (normal)
    if (!tx_item.randomize() with { cts == 1'b1; }) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end

    `uvm_info(get_type_name(), "Starting transaction with CTS high", UVM_LOW)
    env.agent.sequencer.seq_item_export.put(tx_item);

    // Wait a bit
    #1000ns;

    // Second transaction with CTS low (should pause)
    tx_item = uart_tx_seq_item::type_id::create("tx_item");
    if (!tx_item.randomize() with { cts == 1'b0; }) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end

    `uvm_info(get_type_name(), "Starting transaction with CTS low (should pause)", UVM_LOW)
    env.agent.sequencer.seq_item_export.put(tx_item);

    // Wait a bit
    #5000ns;

    // Drop objection
    phase.drop_objection(this, "Completed UART TX flow control test");
  endtask
endclass

// Custom data pattern test - sends specific data patterns
class uart_tx_data_pattern_test extends uart_tx_base_test;
  `uvm_component_utils(uart_tx_data_pattern_test)

  // Data patterns to test
  logic [7:0] patterns[] = {8'h00, 8'hFF, 8'hA5, 8'h5A, 8'h01, 8'h80};

  // Constructor
  function new(string name = "uart_tx_data_pattern_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Run phase - send specific patterns
  virtual task run_phase(uvm_phase phase);
    uart_tx_seq_item tx_item;

    // Call the base run_phase
    super.run_phase(phase);

    // Raise objection
    phase.raise_objection(this, "Starting UART TX data pattern test");

    `uvm_info(get_type_name(), "Testing specific data patterns", UVM_LOW)

    // Send each pattern
    foreach (patterns[i]) begin
      tx_item = uart_tx_seq_item::type_id::create("tx_item");

      if (!tx_item.randomize() with {
        tx_data == patterns[i];
        tx_start == 1'b1;
        cts == 1'b1;
      }) begin
        `uvm_error(get_type_name(), "Randomization failed")
      end

      `uvm_info(get_type_name(), $sformatf("Sending data pattern 0x%h", patterns[i]), UVM_LOW)
      env.agent.sequencer.seq_item_export.put(tx_item);

      // Wait for each transaction to complete
      #2000ns;
    end

    // Drop objection
    phase.drop_objection(this, "Completed UART TX data pattern test");
  endtask

  // Report phase
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info(get_type_name(), $sformatf("Tested %0d different data patterns", patterns.size()), UVM_LOW)
  endfunction
endclass
