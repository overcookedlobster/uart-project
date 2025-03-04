///////////////////////////////////////////////////////////////////////////////
// File: uart_rx_shift_register_tb.sv
// 
// Description: Testbench for UART Receiver Shift Register
// 
// This testbench validates the functionality of the shift register module
// by testing various configurations and scenarios.
///////////////////////////////////////////////////////////////////////////////
/*
xvlog -sv uart_rx_shift_register_tb.sv ../uart_rx_shift_register.sv && xelab -R uart_rx_shift_register_tb
*/
`timescale 1ns/1ps

module uart_rx_shift_register_tb;

  // Parameters
  localparam CLK_PERIOD = 10;  // 100 MHz clock
  localparam MAX_DATA_BITS = 9;
  
  // Testbench signals
  logic                     clk;
  logic                     rst_n;
  logic                     sample_enable;
  logic                     bit_sample;
  logic [3:0]               bit_count;
  logic                     is_data_bit;
  logic                     frame_complete;
  logic [3:0]               data_bits;
  logic                     lsb_first;
  logic [MAX_DATA_BITS-1:0] rx_data;
  logic                     data_valid;
  
  // Instantiate DUT
  uart_rx_shift_register #(
    .MAX_DATA_BITS(MAX_DATA_BITS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .sample_enable(sample_enable),
    .bit_sample(bit_sample),
    .bit_count(bit_count),
    .is_data_bit(is_data_bit),
    .frame_complete(frame_complete),
    .data_bits(data_bits),
    .lsb_first(lsb_first),
    .rx_data(rx_data),
    .data_valid(data_valid)
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
    sample_enable = 0;
    bit_sample = 0;
    bit_count = 0;
    is_data_bit = 0;
    frame_complete = 0;
    data_bits = 8;  // Default to 8 bits
    lsb_first = 1;  // Default to LSB first
    
    // Apply reset
    #(CLK_PERIOD * 2);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    // Test Case 1: Basic 8-bit LSB-first receive (0xA5)
    $display("Test Case 1: 8-bit LSB-first receive (0xA5)");
    data_bits = 8;
    lsb_first = 1;
    
    // Send bits (LSB first): 1(bit0), 0, 1, 0, 0, 1, 0, 1 (0xA5 = 10100101)
    send_bit(1); // bit 0
    send_bit(0); // bit 1
    send_bit(1); // bit 2
    send_bit(0); // bit 3
    send_bit(0); // bit 4
    send_bit(1); // bit 5
    send_bit(0); // bit 6
    send_bit(1); // bit 7
    
    // Complete the frame
    complete_frame();
    
    // Verify the output data
    if (rx_data == 8'hA5 && data_valid) begin
      $display("PASS: Received 0x%h as expected", rx_data);
    end else begin
      $display("FAIL: Expected 0xA5, got 0x%h (data_valid = %b)", rx_data, data_valid);
    end
    
    // Test Case 2: 8-bit MSB-first receive (0x5A)
    $display("\nTest Case 2: 8-bit MSB-first receive (0x5A)");
    #(CLK_PERIOD * 5);
    data_bits = 8;
    lsb_first = 0;
    
    // Send bits (MSB first): 0(bit7), 1, 0, 1, 1, 0, 1, 0 (0x5A = 01011010)
    send_bit(0); // bit 7
    send_bit(1); // bit 6
    send_bit(0); // bit 5
    send_bit(1); // bit 4
    send_bit(1); // bit 3
    send_bit(0); // bit 2
    send_bit(1); // bit 1
    send_bit(0); // bit 0
    
    complete_frame();
    
    if (rx_data == 8'h5A && data_valid) begin
      $display("PASS: Received 0x%h as expected", rx_data);
    end else begin
      $display("FAIL: Expected 0x5A, got 0x%h (data_valid = %b)", rx_data, data_valid);
    end
    
    // Test Case 3: 5-bit LSB-first receive (0x15)
    $display("\nTest Case 3: 5-bit LSB-first receive (0x15)");
    #(CLK_PERIOD * 5);
    data_bits = 5;
    lsb_first = 1;
    
    // Send bits (LSB first): 1(bit0), 0, 1, 0, 1 (0x15 = 10101)
    send_bit(1); // bit 0
    send_bit(0); // bit 1
    send_bit(1); // bit 2
    send_bit(0); // bit 3
    send_bit(1); // bit 4
    
    complete_frame();
    
    if ((rx_data & 5'h1F) == 5'h15 && data_valid) begin
      $display("PASS: Received 0x%h as expected", rx_data & 5'h1F);
    end else begin
      $display("FAIL: Expected 0x15, got 0x%h (data_valid = %b)", rx_data & 5'h1F, data_valid);
    end
    
    // Test Case 4: 9-bit LSB-first receive (0x1A5)
    $display("\nTest Case 4: 9-bit LSB-first receive (0x1A5)");
    #(CLK_PERIOD * 5);
    data_bits = 9;
    lsb_first = 1;
    
    // Send bits (LSB first): 1(bit0), 0, 1, 0, 0, 1, 0, 1, 1 (0x1A5 = 110100101)
    send_bit(1); // bit 0
    send_bit(0); // bit 1
    send_bit(1); // bit 2
    send_bit(0); // bit 3
    send_bit(0); // bit 4
    send_bit(1); // bit 5
    send_bit(0); // bit 6
    send_bit(1); // bit 7
    send_bit(1); // bit 8
    
    complete_frame();
    
    if (rx_data == 9'h1A5 && data_valid) begin
      $display("PASS: Received 0x%h as expected", rx_data);
    end else begin
      $display("FAIL: Expected 0x1A5, got 0x%h (data_valid = %b)", rx_data, data_valid);
    end
    
    // Test Case 5: Reset during reception
    $display("\nTest Case 5: Reset during reception");
    #(CLK_PERIOD * 5);
    data_bits = 8;
    lsb_first = 1;
    
    // Send partial data
    send_bit(1); // bit 0
    send_bit(1); // bit 1
    send_bit(1); // bit 2
    
    // Apply reset
    rst_n = 0;
    #(CLK_PERIOD * 2);
    rst_n = 1;
    #(CLK_PERIOD * 2);
    
    // Complete a new frame
    data_bits = 8;
    lsb_first = 1;
    
    // Send bits for 0x3C
    send_bit(0); // bit 0
    send_bit(0); // bit 1
    send_bit(1); // bit 2
    send_bit(1); // bit 3
    send_bit(1); // bit 4
    send_bit(1); // bit 5
    send_bit(0); // bit 6
    send_bit(0); // bit 7
    
    complete_frame();
    
    if (rx_data == 8'h3C && data_valid) begin
      $display("PASS: Reset handled correctly, received 0x%h", rx_data);
    end else begin
      $display("FAIL: After reset, expected 0x3C, got 0x%h (data_valid = %b)", rx_data, data_valid);
    end
    
    // End simulation
    #(CLK_PERIOD * 10);
    $display("\nAll tests completed");
    $finish;
  end
  
  // Task to send a bit
  task send_bit(input logic bit_value);
    @(posedge clk);
    bit_sample = bit_value;
    sample_enable = 1;
    is_data_bit = 1;
    bit_count = bit_count + 1;
    @(posedge clk);
    sample_enable = 0;
    @(posedge clk);
  endtask
  
  // Task to complete a frame
  task complete_frame();
    @(posedge clk);
    is_data_bit = 0;
    frame_complete = 1;
    @(posedge clk);
    frame_complete = 0;
    bit_count = 0;
    @(posedge clk);
  endtask

endmodule
