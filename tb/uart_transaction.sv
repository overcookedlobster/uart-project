// Make sure UVM macros are included BEFORE the class definition
class uart_tx_seq_item extends uvm_sequence_item;
  // Configuration parameters (could also come from config object)
  // REFACTOR!
  parameter int DATA_BITS = 8;

  // Transaction data fields
  rand bit  [DATA_BITS-1:0] tx_data;
  rand bit  tx_start;
  rand bit  cts;

  // Control knobs for test scenarios
  rand int  tick_delay; // Control delay before starting transmission
  rand int  inter_frame_delay; // Control delay between frames

  // Metadata and tracking
  bit tx_done;  // Transmission complete flag
  bit tx_busy;  // Transmitter busy flag
  bit tx_out;   // Serial output value (for monitoring)

  // UVM macros - use standard macros instead of field macros for better Vivado compatibility
  `uvm_object_utils(uart_tx_seq_item)

  // Constraints
  constraint c_cts_valid {
    cts dist {1'b1 := 90, 1'b0 := 10}; // Usually enabled
  }

  constraint c_delay_reasonable {
    tick_delay inside {[0:20]};
    inter_frame_delay inside {[1:50]}; // Ensure minimum delay between frames
  }

  // Standard UVM methods
  function new (string name = "uart_tx_seq_item");
    super.new(name);
  endfunction

  // Use do_copy, do_compare etc. instead of relying on field macros
  virtual function void do_copy(uvm_object rhs);
    uart_tx_seq_item rhs_;

    if(!$cast(rhs_, rhs)) begin
      `uvm_fatal("CAST", "Failed to cast transaction object")
      return;
    end

    super.do_copy(rhs);

    this.tx_data = rhs_.tx_data;
    this.tx_start = rhs_.tx_start;
    this.cts = rhs_.cts;
    this.tick_delay = rhs_.tick_delay;
    this.inter_frame_delay = rhs_.inter_frame_delay;
    this.tx_done = rhs_.tx_done;
    this.tx_busy = rhs_.tx_busy;
    this.tx_out = rhs_.tx_out;
  endfunction

  virtual function string convert2string();
    string s;
    s = super.convert2string();
    s = {s, $sformatf("tx_data: 0x%0h ", tx_data)};
    s = {s, $sformatf("tx_start: %0b ", tx_start)};
    s = {s, $sformatf("cts: %0b ", cts)};
    s = {s, $sformatf("tx_busy: %0b ", tx_busy)};
    s = {s, $sformatf("tx_done: %0b ", tx_done)};
    return s;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    uart_tx_seq_item rhs_;

    if(!$cast(rhs_, rhs)) return 0;

    return (super.do_compare(rhs, comparer) &&
           (this.tx_data == rhs_.tx_data) &&
           (this.tx_start == rhs_.tx_start) &&
           (this.cts == rhs_.cts));
  endfunction
endclass
