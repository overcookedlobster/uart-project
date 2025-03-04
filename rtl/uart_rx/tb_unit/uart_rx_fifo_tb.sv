/*
xvlog -sv uart_rx_fifo_tb.sv ../uart_rx_fifo.sv && xelab -R uart_rx_fifo_tb
*/
module uart_rx_fifo_tb();
  // Parameters
  localparam DATA_WIDTH = 8;
  localparam FIFO_DEPTH = 16;
  localparam ALMOST_FULL_THRESHOLD = 12;
  
  // Clock and reset
  logic clk = 0;
  logic rst_n;
  
  // FIFO interface signals
  logic [DATA_WIDTH-1:0] write_data;
  logic write_en;
  logic [DATA_WIDTH-1:0] read_data;
  logic read_en;
  logic fifo_clear;
  logic fifo_empty;
  logic fifo_full;
  logic fifo_almost_full;
  logic overflow;
  logic [$clog2(FIFO_DEPTH):0] data_count;
  
  // Clock generation
  always #5 clk = ~clk;
  
  // DUT instantiation
  uart_rx_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .ALMOST_FULL_THRESHOLD(ALMOST_FULL_THRESHOLD)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .write_data(write_data),
    .write_en(write_en),
    .read_data(read_data),
    .read_en(read_en),
    .fifo_clear(fifo_clear),
    .fifo_empty(fifo_empty),
    .fifo_full(fifo_full),
    .fifo_almost_full(fifo_almost_full),
    .overflow(overflow),
    .data_count(data_count)
  );
  
  // Store expected values for verification
  logic [DATA_WIDTH-1:0] expected_data[FIFO_DEPTH];
  
  // Test stimulus
  initial begin
    // Initialize signals
    rst_n = 0;
    write_data = '0;
    write_en = 0;
    read_en = 0;
    fifo_clear = 0;
    
    // Apply reset
    #20 rst_n = 1;
    
    // Test case 1: Write and read single value
    @(posedge clk);
    write_data = 8'hA5;
    write_en = 1;
    @(posedge clk);
    write_en = 0;
    
    // Check FIFO status
    @(posedge clk);
    assert(!fifo_empty) else $error("FIFO should not be empty after write");
    assert(data_count == 1) else $error("FIFO should have 1 entry");
    
    // Read the value back
    @(posedge clk);
    read_en = 1;
    @(posedge clk);
    read_en = 0;
    
    // Check read data
    @(posedge clk);
    assert(read_data == 8'hA5) else $error("Read data mismatch: Expected 8'hA5, got %h", read_data);
    
    // Test case 2: Fill the FIFO
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      @(posedge clk);
      write_data = i[7:0];
      write_en = 1;
      expected_data[i] = i[7:0]; // Store expected data
      @(posedge clk);
    end
    write_en = 0;
    
    // Check FIFO status
    @(posedge clk);
    assert(fifo_full) else $error("FIFO should be full");
    
    // Test case 3: Test overflow condition
    @(posedge clk);
    write_data = 8'hFF;
    write_en = 1;
    @(posedge clk);
    write_en = 0;
    
    // Check overflow flag
    @(posedge clk);
    assert(overflow) else $error("Overflow flag should be set");
    
    // Test case 4: Read all data
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      // Start the read
      @(posedge clk);
      read_en = 1;
      
      // Data becomes available on the next clock edge
      @(posedge clk);
      
      // Turn off read enable for this iteration
      read_en = 0;
      
      // Check the value
      assert(read_data == expected_data[i]) 
        else $error("Read data mismatch at index %0d. Expected %h, Got %h", 
                   i, expected_data[i], read_data);
      
      // Small delay between reads for observability
      @(posedge clk);
    end
    
    // Check FIFO status
    @(posedge clk);
    assert(fifo_empty) else $error("FIFO should be empty after reading all data");
    
    // Test case 5: Test FIFO clear
    // Write some data
    for (int i = 0; i < 5; i++) begin
      @(posedge clk);
      write_data = 8'h10 + i[7:0]; // Different pattern
      write_en = 1;
      @(posedge clk);
    end
    write_en = 0;
    
    // Clear the FIFO
    @(posedge clk);
    fifo_clear = 1;
    @(posedge clk);
    fifo_clear = 0;
    
    // Check FIFO status
    @(posedge clk);
    assert(fifo_empty) else $error("FIFO should be empty after clear");
    assert(data_count == 0) else $error("Data count should be 0 after clear");
    
    // Test case 6: Test almost full flag
    for (int i = 0; i < ALMOST_FULL_THRESHOLD - 1; i++) begin
      @(posedge clk);
      write_data = 8'h20 + i[7:0]; // Different pattern
      write_en = 1;
      @(posedge clk);
    end
    write_en = 0;
    
    // Should not be almost full yet
    @(posedge clk);
    assert(!fifo_almost_full) else $error("FIFO should not be almost full yet");
    
    // Write one more value to cross the threshold
    @(posedge clk);
    write_data = 8'hAA;
    write_en = 1;
    @(posedge clk);
    write_en = 0;
    
    // Now should be almost full
    @(posedge clk);
    assert(fifo_almost_full) else $error("FIFO should be almost full now");
    
    // End simulation
    $display("All tests completed!");
    #100 $finish;
  end
  
  // Optional: Monitor for debug
  initial begin
    $monitor("Time=%0t, empty=%b, full=%b, almost_full=%b, count=%0d", 
             $time, fifo_empty, fifo_full, fifo_almost_full, data_count);
  end
endmodule
