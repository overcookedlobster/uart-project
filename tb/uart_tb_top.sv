//-----------------------------------------------------------------------------
// Title       : UART TX Testbench Top
// Description : Top-level testbench for UART TX UVM verification with enhanced debugging
//-----------------------------------------------------------------------------

// Include the interface first (it needs UVM macros)
`include "uvm_macros.svh"
import uvm_pkg::*;

// Include the interface definition
`include "uart_interface.sv"

// Include the testbench package
`include "uart_tb_pkg.sv"
import uart_tb_pkg::*;

module uart_tb_top;
  // Clock and reset signals
  logic clk;
  logic rst_n;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  // Reset generation
  initial begin
    rst_n = 0;
    #100 rst_n = 1; // Release reset after 100ns
  end

  // Instantiate the interface
  uart_tx_if #(
    .DATA_BITS(8),
    .PARITY_EN(1'b1),
    .PARITY_TYPE(1'b0), // 0=even, 1=odd
    .STOP_BITS(1)
  ) uart_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  // Instantiate the DUT
  uart_tx #(
    .DATA_BITS(8),
    .PARITY_EN(1'b1),
    .PARITY_TYPE(1'b0), // 0=even, 1=odd
    .STOP_BITS(1)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .tick(uart_if.tick),
    .tx_start(uart_if.tx_start),
    .cts(uart_if.cts),
    .tx_data(uart_if.tx_data),
    .tx_out(uart_if.tx_out),
    .tx_busy(uart_if.tx_busy),
    .tx_done(uart_if.tx_done)
  );

  // Generate baudrate using a divider
  // Use a simple counter to generate ticks
  logic [15:0] baud_counter;
  // For simulator speed, use a smaller divider than in real hardware
  localparam BAUD_DIVIDER = 10; // Much faster for simulation

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_counter <= '0;
      // Interface tick is controlled by the driver, not by this always block
    end
    else begin
      if (baud_counter == BAUD_DIVIDER-1) begin
        baud_counter <= '0;
        // Let the driver control the tick signal instead
        // uart_if.tick <= 1'b1;
      end
      else begin
        baud_counter <= baud_counter + 1'b1;
        // uart_if.tick <= 1'b0;
      end
    end
  end

  // Debug: Monitor key signals
  initial begin
    bit prev_tx_start = 0;
    bit prev_tx_busy = 0;
    bit prev_tx_done = 0;
    bit prev_tick = 0;

    forever begin
      @(posedge clk);

      // Monitor tx_start transitions
      if (uart_if.tx_start != prev_tx_start) begin
        $display("[%0t] TX_START changed: %0b -> %0b", $time, prev_tx_start, uart_if.tx_start);
        prev_tx_start = uart_if.tx_start;
      end

      // Monitor tx_busy transitions
      if (uart_if.tx_busy != prev_tx_busy) begin
        $display("[%0t] TX_BUSY changed: %0b -> %0b", $time, prev_tx_busy, uart_if.tx_busy);
        prev_tx_busy = uart_if.tx_busy;
      end

      // Monitor tx_done transitions
      if (uart_if.tx_done != prev_tx_done) begin
        $display("[%0t] TX_DONE changed: %0b -> %0b", $time, prev_tx_done, uart_if.tx_done);
        prev_tx_done = uart_if.tx_done;
      end

      // Monitor tick transitions
      if (uart_if.tick != prev_tick) begin
        prev_tick = uart_if.tick;
      end
    end
  end

  // Run test
  initial begin
    // Set the interface in the resource database
    uvm_config_db#(virtual uart_tx_if)::set(null, "uvm_test_top", "vif", uart_if);

    // Print information about the testbench
    `uvm_info("TB_TOP", "UART TX Testbench started", UVM_LOW)

    // Run test - can specify test name as +UVM_TESTNAME=uart_tx_basic_test on command line
    run_test();
  end

  // Monitor for timeout
  initial begin
    #10000000; // 10ms timeout
    `uvm_error("TB_TOP", "Testbench timeout occurred")
    $finish;
  end

  // Display final status
  final begin
    `uvm_info("TB_TOP", "UART TX Testbench completed", UVM_LOW)
  end
endmodule
