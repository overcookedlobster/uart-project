`timescale 1ns/1ps

module baudrate_gen_tb;

  // Test parameters
  localparam CLK_PERIOD_NS = 20;  // 50 MHz clock
  localparam TEST_BAUD_RATE = 9600;
  localparam TEST_OVERSAMPLING = 16;
  
  // Expected tick periods
  localparam real EXPECTED_TICK_NS = 1_000_000_000.0 / TEST_BAUD_RATE;  // ns
  localparam real EXPECTED_TICK_16X_NS = EXPECTED_TICK_NS / TEST_OVERSAMPLING;
  
  // Divider values
  localparam int EXPECTED_BAUD_DIV = 50_000_000 / TEST_BAUD_RATE - 1;
  localparam int EXPECTED_BAUD_DIV_16X = 50_000_000 / (TEST_BAUD_RATE * TEST_OVERSAMPLING) - 1;
  
  // DUT signals
  logic clk;
  logic rst_n;
  logic enable;
  logic tick;
  logic tick_16x;
  
  // Timing measurement
  time last_tick_time;
  time last_tick_16x_time;
  time tick_period;
  time tick_16x_period;
  
  // Statistics
  int tick_count;
  int tick_16x_count;
  real avg_tick_period;
  real avg_tick_16x_period;
  real tick_error_pct;
  real tick_16x_error_pct;
  
  // Instantiate the DUT
  baudrate_gen #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(TEST_BAUD_RATE),
    .OVERSAMPLING(TEST_OVERSAMPLING)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .tick(tick),
    .tick_16x(tick_16x)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end
  
  // Monitor ticks
  always @(posedge tick) begin
    if (last_tick_time != 0) begin
      tick_period = $time - last_tick_time;
      tick_count = tick_count + 1;
      avg_tick_period = ((tick_count-1) * avg_tick_period + tick_period) / tick_count;
      $display("Tick detected at %0t ns, period = %0t ns (expected ~%0.2f ns)", 
                $time, tick_period, EXPECTED_TICK_NS);
    end
    last_tick_time = $time;
  end
  
  always @(posedge tick_16x) begin
    if (last_tick_16x_time != 0) begin
      tick_16x_period = $time - last_tick_16x_time;
      tick_16x_count = tick_16x_count + 1;
      avg_tick_16x_period = ((tick_16x_count-1) * avg_tick_16x_period + tick_16x_period) / tick_16x_count;
      $display("Tick16x detected at %0t ns, period = %0t ns (expected ~%0.2f ns)", 
                $time, tick_16x_period, EXPECTED_TICK_16X_NS);
    end
    last_tick_16x_time = $time;
  end
  
  // Test sequence
  initial begin
    // Initialize values
    rst_n = 0;
    enable = 0;
    last_tick_time = 0;
    last_tick_16x_time = 0;
    tick_count = 0;
    tick_16x_count = 0;
    avg_tick_period = 0;
    avg_tick_16x_period = 0;
    
    // Print test parameters
    $display("Testing baudrate_gen with:");
    $display("  CLK_FREQ_HZ = 50,000,000 (50 MHz)");
    $display("  BAUD_RATE = %0d", TEST_BAUD_RATE);
    $display("  OVERSAMPLING = %0d", TEST_OVERSAMPLING);
    $display("  Expected BAUD_DIV = %0d", EXPECTED_BAUD_DIV);
    $display("  Expected BAUD_DIV_16X = %0d", EXPECTED_BAUD_DIV_16X);
    $display("  Expected tick period = %0.2f ns", EXPECTED_TICK_NS);
    $display("  Expected tick_16x period = %0.2f ns", EXPECTED_TICK_16X_NS);
    
    // Apply reset
    #100;
    rst_n = 1;
    #100;
    
    // Enable and collect data for some time
    enable = 1;
    
    // Wait for multiple ticks to be collected
    #(EXPECTED_TICK_NS * 20);
    
    // Check results
    $display("\nTest Results:");
    $display("  Collected %0d standard ticks", tick_count);
    $display("  Average tick period = %0.2f ns (expected ~%0.2f ns)", 
              avg_tick_period, EXPECTED_TICK_NS);
    
    $display("  Collected %0d oversampling ticks", tick_16x_count);
    $display("  Average tick_16x period = %0.2f ns (expected ~%0.2f ns)", 
              avg_tick_16x_period, EXPECTED_TICK_16X_NS);
    
    // Calculate errors
    tick_error_pct = ((avg_tick_period - EXPECTED_TICK_NS) / EXPECTED_TICK_NS) * 100;
    tick_16x_error_pct = ((avg_tick_16x_period - EXPECTED_TICK_16X_NS) / EXPECTED_TICK_16X_NS) * 100;
    
    $display("\nError Analysis:");
    $display("  Tick period error: %0.2f%%", tick_error_pct);
    $display("  Tick_16x period error: %0.2f%%", tick_16x_error_pct);
    
    // Test disable functionality
    enable = 0;
    $display("\nDisabling baudrate generator...");
    #(EXPECTED_TICK_NS * 5);
    
    // Check if ticks stopped
    if (tick || tick_16x) begin
      $display("ERROR: Ticks did not stop when enable=0");
    end else begin
      $display("Ticks successfully stopped when enable=0");
    end
    
    // Re-enable
    $display("\nRe-enabling baudrate generator...");
    enable = 1;
    #(EXPECTED_TICK_NS * 5);
    
    // Finish simulation
    $display("\nSimulation complete");
    $finish;
  end

endmodule
