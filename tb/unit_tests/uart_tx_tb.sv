/*
Filename: uart_tx_tb.sv
Description: testbench for the uart transmitter module with enhanced debugging
*/
/*
xvlog -sv rtl/uart_tx.sv rtl/baudrate_gen.sv tb/unit_tests/uart_tx_tb.sv && xelab -R uart_tx_tb
*/
`timescale 1ns/1ps

module uart_tx_tb;
  // testbench parameters 
  localparam CLK_PERIOD = 20; // 50MHz clk
  localparam BAUD_RATE = 9600;
  localparam CYCLES_PER_BIT = 50_000_000 / BAUD_RATE;

  // DUT parameters to check for different configuration
  localparam int DATA_BITS = 8;
  localparam bit PARITY_EN = 1'b1;
  localparam bit PARITY_TYPE = 1'b0; // 0 even, 1 odd
  localparam int STOP_BITS = 1;

  // testbench signals
  logic clk;
  logic rst_n;
  logic tick;
  logic tick_16x; // Not used in this test
  logic baudgen_enable;
  logic tx_start;
  logic cts;
  logic [DATA_BITS-1:0] tx_data;
  logic tx_out;
  logic tx_busy;
  logic tx_done;

  // Use the provided baudrate generator
  baudrate_gen #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLING(16)
  ) baudgen (
    .clk(clk),
    .rst_n(rst_n),
    .enable(baudgen_enable),
    .tick(tick),
    .tick_16x(tick_16x)
  );
  
  // Instantiate the DUT
  uart_tx #(
    .DATA_BITS(DATA_BITS),
    .PARITY_EN(PARITY_EN),
    .PARITY_TYPE(PARITY_TYPE),
    .STOP_BITS(STOP_BITS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .tick(tick),
    .tx_start(tx_start),
    .cts(cts),
    .tx_data(tx_data),
    .tx_out(tx_out),
    .tx_busy(tx_busy),
    .tx_done(tx_done)
  );

  // clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Debug and timeout monitor
  initial begin
    int timeout_counter = 0;
    bit transmission_in_progress = 0;
    
    forever begin
      @(posedge clk);
      
      // Start counting when a transmission begins
      if (tx_busy && !transmission_in_progress) begin
        transmission_in_progress = 1;
        timeout_counter = 0;
        $display("[MONITOR] Transmission started at %0t", $time);
      end
      
      // Stop counting when transmission ends
      if (!tx_busy && transmission_in_progress) begin
        transmission_in_progress = 0;
        $display("[MONITOR] Transmission ended after %0d cycles at %0t", timeout_counter, $time);
      end
      
      // Count while transmission is ongoing
      if (transmission_in_progress) begin
        timeout_counter++;
        
        // Print status every 5000 clock cycles
        if (timeout_counter % 5000 == 0) begin
          $display("[MONITOR] Still in transmission after %0d cycles, state=%s, bit_count=%0d, tx_out=%b", 
                   timeout_counter, dut.current_state.name(), dut.bit_count, tx_out);
        end
        
        // Force end simulation if stuck for too long in a single transmission
        if (timeout_counter > CYCLES_PER_BIT * 20) begin
          $display("[ERROR] Transmission appears stuck! Current state: %s, bit_count: %0d, tx_out: %b", 
                  dut.current_state.name(), dut.bit_count, tx_out);
          $display("[ERROR] CYCLES_PER_BIT = %0d", CYCLES_PER_BIT);
          $finish;
        end
      end
    end
  end

  // calculate expected parity
  function logic expected_parity(logic [DATA_BITS-1:0] data);
    automatic logic parity = ^data;
    return PARITY_TYPE ? ~parity : parity; // invert for odd parity
  endfunction

  // monitor for transmitted data
  logic [15:0] received_data; // to store received frame
  int bit_count;
  logic exp_parity;

  task automatic monitor_tx();
    bit_count = 0;
    received_data = 0;

    // wait for start bit
    @(negedge tx_out);
    $display("[%0t] Start bit detected", $time);

    // sample in middle of bit time
    repeat (CYCLES_PER_BIT/2) @(posedge clk);

    // verify start bit is 0
    if (tx_out != 0) $error("[%0t] Invalid start bit: %b", $time, tx_out);

    // wait for the end of start bit
    repeat (CYCLES_PER_BIT/2) @(posedge clk);

    // capture data bits 
    for (int i = 0; i < DATA_BITS; i++) begin
      repeat(CYCLES_PER_BIT) @(posedge clk);
      received_data[i] = tx_out;
      $display("[%0t] Data bit %0d: %b", $time, i, tx_out);
    end

    // capture parity bit if enabled
    if (PARITY_EN) begin
      repeat (CYCLES_PER_BIT) @(posedge clk);
      exp_parity = expected_parity(tx_data);
      $display("[%0t] Parity bit: %b (Expected: %b)", $time, tx_out, exp_parity);
      if (tx_out != exp_parity) 
        $error("[%0t] Parity bit mismatch! Got: %b, Expected: %b", $time, tx_out, exp_parity);
    end
    
    // Capture stop bit(s)
    for (int i = 0; i < STOP_BITS; i++) begin
      repeat (CYCLES_PER_BIT) @(posedge clk);
      $display("[%0t] Stop bit %0d: %b", $time, i, tx_out);
      if (tx_out != 1) 
        $error("[%0t] Invalid stop bit %0d: %b", $time, i, tx_out);
    end

    $display("[%0t] Received data: 0x%h, Expected: 0x%h", 
              $time, received_data[DATA_BITS-1:0], tx_data);
    
    if (received_data[DATA_BITS-1:0] != tx_data)
      $error("[%0t] Data mismatch! Received: 0x%h, Expected: 0x%h", 
              $time, received_data[DATA_BITS-1:0], tx_data);
    else
      $display("[%0t] Data verified successfully", $time);
  endtask
  
  // main test sequence
  initial begin
    // initialize signals
    rst_n = 0;
    tx_start = 0;
    cts = 1;
    tx_data = 0;
    baudgen_enable = 0;
    
    // Reset pulse
    #(CLK_PERIOD * 5);
    rst_n = 1;
    #(CLK_PERIOD * 5);
    
    // Enable baudrate generator
    baudgen_enable = 1;
    
    // Give time for a few ticks to register
    repeat(5) @(posedge tick);
    $display("\n[%0t] Baudrate generator initialized. CYCLES_PER_BIT = %0d", $time, CYCLES_PER_BIT);
    
    // test case 1: basic transmission
    $display("\n[%0t] Test Case 1: Basic Transmission", $time);
    tx_data = 8'h55; // 01010101
    
    // Assert tx_start for multiple clock cycles to ensure proper latching
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    $display("[%0t] Waiting for transmission to start", $time);
    
    // Wait for start bit on tx_out
    wait(tx_busy);
    $display("[%0t] Transmission has started, tx_busy asserted", $time);
    
    fork
      monitor_tx();
      begin
        @(posedge tx_done);
        $display("[%0t] Transmission completed, tx_done signaled", $time);
      end
    join
    
    #(CLK_PERIOD * 10);
    
    // test case 2: flow control test (cts deasserted)
    $display("\n[%0t] Test Case 2: Flow Control Test", $time);
    tx_data = 8'hAA; // 10101010
    
    // First make sure we're completely idle
    @(posedge clk);
    wait(!tx_busy);  // Wait until the previous transmission is completely done
    repeat(10) @(posedge clk);  // Additional wait time for stability
    
    // Then deassert CTS
    cts = 0; // Deassert CTS
    #(CLK_PERIOD * 2);  // Give time for cts to propagate
    
    $display("[DEBUG] Before asserting tx_start: cts=%b, tx_busy=%b, tx_start_pending=%b", 
             cts, tx_busy, dut.tx_start_pending);
    
    // Now try to start transmission
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    $display("[DEBUG] After asserting tx_start: cts=%b, tx_busy=%b, tx_start_pending=%b", 
             cts, tx_busy, dut.tx_start_pending);
    
    // Check if tx_start_pending was incorrectly set
    #(CLK_PERIOD * 2);
    if (dut.tx_start_pending)
        $error("[%0t] tx_start_pending was incorrectly set despite CTS being deasserted", $time);
    
    // verify transmission doesn't start
    #(CLK_PERIOD * 20);
    if (tx_busy) $error("[%0t] Transmission started despite CTS being deasserted", $time);
    
    // assert cts to allow transmission
    $display("[DEBUG] Now asserting CTS to allow transmission");
    cts = 1;
    #(CLK_PERIOD * 2);
    
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    fork
      monitor_tx();
      begin
        @(posedge tx_done);
        $display("[%0t] Transmission completed after CTS assertion", $time);
      end
    join
    
    #(CLK_PERIOD * 10);
    
    // test case 3: multiple consecutive transmissions
    $display("\n[%0t] Test Case 3: Multiple Consecutive Transmissions", $time);
    
    for (int i = 0; i < 3; i++) begin
      tx_data = $urandom_range(0, 2**DATA_BITS-1);
      $display("[%0t] Starting transmission of data: 0x%h", $time, tx_data);
      
      tx_start = 1;
      repeat(5) @(posedge clk);
      tx_start = 0;
      
      fork
        monitor_tx();
        begin
          @(posedge tx_done);
          $display("[%0t] Transmission %0d completed", $time, i);
        end
      join
      
      #(CLK_PERIOD * 10);
    end
    
    // test case 4: cts deasserted during transmission
    $display("\n[%0t] Test Case 4: CTS Deasserted During Transmission", $time);
    tx_data = 8'h33; // 00110011
    
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    // wait for transmission to start
    wait(tx_busy);
    #(CLK_PERIOD * 10);
    
    // deassert cts during transmission
    cts = 0;
    $display("[%0t] CTS deasserted during transmission", $time);
    #(CLK_PERIOD * 20);
    
    // assert cts again to allow transmission to complete
    cts = 1;
    $display("[%0t] CTS reasserted", $time);
    
    // wait for transmission to complete
    @(posedge tx_done);
    $display("[%0t] Transmission completed after CTS pause", $time);
    
    #(CLK_PERIOD * 20);
    
    // test case 5: verify different data patterns
    $display("\n[%0t] Test Case 5: Different Data Patterns", $time);
    
    // All zeros
    tx_data = 8'h00;
    $display("[%0t] Testing all zeros: 0x%h", $time, tx_data);
    
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    fork
      monitor_tx();
      begin
        @(posedge tx_done);
        $display("[%0t] All zeros transmission completed", $time);
      end
    join
    
    #(CLK_PERIOD * 10);
    
    // All ones
    tx_data = 8'hFF;
    $display("[%0t] Testing all ones: 0x%h", $time, tx_data);
    
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    fork
      monitor_tx();
      begin
        @(posedge tx_done);
        $display("[%0t] All ones transmission completed", $time);
      end
    join
    
    #(CLK_PERIOD * 10);
    
    // Alternating pattern
    tx_data = 8'hA5;
    $display("[%0t] Testing alternating pattern: 0x%h", $time, tx_data);
    
    tx_start = 1;
    repeat(5) @(posedge clk);
    tx_start = 0;
    
    fork
      monitor_tx();
      begin
        @(posedge tx_done);
        $display("[%0t] Alternating pattern transmission completed", $time);
      end
    join
    
    #(CLK_PERIOD * 10);
    
    // end simulation
    $display("\n[%0t] Testbench completed successfully", $time);
    $finish;
  end
  
  // Global timeout
  initial begin
    #(CLK_PERIOD * 1000000); // adjusted timeout
    $display("[%0t] Global simulation timeout - something is wrong!", $time);
    $finish;
  end
  
  initial begin
    $dumpfile("uart_tx_tb.vcd");
    $dumpvars(0, uart_tx_tb);
  end

endmodule
