///////////////////////////////////////////////////////////////////////////////
// File: uart_error_manager_tb.sv
// 
// Description: Testbench for UART Receiver Error Manager
// 
// This testbench validates the functionality of the error manager module
// by testing various error conditions and scenarios.
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module uart_error_manager_tb;

  // Parameters
  localparam CLK_PERIOD = 10;          // 100 MHz clock
  localparam CLK_FREQ_HZ = 100_000_000;
  localparam TEST_BAUD_RATE = 9600;
  localparam TIMEOUT_BIT_PERIODS = 3;
  localparam BIT_PERIOD_NS = 1_000_000_000 / TEST_BAUD_RATE; // 104,167 ns at 9600 baud
  
  // Testbench signals
  logic        clk;
  logic        rst_n;
  logic        frame_error;
  logic        parity_error;
  logic        frame_active;
  logic        bit_valid;
  logic        rx_filtered;
  logic [31:0] baud_rate;
  logic        error_clear;
  logic        error_detected;
  logic        framing_error;
  logic        parity_err;
  logic        break_detect;
  logic        timeout_detect;
  
  // Instantiate DUT
  uart_error_manager #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .TIMEOUT_BIT_PERIODS(TIMEOUT_BIT_PERIODS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .frame_error(frame_error),
    .parity_error(parity_error),
    .frame_active(frame_active),
    .bit_valid(bit_valid),
    .rx_filtered(rx_filtered),
    .baud_rate(baud_rate),
    .error_clear(error_clear),
    .error_detected(error_detected),
    .framing_error(framing_error),
    .parity_err(parity_err),
    .break_detect(break_detect),
    .timeout_detect(timeout_detect)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // Test stimulus
  initial begin
    // Initialize signals
    rst_n = 0;
    frame_error = 0;
    parity_error = 0;
    frame_active = 0;
    bit_valid = 0;
    rx_filtered = 1;  // Idle high
    baud_rate = TEST_BAUD_RATE;
    error_clear = 0;
    
    // Apply reset
    #(CLK_PERIOD * 2);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    // Test Case 1: Frame Error Detection
    $display("Test Case 1: Frame Error Detection");
    
    // Simulate start of frame
    frame_active = 1;
    #(CLK_PERIOD * 10);
    
    // Trigger frame error
    frame_error = 1;
    #(CLK_PERIOD);
    frame_error = 0;
    #(CLK_PERIOD * 5);
    
    // End of frame
    frame_active = 0;
    #(CLK_PERIOD * 5);
    
    // Check results
    if (framing_error && error_detected) begin
      $display("PASS: Frame error correctly detected");
    end else begin
      $display("FAIL: Frame error not detected");
    end
    
    // Test Case 2: Parity Error Detection
    $display("\nTest Case 2: Parity Error Detection");
    
    // Clear previous errors
    error_clear = 1;
    #(CLK_PERIOD);
    error_clear = 0;
    #(CLK_PERIOD);
    
    // Simulate start of frame
    frame_active = 1;
    #(CLK_PERIOD * 10);
    
    // Trigger parity error
    parity_error = 1;
    #(CLK_PERIOD);
    parity_error = 0;
    #(CLK_PERIOD * 5);
    
    // End of frame
    frame_active = 0;
    #(CLK_PERIOD * 5);
    
    // Check results
    if (parity_err && error_detected) begin
      $display("PASS: Parity error correctly detected");
    end else begin
      $display("FAIL: Parity error not detected");
    end
    
    // Test Case 3: Break Detection
    $display("\nTest Case 3: Break Detection");
    
    // Clear previous errors
    error_clear = 1;
    #(CLK_PERIOD);
    error_clear = 0;
    #(CLK_PERIOD);
    
    // Simulate start of frame with continuous low
    frame_active = 1;
    rx_filtered = 0;  // Low signal
    
    // Send 10 consecutive low bits
    for (int i = 0; i < 10; i++) begin
      bit_valid = 1;
      #(CLK_PERIOD);
      bit_valid = 0;
      #(CLK_PERIOD * 9);  // Bit time
    end
    
    // End of frame
    frame_active = 0;
    #(CLK_PERIOD * 10);
    
    // Check results
    if (break_detect && error_detected) begin
      $display("PASS: Break condition correctly detected");
    end else begin
      $display("FAIL: Break condition not detected");
    end
    
    // Test Case 4: Timeout Detection
    $display("\nTest Case 4: Timeout Detection");
    
    // Clear previous errors
    error_clear = 1;
    #(CLK_PERIOD);
    error_clear = 0;
    #(CLK_PERIOD);
    
    // Set RX to idle
    rx_filtered = 1;
    
    // Wait for timeout - three bit periods
    // Calculate cycles: (CLK_FREQ_HZ / baud_rate) * TIMEOUT_BIT_PERIODS
    // For 100MHz and 9600 baud: (100,000,000 / 9600) * 3 ≈ 31,250 cycles
    // We'll wait a bit longer to ensure timeout triggers
    #(32000 * CLK_PERIOD);
    
    // Check results
    if (timeout_detect) begin
      $display("PASS: Timeout correctly detected");
    end else begin
      $display("FAIL: Timeout not detected");
    end
    
    // Test Case 5: Error Clearing
    $display("\nTest Case 5: Error Clearing");
    
    // Trigger multiple errors
    frame_error = 1;
    parity_error = 1;
    #(CLK_PERIOD);
    frame_error = 0;
    parity_error = 0;
    #(CLK_PERIOD * 5);
    
    // Verify errors are set
    if (framing_error && parity_err && error_detected) begin
      $display("Errors set correctly before clearing");
    end else begin
      $display("Failed to set errors before clearing");
    end
    
    // Clear errors
    error_clear = 1;
    #(CLK_PERIOD);
    error_clear = 0;
    #(CLK_PERIOD);
    
    // Check that errors were cleared
    if (!framing_error && !parity_err && !error_detected) begin
      $display("PASS: Errors correctly cleared");
    end else begin
      $display("FAIL: Errors not cleared properly");
    end
    
    // End simulation
    #(CLK_PERIOD * 10);
    $display("\nAll tests completed");
    // $finish;
  end

endmodule
