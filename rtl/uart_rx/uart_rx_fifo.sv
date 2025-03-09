module uart_rx_fifo #(
  parameter DATA_WIDTH = 8,             // Data width (8 for standard UART, 9 for 9-bit data)
  parameter FIFO_DEPTH = 16,            // FIFO depth (must be power of 2)
  parameter ALMOST_FULL_THRESHOLD = 12  // Almost full threshold value
) (
  input  logic                  clk,           // System clock
  input  logic                  rst_n,         // Active-low reset
  
  // Write interface
  input  logic [DATA_WIDTH-1:0] write_data,    // Data to write to FIFO
  input  logic                  write_en,      // Write enable
  
  // Read interface
  output logic [DATA_WIDTH-1:0] read_data,     // Data read from FIFO
  input  logic                  read_en,       // Read enable
  
  // Control and status
  input  logic                  fifo_clear,    // Clear/flush the FIFO
  output logic                  fifo_empty,    // FIFO empty flag
  output logic                  fifo_full,     // FIFO full flag
  output logic                  fifo_almost_full, // FIFO almost full flag
  output logic                  overflow,      // Overflow flag (write when full)
  output logic [$clog2(FIFO_DEPTH):0] data_count  // Number of entries in FIFO
);

  // Memory array to store FIFO data
  logic [DATA_WIDTH-1:0] fifo_mem [FIFO_DEPTH-1:0];
  
  // Pointers for read and write operations
  logic [$clog2(FIFO_DEPTH)-1:0] read_ptr;
  logic [$clog2(FIFO_DEPTH)-1:0] write_ptr;
  
  // Full/empty tracking
  logic [$clog2(FIFO_DEPTH):0] count;
  
  // Keep track of overflow condition
  logic overflow_r;
  
  // Status flags
  assign fifo_empty = (count == 0);
  assign fifo_full = (count == FIFO_DEPTH);
  assign fifo_almost_full = (count > ALMOST_FULL_THRESHOLD);
  assign overflow = overflow_r;
  assign data_count = count;
  
  // CRITICAL CHANGE: Asynchronous read - output data directly from memory
  // This avoids the register delay and makes read data available immediately
  assign read_data = fifo_empty ? '0 : fifo_mem[read_ptr];
  
  // FIFO control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      read_ptr <= '0;
      write_ptr <= '0;
      count <= '0;
      overflow_r <= 1'b0;
    end
    else if (fifo_clear) begin
      read_ptr <= '0;
      write_ptr <= '0;
      count <= '0;
      overflow_r <= 1'b0;
    end
    else begin
      // Update read pointer on read operation
      if (read_en && !fifo_empty) begin
        read_ptr <= read_ptr + 1'b1;
        
        // Update count when reading (unless simultaneously writing)
        if (!(write_en && !fifo_full)) begin
          count <= count - 1'b1;
        end
      end
      
      // Handle write operation
      if (write_en && !fifo_full) begin
        fifo_mem[write_ptr] <= write_data;
        write_ptr <= write_ptr + 1'b1;
        
        // Update count when writing (unless simultaneously reading)
        if (!(read_en && !fifo_empty)) begin
          count <= count + 1'b1;
        end
      end
      
      // Handle overflow condition
      if (write_en && fifo_full) begin
        overflow_r <= 1'b1;
      end
      else if (fifo_clear) begin
        overflow_r <= 1'b0;
      end
    end
  end

endmodule
