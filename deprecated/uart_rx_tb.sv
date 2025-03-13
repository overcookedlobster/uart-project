/*
Filename: uart_rx_tb.sv
Description: Testbench for the enhanced UART receiver with comprehensive testing
*/
/*
xvlog -sv rtl/uart_rx.sv tb/unit_tests/uart_rx_tb.sv rtl/baudrate_gen.sv && xelab -R uart_rx_tb
*/
`timescale 1ns/1ps

module uart_rx_tb;
  // Testbench parameters
  localparam CLK_PERIOD = 20;     // 50MHz clock
  localparam BAUD_RATE = 9600;
  localparam CYCLES_PER_BIT = 50_000_000 / BAUD_RATE;
  localparam CYCLES_PER_BIT_16X = CYCLES_PER_BIT / 16;
  
  // DUT parameters to check different configurations
  localparam int DATA_BITS = 8;
  localparam bit PARITY_EN = 1'b1;
  localparam bit PARITY_TYPE = 1'b0; // 0=even, 1=odd
  localparam int STOP_BITS = 1;
  localparam int FIFO_DEPTH = 8;
  
  // Testbench signals
  logic clk;
  logic rst_n;
  logic tick_16x;
  logic baudgen_enable;
  logic rx_in;
  logic clear_error;
  logic read_data;
  logic rts;
  logic [DATA_BITS-1:0] rx_data;
  logic rx_data_ready;
  logic frame_error;
  logic parity_error;
  logic overrun_error;
  logic break_detect;
  
  // Use the provided baudrate generator
  baudrate_gen #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLING(16)
  ) baudgen (
    .clk(clk),
    .rst_n(rst_n),
    .enable(baudgen_enable),
    .tick(),
    .tick_16x(tick_16x)
  );
  
  // Instantiate the DUT
  uart_rx #(
    .DATA_BITS(DATA_BITS),
    .PARITY_EN(PARITY_EN),
    .PARITY_TYPE(PARITY_TYPE),
    .STOP_BITS(STOP_BITS),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .tick_16x(tick_16x),
    .rx_in(rx_in),
    .clear_error(clear_error),
    .read_data(read_data),
    .rts(rts),
    .rx_data(rx_data),
    .rx_data_ready(rx_data_ready),
    .frame_error(frame_error),
    .parity_error(parity_error),
    .overrun_error(overrun_error),
    .break_detect(break_detect)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // Calculate expected parity
  function logic expected_parity(logic [DATA_BITS-1:0] data);
    automatic logic parity = ^data;
    return PARITY_TYPE ? ~parity : parity; // invert for odd parity
  endfunction
  
  // Task to send a serial byte
  task automatic send_serial_byte(
    input logic [DATA_BITS-1:0] data,
    input logic parity_bit = 0,
    input logic send_correct_parity = 1,
    input logic send_correct_stop = 1
  );
    // Calculate parity if sending correct parity
    logic correct_parity = expected_parity(data);
    logic actual_parity = send_correct_parity ? correct_parity : ~correct_parity;
    
    $display("[%0t] Sending data: 0x%h (Parity: %b, Stop: %b)", 
             $time, data, actual_parity, send_correct_stop);
    
    // Start bit
    rx_in = 1'b0;
    repeat (16*1) @(posedge tick_16x);
    
    // Data bits (LSB first)
    for (int i = 0; i < DATA_BITS; i++) begin
      rx_in = data[i];
      repeat (16*1) @(posedge tick_16x);
    end
    
    // Parity bit if enabled
    if (PARITY_EN) begin
      rx_in = actual_parity;
      repeat (16*1) @(posedge tick_16x);
    end
    
    // Stop bit(s)
    if (send_correct_stop) begin
      rx_in = 1'b1;
    end else begin
      rx_in = 1'b0; // Incorrect stop bit to generate framing error
    end
    
    repeat (16*1) @(posedge tick_16x);
    
    // Second stop bit if configured
    if (STOP_BITS == 2) begin
      rx_in = 1'b1;
      repeat (16*1) @(posedge tick_16x);
    end
    
    // Return to idle state (high)
    rx_in = 1'b1;
    repeat (16*1) @(posedge tick_16x);
  endtask
  
  // Task to generate a break condition
  task automatic send_break(input int duration_bits = 10);
    $display("[%0t] Generating BREAK condition for %0d bit times", $time, duration_bits);
    
    // Hold line low for specified duration
    rx_in = 1'b0;
    repeat (16*duration_bits) @(posedge tick_16x);
    
    // Return to idle
    rx_in = 1'b1;
    repeat (16*1) @(posedge tick_16x);
  endtask
  
  // Task to generate noise/glitches
  task automatic generate_noise(input int position_16ths, input int duration_clocks);
      int current_pos = 0;
      logic original_value; // Properly declare the variable
      
      // Wait until the specified position within the current bit
      while (current_pos < position_16ths) begin
        @(posedge tick_16x);
        current_pos++;
      end
      
      // Generate the glitch
      original_value = rx_in; // Store the current value
      $display("[%0t] Injecting noise at position %0d/16 for %0d clocks", 
               $time, position_16ths, duration_clocks);
      
      rx_in = ~original_value;
      repeat (duration_clocks) @(posedge clk);
      rx_in = original_value;
    endtask
  
  // Test patterns used in Test Case 10
  logic [7:0] test_patterns [3];

  // Test sequence
  initial begin
    // Initialize signals
    rst_n = 0;
    rx_in = 1;
    clear_error = 0;
    read_data = 0;
    baudgen_enable = 0;
    
    // Reset pulse
    #(CLK_PERIOD * 5);
    rst_n = 1;
    #(CLK_PERIOD * 5);
    
    // Enable baudrate generator
    baudgen_enable = 1;
    
    // Wait for a few ticks to stabilize
    repeat (5) @(posedge tick_16x);
    $display("\n[%0t] Baudrate generator initialized", $time);
    
    // Test Case 1: Basic Reception
    $display("\n[%0t] Test Case 1: Basic Reception (0x55)", $time);
    send_serial_byte(8'h55);
    
    // Wait for data ready and check result
    fork
      begin
        wait(rx_data_ready);
        $display("[%0t] Data received: 0x%h (Expected: 0x55)", $time, rx_data);
        
        if (rx_data !== 8'h55)
          $error("Test Case 1 Failed - Wrong data received: 0x%h", rx_data);
        else
          $display("Test Case 1 Passed!");
        
        // Read the data
        read_data = 1;
        @(posedge clk);
        read_data = 0;
        @(posedge clk);
      end
      begin
        // Timeout after 20 bit periods
        repeat (16 * 20) @(posedge tick_16x);
        if (!rx_data_ready)
          $error("Test Case 1 Failed - Timeout waiting for data ready");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 2: Parity Error
    $display("\n[%0t] Test Case 2: Parity Error", $time);
    send_serial_byte(8'hAA, 0, 0); // Send with incorrect parity
    
    // Wait for reception and check error flags
    fork
      begin
        wait(rx_data_ready || parity_error);
        #(CLK_PERIOD * 2); // Give time for error flags to propagate
        
        $display("[%0t] Data received: 0x%h with parity_error=%b", 
                $time, rx_data, parity_error);
        
        if (!parity_error)
          $error("Test Case 2 Failed - Parity error not detected");
        else
          $display("Test Case 2 Passed!");
        
        // Clear error flags
        clear_error = 1;
        @(posedge clk);
        clear_error = 0;
        
        // Read the data (even with error)
        read_data = 1;
        @(posedge clk);
        read_data = 0;
      end
      begin
        // Timeout after 20 bit periods
        repeat (16 * 20) @(posedge tick_16x);
        if (!parity_error && !rx_data_ready)
          $error("Test Case 2 Failed - Timeout waiting for reception");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 3: Framing Error
    $display("\n[%0t] Test Case 3: Framing Error", $time);
    send_serial_byte(8'h33, 0, 1, 0); // Send with incorrect stop bit
    
    // Wait for reception and check error flags
    fork
      begin
        wait(rx_data_ready || frame_error);
        #(CLK_PERIOD * 2); // Give time for error flags to propagate
        
        $display("[%0t] Data received: 0x%h with frame_error=%b", 
                $time, rx_data, frame_error);
        
        if (!frame_error)
          $error("Test Case 3 Failed - Framing error not detected");
        else
          $display("Test Case 3 Passed!");
        
        // Clear error flags
        clear_error = 1;
        @(posedge clk);
        clear_error = 0;
        
        // Read the data (even with error)
        read_data = 1;
        @(posedge clk);
        read_data = 0;
      end
      begin
        // Timeout after 20 bit periods
        repeat (16 * 20) @(posedge tick_16x);
        if (!frame_error && !rx_data_ready)
          $error("Test Case 3 Failed - Timeout waiting for reception");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 4: Break Detection
    $display("\n[%0t] Test Case 4: Break Detection", $time);
    send_break(12); // Send break condition for 12 bit times
    
    // Wait for break detection
    fork
      begin
        wait(break_detect);
        $display("[%0t] Break condition detected", $time);
        $display("Test Case 4 Passed!");
        
        // Clear error flags
        clear_error = 1;
        @(posedge clk);
        clear_error = 0;
      end
      begin
        // Timeout after 20 bit periods
        repeat (16 * 20) @(posedge tick_16x);
        if (!break_detect)
          $error("Test Case 4 Failed - Break not detected");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 5: Noise Immunity
    $display("\n[%0t] Test Case 5: Noise Immunity Test", $time);
    
    // Start sending a normal byte but inject noise
    fork
      begin
        send_serial_byte(8'h77);
      end
      begin
        // Inject noise in the middle of a data bit
        // but not at sample points (positions 6,7,8)
        #(CLK_PERIOD * 10);
        generate_noise(3, 2);  // Position 3/16, duration 2 clocks
        #(CLK_PERIOD * 20);
        generate_noise(12, 2); // Position 12/16, duration 2 clocks
      end
    join
    
    // Check if data was received correctly despite noise
    fork
      begin
        wait(rx_data_ready);
        $display("[%0t] Data received with noise: 0x%h (Expected: 0x77)", 
                $time, rx_data);
        
        if (rx_data !== 8'h77)
          $error("Test Case 5 Failed - Noise affected data: 0x%h", rx_data);
        else
          $display("Test Case 5 Passed - Noise correctly filtered!");
        
        // Read the data
        read_data = 1;
        @(posedge clk);
        read_data = 0;
      end
      begin
        // Timeout after 20 bit periods
        repeat (16 * 20) @(posedge tick_16x);
        if (!rx_data_ready)
          $error("Test Case 5 Failed - Timeout waiting for data ready");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 6: Overrun Detection
    $display("\n[%0t] Test Case 6: Overrun Detection", $time);
    
    // First clear any pending data
    if (rx_data_ready) begin
      read_data = 1;
      @(posedge clk);
      read_data = 0;
      @(posedge clk);
    end
    
    // Fill the FIFO and then send one more byte
    $display("Filling FIFO with %0d bytes...", FIFO_DEPTH);
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      send_serial_byte(8'hA0 + i);
      wait(rx_data_ready);
      $display("  Received byte %0d: 0x%h", i, rx_data);
      #(CLK_PERIOD * 5);
    end
    
    // Send one more byte without reading any - should cause overrun
    $display("Sending one more byte to cause overrun...");
    send_serial_byte(8'hFF);
    
    // Check for overrun error
    fork
      begin
        wait(overrun_error);
        $display("[%0t] Overrun error detected!", $time);
        $display("Test Case 6 Passed!");
        
        // Clear error flags
        clear_error = 1;
        @(posedge clk);
        clear_error = 0;

        // Read out all the data
        while (rx_data_ready) begin
          read_data = 1;
          @(posedge clk);
          read_data = 0;
          @(posedge clk);
          @(posedge clk);
        end
      end
      begin
        // Timeout after 30 bit periods
        repeat (16 * 30) @(posedge tick_16x);
        if (!overrun_error)
          $error("Test Case 6 Failed - Overrun error not detected");
      end
    join_any
    disable fork;
    
    #(CLK_PERIOD * 10);
    
    // Test Case 7: Flow Control (RTS)
    $display("\n[%0t] Test Case 7: Flow Control (RTS)", $time);
    
    // Reset FIFO by reading any remaining data
    while (rx_data_ready) begin
      read_data = 1;
      @(posedge clk);
      read_data = 0;
      @(posedge clk);
    end
    
    // Clear any errors
    clear_error = 1;
    @(posedge clk);
    clear_error = 0;
    @(posedge clk);
    
    // Monitor RTS signal while filling FIFO
    $display("Monitoring RTS signal while filling FIFO...");
    fork
      begin
        // Send multiple bytes to fill FIFO
        for (int i = 0; i < FIFO_DEPTH-1; i++) begin
          send_serial_byte(8'h10 + i);
          #(CLK_PERIOD * 5);
        end
      end
      begin
        // Monitor RTS signal
        automatic int rts_deasserted = 0;
        for (int i = 0; i < FIFO_DEPTH+5; i++) begin
          if (!rts) begin
            rts_deasserted = 1;
            $display("[%0t] RTS deasserted after %0d bytes", $time, i);
          end
          @(posedge clk);
          repeat(100) @(posedge clk);
        end
        
        if (rts_deasserted)
          $display("Test Case 7 Passed - RTS properly deasserted!");
        else
          $error("Test Case 7 Failed - RTS not deasserted with FIFO filling");
      end
    join_any
    disable fork;
    
    // Read out all the data to clear FIFO
    $display("Clearing FIFO...");
    while (rx_data_ready) begin
      read_data = 1;
      @(posedge clk);
      read_data = 0;
      @(posedge clk);
      @(posedge clk);
    end
    
    #(CLK_PERIOD * 10);
    
    // Test Case 8: Multiple Consecutive Bytes
    $display("\n[%0t] Test Case 8: Multiple Consecutive Bytes", $time);
    
    // Send 3 bytes with minimum inter-byte spacing
    $display("Sending 3 consecutive bytes with minimum spacing...");
    for (int i = 0; i < 3; i++) begin
      automatic logic [7:0] test_data = 8'hC0 + i;
      send_serial_byte(test_data);
      
      // Wait for reception and verify
      fork
        begin
          wait(rx_data_ready);
          $display("[%0t] Received byte %0d: 0x%h (Expected: 0x%h)", 
                  $time, i, rx_data, test_data);
          
          if (rx_data !== test_data)
            $error("Byte %0d mismatch: Got 0x%h, Expected 0x%h", i, rx_data, test_data);
          
          // Read the data
          read_data = 1;
          @(posedge clk);
          read_data = 0;
          @(posedge clk);
        end
        begin
          // Timeout after 20 bit periods
          repeat (16 * 20) @(posedge tick_16x);
          if (!rx_data_ready)
            $error("Timeout waiting for byte %0d", i);
        end
      join_any
      disable fork;
    end
    
    // Check final status
    if (!frame_error && !parity_error && !overrun_error)
      $display("Test Case 8 Passed!");
    else
      $error("Test Case 8 Failed - Unexpected errors detected");
    
    #(CLK_PERIOD * 10);
    
    // Test Case 9: Glitch in Start Bit
    $display("\n[%0t] Test Case 9: Glitch in Start Bit", $time);
    
    // Create a start bit with a glitch back to high in the middle
    rx_in = 1'b1;  // Idle
    repeat (16) @(posedge tick_16x);
    
    // Start bit
    rx_in = 1'b0;
    repeat (3) @(posedge tick_16x);
    
    // Glitch in start bit (back to high briefly)
    rx_in = 1'b1;
    repeat (2) @(posedge tick_16x);
    rx_in = 1'b0;
    repeat (11) @(posedge tick_16x);
    
    // Send remaining valid frame
    // Data bits (0xAA = 10101010)
    rx_in = 1'b0; repeat (16) @(posedge tick_16x); // Bit 0
    rx_in = 1'b1; repeat (16) @(posedge tick_16x); // Bit 1
    rx_in = 1'b0; repeat (16) @(posedge tick_16x); // Bit 2
    rx_in = 1'b1; repeat (16) @(posedge tick_16x); // Bit 3
    rx_in = 1'b0; repeat (16) @(posedge tick_16x); // Bit 4
    rx_in = 1'b1; repeat (16) @(posedge tick_16x); // Bit 5
    rx_in = 1'b0; repeat (16) @(posedge tick_16x); // Bit 6
    rx_in = 1'b1; repeat (16) @(posedge tick_16x); // Bit 7
    
    // Parity (for 0xAA, even parity is 0)
    if (PARITY_EN) begin
      rx_in = 1'b0;
      repeat (16) @(posedge tick_16x);
    end
    
    // Stop bit
    rx_in = 1'b1;
    repeat (16 * STOP_BITS) @(posedge tick_16x);
    
    // Check if receiver properly rejected the glitchy start bit
    // by looking for timing - if it processed the frame, rx_data_ready would assert
    repeat (50) @(posedge clk);
    
    if (!rx_data_ready) begin
      $display("Test Case 9 Passed - Receiver properly rejected glitchy start bit!");
    end else begin
      $error("Test Case 9 Failed - Receiver accepted frame with glitchy start bit");
      
      // Clear the data
      read_data = 1;
      @(posedge clk);
      read_data = 0;
    end
    
    #(CLK_PERIOD * 10);
    
    // Test Case 10: Variable Width Data
    $display("\n[%0t] Test Case 10: Different Data Patterns", $time);

    // Initialize test patterns
    test_patterns[0] = 8'h00;
    test_patterns[1] = 8'hFF;
    test_patterns[2] = 8'hA5;
    
    for (int i = 0; i < 3; i++) begin
      $display("Sending pattern %0d: 0x%h", i, test_patterns[i]);
      send_serial_byte(test_patterns[i]);
      
      // Wait for reception and verify
      fork
        begin
          wait(rx_data_ready);
          $display("[%0t] Received: 0x%h (Expected: 0x%h)", 
                  $time, rx_data, test_patterns[i]);
          
          if (rx_data !== test_patterns[i])
            $error("Data mismatch: Got 0x%h, Expected 0x%h", rx_data, test_patterns[i]);
          
          // Read the data
          read_data = 1;
          @(posedge clk);
          read_data = 0;
          @(posedge clk);
        end
        begin
          // Timeout after 20 bit periods
          repeat (16 * 20) @(posedge tick_16x);
          if (!rx_data_ready)
            $error("Timeout waiting for pattern %0d", i);
        end
      join_any
      disable fork;
    end
    
    $display("Test Case 10 Passed!");
    
    // End simulation
    $display("\n[%0t] All tests completed", $time);
    $finish;
  end
  
  // Global timeout
  initial begin
    #(CLK_PERIOD * 2000000); // Adjusted timeout
    $display("[%0t] Global simulation timeout - something is wrong!", $time);
    $finish;
  end
  
  // Generate VCD file for waveform viewing
  initial begin
    $dumpfile("uart_rx_tb.vcd");
    $dumpvars(0, uart_rx_tb);
  end

endmodule
