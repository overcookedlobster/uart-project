class uart_tx_agent extends uvm_agent;
  `uvm_component_utils(uart_tx_agent)

  // Configuration handle
  uart_tx_config cfg;

  // Components
  uart_tx_driver      driver;
  uart_tx_sequencer   sequencer;
  uart_tx_monitor     monitor;

  // Analysis port to forward collected transactions
  uvm_analysis_port #(uart_tx_seq_item) agent_ap;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    agent_ap = new("agent_ap", this);
  endfunction

  // Build phase - create and configure components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get the configuration
    if(!uvm_config_db#(uart_tx_config)::get(this, "", "cfg", cfg)) begin
      `uvm_error(get_type_name(), "Failed to get configuration object")
      cfg = uart_tx_config::type_id::create("default_cfg");
    end

    // Set configuration for sub-components using config db
    uvm_config_db#(uart_tx_config)::set(this, "*", "cfg", cfg);

    // Always create the monitor (needed for both active and passive agents)
    monitor = uart_tx_monitor::type_id::create("monitor", this);

    // Create driver and sequencer only for active agents
    if(cfg.is_active == UVM_ACTIVE) begin
      `uvm_info(get_type_name(), "Creating active agent components", UVM_MEDIUM)
      driver = uart_tx_driver::type_id::create("driver", this);
      sequencer = uart_tx_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  // Connect phase - connect TLM ports
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor's analysis port to the agent's analysis port
    monitor.item_collected_port.connect(agent_ap);

    // Connect driver and sequencer for active agents
    if(cfg.is_active == UVM_ACTIVE) begin
      `uvm_info(get_type_name(), "Connecting driver and sequencer", UVM_MEDIUM)
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

  // Run phase - optionally add synchronized start logic
  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    if(cfg.is_active == UVM_ACTIVE) begin
      `uvm_info(get_type_name(), "Agent running in ACTIVE mode", UVM_MEDIUM)
    end else begin
      `uvm_info(get_type_name(), "Agent running in PASSIVE mode", UVM_MEDIUM)
    end
  endtask

  // Report phase - summarize agent activity at end of test
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    // Add any agent-specific reporting here
  endfunction
endclass
