//------------------------------------------------------------------------------
// File name: uart_rx_state_machine_tb.sv
//
// Description: Testbench for UART Receiver State Machine
// - Tests state transitions across various configurations
// - Verifies correct handling of data bits, parity, and stop bits
// - Validates error detection for frame and parity errors
// - Confirms proper control signal generation
//------------------------------------------------------------------------------
/*
xvlog -sv ../uart_rx_state_machine.sv uart_rx_state_machine_tb.sv && xelab -R uart_rx_state_machine_tb
*/

`timescale 1ns/1ps

module uart_rx_state_machine_tb;

  // Clock and reset
  logic        clk;
  logic        rst_n;
  
  // DUT inputs
  logic        bit_valid;
  logic        bit_sample;
  logic        start_detected;
  logic [3:0]  data_bits;
  logic [1:0]  parity_mode;
  logic        stop_bits;
  
  // DUT outputs
  logic        frame_active;
  logic        sample_enable;
  logic [3:0]  bit_count;
  logic        is_data_bit;
  logic        is_parity_bit;
  logic        is_stop_bit;
  logic        frame_complete;
  logic        frame_error;
  logic        parity_error;
  
  // Testbench variables
  int          test_number = 0;
  int          errors = 0;
  
  // Instantiate the DUT
  uart_rx_state_machine DUT (
    .clk             (clk),
    .rst_n           (rst_n),
    .bit_valid       (bit_valid),
    .bit_sample      (bit_sample),
    .start_detected  (start_detected),
    .data_bits       (data_bits),
    .parity_mode     (parity_mode),
    .stop_bits       (stop_bits),
    .frame_active    (frame_active),
    .sample_enable   (sample_enable),
    .bit_count       (bit_count),
    .is_data_bit     (is_data_bit),
    .is_parity_bit   (is_parity_bit),
    .is_stop_bit     (is_stop_bit),
    .frame_complete  (frame_complete),
    .frame_error     (frame_error),
    .parity_error    (parity_error)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz clock
  end
  
  // Task to reset the DUT
  task reset_dut();
    rst_n = 0;
    bit_valid = 0;
    bit_sample = 1;
    start_detected = 0;
    data_bits = 8;
    parity_mode = 0;  // No parity
    stop_bits = 0;    // 1 stop bit
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);
  endtask
  
  // Task to feed a bit to the DUT
  task send_bit(logic bit_value);
    bit_valid = 1;
    bit_sample = bit_value;
    @(posedge clk);
    bit_valid = 0;
    repeat (3) @(posedge clk);  // Wait between bits
  endtask
  
  // Task to start frame reception
  task signal_start_bit();
    start_detected = 1;
    bit_valid = 1;
    bit_sample = 0;  // Start bit is low
    @(posedge clk);
    start_detected = 0;
    bit_valid = 0;
    repeat (3) @(posedge clk);
  endtask
  
  // Task to check the state of signals
  task check_signals(
    string label,
    logic exp_frame_active,
    logic exp_is_data_bit,
    logic exp_is_parity_bit,
    logic exp_is_stop_bit
  );
    if (frame_active !== exp_frame_active ||
        is_data_bit !== exp_is_data_bit ||
        is_parity_bit !== exp_is_parity_bit ||
        is_stop_bit !== exp_is_stop_bit) begin
      
      $display("ERROR in %s: Signal mismatch at time %0t", label, $time);
      $display("  frame_active: Expected %b, Got %b", exp_frame_active, frame_active);
      $display("  is_data_bit:  Expected %b, Got %b", exp_is_data_bit, is_data_bit);
      $display("  is_parity_bit: Expected %b, Got %b", exp_is_parity_bit, is_parity_bit);
      $display("  is_stop_bit:  Expected %b, Got %b", exp_is_stop_bit, is_stop_bit);
      errors++;
    end
  endtask
  
  // Task to send a complete UART frame with configurable options
task send_frame(
  logic [8:0] data,         // Up to 9 bits of data
  logic [3:0] num_bits,     // Number of data bits (5-9)
  logic [1:0] p_mode,       // Parity mode
  logic stop_bit_count,     // 0=1 stop bit, 1=2 stop bits
  logic expected_parity_error = 0,
  logic expected_frame_error = 0
);
  logic parity_bit;
  logic parity_calc = 0;
  logic stop_bit_value;
  
  // Configure the DUT
  data_bits = num_bits;
  parity_mode = p_mode;
  stop_bits = stop_bit_count;
  @(posedge clk);
  
  // Send start bit
  signal_start_bit();
  
  // Calculate expected parity
  for (int i = 0; i < num_bits; i++) begin
    parity_calc ^= data[i];
  end
  
  case (p_mode)
    2'b01: parity_bit = ~parity_calc; // Odd parity
    2'b10: parity_bit = parity_calc;  // Even parity
    2'b11: parity_bit = 1'b1;         // Mark parity
    default: parity_bit = 1'b0;       // Space parity
  endcase
  
  // Force parity error if requested
  if (expected_parity_error && p_mode != 0) begin
    parity_bit = ~parity_bit;  // Invert parity to create error
    $display("DEBUG: Forcing bad parity bit = %b (should be %b)", 
             parity_bit, ~parity_bit);
  end
  
  // Send data bits
  for (int i = 0; i < num_bits; i++) begin
    send_bit(data[i]);
  end
  
  // Send parity bit if enabled
  if (p_mode != 0) begin
    send_bit(parity_bit);
  end
  
  // Send stop bits
  stop_bit_value = expected_frame_error ? 1'b0 : 1'b1;
  $display("DEBUG: Sending stop bit = %b (frame_error = %b)", 
           stop_bit_value, expected_frame_error);
  send_bit(stop_bit_value);  // First stop bit
  
  if (stop_bit_count) begin
    send_bit(stop_bit_value);  // Second stop bit if configured
  end
  
  // Wait for frame completion
  fork
    begin
      wait(frame_complete);
    end
    begin
      repeat(20) @(posedge clk);
    end
  join_any
  
  // Ensure we're back in idle state before continuing
  repeat(10) @(posedge clk);
  
  // Check error flags against expectations with better debug
  if (parity_error !== expected_parity_error) begin
    $display("ERROR: Parity error flag mismatch at time %0t", $time);
    $display("  Expected: %b, Got: %b", expected_parity_error, parity_error);
    $display("  Parity mode: %b, Data: %h", p_mode, data);
    errors++;
  end
  
  if (frame_error !== expected_frame_error) begin
    $display("ERROR: Frame error flag mismatch at time %0t", $time);
    $display("  Expected: %b, Got: %b", expected_frame_error, frame_error);
    $display("  Stop bit value sent: %b", stop_bit_value);
    errors++;
  end
endtask
  
  // Main test sequence
  initial begin
    $display("Starting UART RX State Machine Testbench");
    
    reset_dut();
    
    // Test 1: Basic 8N1 frame (8 data bits, no parity, 1 stop bit)
    test_number = 1;
    $display("\n=== Test %0d: Basic 8N1 Frame ===", test_number);
    send_frame(8'hA5, 8, 2'b00, 0);
    
    // Test 2: 7E1 frame (7 data bits, even parity, 1 stop bit)
    test_number = 2;
    $display("\n=== Test %0d: 7E1 Frame ===", test_number);
    send_frame(7'h27, 7, 2'b10, 0);
    
    // Test 3: 9O2 frame (9 data bits, odd parity, 2 stop bits)
    test_number = 3;
    $display("\n=== Test %0d: 9O2 Frame ===", test_number);
    send_frame(9'h155, 9, 2'b01, 1);
    
    // Test 4: 8M1 frame (8 data bits, mark parity, 1 stop bit)
    test_number = 4;
    $display("\n=== Test %0d: 8M1 Frame ===", test_number);
    send_frame(8'h7F, 8, 2'b11, 0);
    
    // Test 5: Parity error detection (8E1 with wrong parity)
    test_number = 5;
    $display("\n=== Test %0d: Parity Error Detection ===", test_number);
    send_frame(8'h55, 8, 2'b10, 0, 1, 0);
    
    // Test 6: Frame error detection (8N1 with bad stop bit)
    test_number = 6;
    $display("\n=== Test %0d: Frame Error Detection ===", test_number);
    send_frame(8'hAA, 8, 2'b00, 0, 0, 1);
    
    // Test 7: Consecutive frames
    test_number = 7;
    $display("\n=== Test %0d: Consecutive Frames ===", test_number);
    send_frame(8'h11, 8, 2'b00, 0);
    send_frame(8'h22, 8, 2'b00, 0);
    
    // Test 8: Reset during frame
    test_number = 8;
    $display("\n=== Test %0d: Reset During Frame ===", test_number);
    // Start a frame
    signal_start_bit();
    send_bit(1);
    send_bit(0);
    
    // Reset mid-frame
    $display("Applying reset mid-frame");
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);
    
    // Verify system returns to idle
    check_signals("Reset recovery", 0, 0, 0, 0);
    
    // Test 9: Minimum and maximum data bits configurations
    test_number = 9;
    $display("\n=== Test %0d: Min/Max Data Bits ===", test_number);
    // 5 data bits (minimum)
    send_frame(5'h15, 5, 2'b00, 0);
    // 9 data bits (maximum)
    send_frame(9'h1A5, 9, 2'b00, 0);
    
    // Display test results
    $display("\n=== Test Results ===");
    if (errors == 0) begin
      $display("All tests PASSED!");
    end else begin
      $display("%0d test(s) FAILED!", errors);
    end
    
    $finish;
  end
  
  // Monitor state machine activity
  always @(posedge clk) begin
    if (frame_active) begin
      if (bit_valid) begin
        if (is_data_bit)
          $display("Time %0t: Data bit = %b, Position = %0d", $time, bit_sample, bit_count);
        else if (is_parity_bit)
          $display("Time %0t: Parity bit = %b", $time, bit_sample);
        else if (is_stop_bit)
          $display("Time %0t: Stop bit = %b", $time, bit_sample);
      end
    end
    
    if (frame_complete)
      $display("Time %0t: Frame complete", $time);
    
    if (frame_error)
      $display("Time %0t: FRAME ERROR detected", $time);
    
    if (parity_error)
      $display("Time %0t: PARITY ERROR detected", $time);
  end

endmodule
