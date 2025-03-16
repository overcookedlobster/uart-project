// Scoreboard implementation
class uart_tx_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_tx_scoreboard)

  // Analysis export to receive transactions from monitor
  uvm_analysis_imp #(uart_tx_seq_item, uart_tx_scoreboard) uart_tx_export;

  // Statistics
  int num_checked;
  int num_errors;

  // Optional: Queue to store transactions for self-checking protocols
  uart_tx_seq_item tx_items[$];

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    uart_tx_export = new("uart_tx_export", this);
    num_checked = 0;
    num_errors = 0;
  endfunction

  // Write method for the analysis export
  function void write(uart_tx_seq_item item);
    // Increment the transaction counter
    num_checked++;

    `uvm_info(get_type_name(), $sformatf("Received transaction: %s", item.convert2string()), UVM_HIGH)

    // Perform checks on the transaction
    check_transaction(item);

    // Store transaction for potential later use
    tx_items.push_back(item);
  endfunction

  // Method to check transaction correctness
  function void check_transaction(uart_tx_seq_item item);
    // Basic checks
    if (item.tx_start && !item.tx_busy) begin
      `uvm_error(get_type_name(), "TX busy not asserted after TX start")
      num_errors++;
    end

    if (item.tx_done && item.tx_busy) begin
      `uvm_error(get_type_name(), "TX busy still asserted when TX done")
      num_errors++;
    end

    // Protocol-specific checks
    // Add more checks based on the UART protocol requirements

    `uvm_info(get_type_name(), $sformatf("Transaction #%0d checked", num_checked), UVM_HIGH)
  endfunction

  // Report phase
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (num_errors > 0) begin
      `uvm_error(get_type_name(), $sformatf("%0d errors detected during simulation", num_errors))
    end else begin
      `uvm_info(get_type_name(), "No errors detected during simulation", UVM_LOW)
    end
  endfunction
endclass
class uart_tx_env extends uvm_env;
  `uvm_component_utils(uart_tx_env)

  // Components
  uart_tx_agent    agent;
  uart_tx_scoreboard scoreboard;

  // Configuration
  uart_tx_config   cfg;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build phase - create and configure components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), "Building environment", UVM_MEDIUM)

    // Get or create the configuration
    if (!uvm_config_db#(uart_tx_config)::get(this, "", "cfg", cfg)) begin
      `uvm_info(get_type_name(), "No config provided, creating default config", UVM_MEDIUM)
      cfg = uart_tx_config::type_id::create("cfg");
    end

    // Configure the agent
    uvm_config_db#(uart_tx_config)::set(this, "agent", "cfg", cfg);

    // Create the agent
    agent = uart_tx_agent::type_id::create("agent", this);

    // Create scoreboard if checks are enabled
    if (cfg.has_checks) begin
      scoreboard = uart_tx_scoreboard::type_id::create("scoreboard", this);
    end
  endfunction

  // Connect phase - connect TLM ports
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    `uvm_info(get_type_name(), "Connecting components", UVM_MEDIUM)

    // Connect monitor to scoreboard if both exist
    if (cfg.has_checks) begin
      agent.agent_ap.connect(scoreboard.uart_tx_export);
      `uvm_info(get_type_name(), "Connected agent to scoreboard", UVM_MEDIUM)
    end
  endfunction

  // Run phase - start activities
  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    `uvm_info(get_type_name(), "Environment running", UVM_MEDIUM)
  endtask

  // Report phase - summarize test results
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (cfg.has_checks && scoreboard != null) begin
      `uvm_info(get_type_name(), $sformatf(
        "\n----- UART TX Scoreboard Report -----\n" +
        "  Transactions checked: %0d\n" +
        "  Errors detected:      %0d\n" +
        "------------------------------------",
        scoreboard.num_checked, scoreboard.num_errors), UVM_LOW)
    end
  endfunction
endclass

