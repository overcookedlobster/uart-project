/*
xvlog -sv uart_input_filter_tb.sv ../uart_input_filter.sv && xelab -R uart_input_filter_tb
*/
/*
Filename: uart_input_filter_tb.sv
Description: Testbench for UART input synchronizer and glitch filter
*/

`timescale 1ns/1ps

module uart_input_filter_tb;

  // Parameters for simulation
  localparam CLOCK_PERIOD = 10;     // 100 MHz clock
  
  // Testbench signals
  logic clk;              // System clock
  logic rst_n;            // Active-low reset
  logic tick_16x;         // 16x oversampling tick
  logic rx_in;            // Raw serial input
  logic rx_filtered;      // Filtered serial input
  logic falling_edge;     // Falling edge detection signal
  
  // For result checking
  logic expected_edge_detected;
  
  // DUT instantiation
  uart_input_filter dut (
    .clk(clk),
    .rst_n(rst_n),
    .tick_16x(tick_16x),
    .rx_in(rx_in),
    .rx_filtered(rx_filtered),
    .falling_edge(falling_edge)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
  end
  
  // 16x Tick generation - manually controlled in the test sequence
  initial begin
    tick_16x = 0;
  end
  
  // Task to pulse tick_16x for one clock cycle
  task pulse_tick;
    @(posedge clk);
    tick_16x = 1;
    @(posedge clk);
    tick_16x = 0;
  endtask
  
  // Task to generate multiple ticks
  task multiple_ticks(input int count);
    repeat(count) begin
      pulse_tick();
    end
  endtask
  
  // Task to create a clean transition and watch for edge
  task check_clean_transition(input logic level, output logic edge_detected);
    edge_detected = 0;
    
    // Set the input level
    rx_in = level;
    
    // Generate enough ticks to stabilize the filter
    repeat(4) begin
      @(posedge clk);
      tick_16x = 1;
      @(posedge clk);
      tick_16x = 0;
      if (falling_edge) edge_detected = 1;
    end
    
  endtask
  
  // Test stimulus
  initial begin
    $display("Starting UART Input Filter Testbench");
    
    // Initialize inputs
    rx_in = 1'b1;   // Idle state is high
    rst_n = 1'b0;   // Start in reset
    expected_edge_detected = 0;
    
    // Wait a few clock cycles and release reset
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    
    // Wait for things to stabilize
    repeat(10) @(posedge clk);
    
    // ----------------------------------------
    // Test Case 1: Clean falling edge
    // ----------------------------------------
    $display("\nTest Case 1: Clean falling edge");
    
    // Stable high state first
    rx_in = 1'b1;
    multiple_ticks(4);
    
    // Create a falling edge
    rx_in = 1'b0;
    pulse_tick();
    
    // Check for edge detection on the next tick
    pulse_tick();
    
    // Wait another tick and check results
    pulse_tick();
    
    if (rx_filtered == 1'b0) begin
      $display("PASS: Clean falling edge filtered output is now low");
      
      // Check if we detected the edge in any recent tick
      if (falling_edge) begin
        $display("PASS: Falling edge currently being detected");
      end else begin
        $display("INFO: Falling edge not currently being signaled - checking previous");
        if (expected_edge_detected) begin
          $display("PASS: Falling edge was detected in previous ticks");
        end else begin
          $display("FAIL: Falling edge was not detected at any point");
        end
      end
    end else begin
      $display("FAIL: Filtered output didn't go low after clean falling edge");
    end
    
    // Return to idle
    rx_in = 1'b1;
    multiple_ticks(4);
    
    // ----------------------------------------
    // Test Case 2: Glitch rejection
    // ----------------------------------------
    $display("\nTest Case 2: Glitch rejection");
    
    // Create a short glitch (between tick_16x pulses)
    rx_in = 1'b0;
    @(posedge clk);
    rx_in = 1'b1;
    
    // Generate ticks and check filtering
    multiple_ticks(3);
    
    // Check that glitch was filtered
    if (rx_filtered == 1'b1) begin
      $display("PASS: Single-cycle glitch was properly filtered");
    end else begin
      $display("FAIL: Glitch was not filtered, rx_filtered=%b", rx_filtered);
    end
    
    // ----------------------------------------
    // Test Case 3: Noisy transition with majority vote
    // ----------------------------------------
    $display("\nTest Case 3: Noisy transition with majority vote");
    
    // Stable high
    rx_in = 1'b1;
    multiple_ticks(3);
    
    // Create a noisy transition sequence
    rx_in = 1'b0;  // Start going low
    pulse_tick();
    expected_edge_detected = falling_edge;
    
    rx_in = 1'b1;  // Bounce up
    pulse_tick();
    expected_edge_detected = expected_edge_detected | falling_edge;
    
    rx_in = 1'b0;  // Go low again
    pulse_tick();
    expected_edge_detected = expected_edge_detected | falling_edge;
    
    rx_in = 1'b0;  // Stay low
    pulse_tick();
    expected_edge_detected = expected_edge_detected | falling_edge;
    
    multiple_ticks(2);
    
    // Check that we eventually settled on low after the noise
    if (rx_filtered == 1'b0) begin
      $display("PASS: Filtered signal settled to low after noisy transition");
    end else begin
      $display("FAIL: Filtered signal did not settle to low, rx_filtered=%b", rx_filtered);
    end
    
    // ----------------------------------------
    // Test Case 4: Reset behavior
    // ----------------------------------------
    $display("\nTest Case 4: Reset behavior");
    
    // Stay low for some ticks
    rx_in = 1'b0;
    multiple_ticks(2);
    
    // Apply reset
    rst_n = 1'b0;
    repeat(2) @(posedge clk);
    
    // Check that filtered output returned to idle (high)
    if (rx_filtered == 1'b1) begin
      $display("PASS: Reset correctly returned filtered output to idle high state");
    end else begin
      $display("FAIL: Reset did not set filtered output high, rx_filtered=%b", rx_filtered);
    end
    
    // Release reset
    rst_n = 1'b1;
    
    // ----------------------------------------
    // Test Case 5: UART-like reception sequence
    // ----------------------------------------
    $display("\nTest Case 5: UART-like reception sequence");
    
    // Return to idle state
    rx_in = 1'b1;
    multiple_ticks(5);
    
    // Send start bit (falling edge)
    rx_in = 1'b0;
    expected_edge_detected = 0;
    
    repeat(4) begin
      pulse_tick();
      expected_edge_detected = expected_edge_detected | falling_edge;
    end
    
    if (expected_edge_detected) begin
      $display("PASS: Start bit falling edge detected");
    end else begin
      $display("FAIL: Start bit falling edge not detected");
    end
    
    // Hold low for full bit time
    multiple_ticks(12);
    
    // Send first data bit (0)
    rx_in = 1'b0;
    multiple_ticks(16);
    
    // Send second data bit (1)
    rx_in = 1'b1;
    multiple_ticks(16);
    
    // Return to idle
    rx_in = 1'b1;
    multiple_ticks(5);
    
    // ----------------------------------------
    // End of simulation
    // ----------------------------------------
    $display("\nTestbench completed successfully");
    $finish;
  end
  
  // Monitor falling edge detection for checking
  always @(posedge clk) begin
    if (falling_edge) begin
      expected_edge_detected = 1;
      $display("Time=%0t: Falling edge detected!", $time);
    end
  end
  
  // Monitor block for tracking state changes
  initial begin
    $monitor("Time=%0t, tick_16x=%b, rx_in=%b, rx_filtered=%b, falling_edge=%b", 
              $time, tick_16x, rx_in, rx_filtered, falling_edge);
  end
  
  // Optional: Waveform dumping for visual inspection
  initial begin
    $dumpfile("uart_input_filter_tb.vcd");
    $dumpvars(0, uart_input_filter_tb);
  end
  
endmodule
