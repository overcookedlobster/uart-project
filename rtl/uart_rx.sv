/*
Filename: uart_rx.sv
Description: Enhanced UART receiver with improved sampling and error detection
*/

`timescale 1ns/1ps

module uart_rx #(
  parameter int DATA_BITS = 8,
  parameter bit PARITY_EN = 1'b1,
  parameter bit PARITY_TYPE = 1'b0,  // 0=even, 1=odd
  parameter int STOP_BITS = 1,
  parameter int FIFO_DEPTH = 8       // Depth of the receive FIFO
) (
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   tick_16x,    // 16x oversampling tick
  input  logic                   rx_in,       // Serial input
  input  logic                   clear_error, // Clear error flags
  input  logic                   read_data,   // Signal to read data from FIFO
  output logic                   rts,         // Request to Send (flow control)
  output logic [DATA_BITS-1:0]   rx_data,     // Parallel data output
  output logic                   rx_data_ready, // Data ready flag
  output logic                   frame_error,   // Framing error flag
  output logic                   parity_error,  // Parity error flag
  output logic                   overrun_error, // Overrun error flag
  output logic                   break_detect   // Break condition detected
);

  // Define states
  typedef enum logic [3:0] {
    S_IDLE,
    S_START_BIT,
    S_DATA_BITS,
    S_PARITY_BIT,
    S_STOP_BIT1,
    S_STOP_BIT2,
    S_BREAK
  } state_t;
  
  // Internal registers
  state_t current_state;
  logic [3:0] bit_count;              // Track which bit we're receiving
  logic [3:0] sample_count;           // Count 16x samples
  logic [DATA_BITS-1:0] rx_shift_reg; // Shift register for incoming data
  logic [DATA_BITS-1:0] rx_fifo[FIFO_DEPTH]; // Simple FIFO implementation
  logic [$clog2(FIFO_DEPTH):0] fifo_wr_ptr;  // Write pointer
  logic [$clog2(FIFO_DEPTH):0] fifo_rd_ptr;  // Read pointer
  
  // Synchronization registers
  logic rx_in_meta, rx_in_sync, rx_in_filtered;
  logic [2:0] rx_in_history;       // For glitch filtering
  
  // FIFO status signals
  logic fifo_full;
  logic fifo_empty;
  logic rx_done;                   // Reception complete flag
  
  // Error detection
  logic start_bit_error;
  logic idle_line_detected;
  logic break_counter_active;
  logic [4:0] break_counter;
  
  // Majority vote for bit sampling (3 samples)
  logic [2:0] bit_samples;
  logic sampled_bit;
  logic expected_parity;
  
  // Double-flop synchronizer for rx_in
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_in_meta <= 1'b1;
      rx_in_sync <= 1'b1;
    end else begin
      rx_in_meta <= rx_in;
      rx_in_sync <= rx_in_meta;
    end
  end
  
  // Glitch filter - track last 3 samples
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_in_history <= 3'b111;
      rx_in_filtered <= 1'b1;
    end else if (tick_16x) begin
      rx_in_history <= {rx_in_history[1:0], rx_in_sync};
      
      // Filter glitches - majority vote of last 3 samples
      rx_in_filtered <= (rx_in_history[0] & rx_in_history[1]) | 
                        (rx_in_history[1] & rx_in_sync) | 
                        (rx_in_history[0] & rx_in_sync);
    end
  end
  
  // Edge detection
  wire falling_edge = (rx_in_history[2] & ~rx_in_history[1]);
  
  // FIFO control signals
  assign fifo_empty = (fifo_rd_ptr == fifo_wr_ptr);
  assign fifo_full = ((fifo_wr_ptr[$clog2(FIFO_DEPTH)] != fifo_rd_ptr[$clog2(FIFO_DEPTH)]) && 
                      (fifo_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == fifo_rd_ptr[$clog2(FIFO_DEPTH)-1:0]));
  
  // Data ready indication
  assign rx_data_ready = !fifo_empty;
  
  // RTS flow control - deassert when FIFO is almost full
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rts <= 1'b1; // Active low, so default is ready to receive
    end else begin
      // Assert RTS when FIFO is less than 75% full
      rts <= ((fifo_wr_ptr - fifo_rd_ptr) < (3*FIFO_DEPTH/4));
    end
  end
  
  // Break detection logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      break_counter <= '0;
      break_counter_active <= 1'b0;
      break_detect <= 1'b0;
    end else if (tick_16x) begin
      // Start counting when line is continuously low
      if (rx_in_filtered == 1'b0) begin
        if (!break_counter_active) begin
          break_counter_active <= 1'b1;
          break_counter <= '0;
        end else if (break_counter < 5'd31) begin
          break_counter <= break_counter + 1'b1;
        end
      end else begin
        break_counter_active <= 1'b0;
      end
      
      // Break is detected after line is low for more than one character time
      if (break_counter > 20) // More than one complete frame time
        break_detect <= 1'b1;
      else if (clear_error)
        break_detect <= 1'b0;
    end
  end
  
  // FIFO read logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_rd_ptr <= '0;
      rx_data <= '0;
    end else if (read_data && !fifo_empty) begin
      // Read data from FIFO when requested
      rx_data <= rx_fifo[fifo_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
      fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
    end
  end
  
  // FIFO write and error handling
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_wr_ptr <= '0;
      frame_error <= 1'b0;
      parity_error <= 1'b0;
      overrun_error <= 1'b0;
    end else begin
      // Write received data to FIFO
      if (rx_done) begin
        if (!fifo_full) begin
          rx_fifo[fifo_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift_reg;
          fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
        end else begin
          overrun_error <= 1'b1;
        end
      end
      
      // Clear error flags
      if (clear_error) begin
        frame_error <= 1'b0;
        parity_error <= 1'b0;
        overrun_error <= 1'b0;
      end
    end
  end
  
  // Main receiver state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= S_IDLE;
      bit_count <= 0;
      sample_count <= 0;
      rx_shift_reg <= '0;
      rx_done <= 1'b0;
      start_bit_error <= 1'b0;
    end else begin
      // Default assignments
      rx_done <= 1'b0;
      
      // Only process on tick_16x
      if (tick_16x) begin
        case (current_state)
          S_IDLE: begin
            // Detect start bit (falling edge)
            if (falling_edge) begin
              current_state <= S_START_BIT;
              sample_count <= 0;
              start_bit_error <= 1'b0;
            end
          end
          
          S_START_BIT: begin
            // Count samples
            sample_count <= sample_count + 1'b1;
            
            // Sample around the middle of the bit (7-8-9)
            if (sample_count == 4'd7) begin
              bit_samples[0] <= rx_in_filtered;
            end else if (sample_count == 4'd8) begin
              bit_samples[1] <= rx_in_filtered;
            end else if (sample_count == 4'd9) begin
              bit_samples[2] <= rx_in_filtered;
              
              // Verify start bit is low (majority vote)
              sampled_bit <= ((rx_in_filtered & bit_samples[1]) | 
                             (bit_samples[1] & bit_samples[0]) | 
                             (rx_in_filtered & bit_samples[0]));
                             
              start_bit_error <= ((rx_in_filtered & bit_samples[1]) | 
                                 (bit_samples[1] & bit_samples[0]) | 
                                 (rx_in_filtered & bit_samples[0]));
            end
            
            // Move to data bits state at the end of start bit
            if (sample_count == 4'd15) begin
              if (!start_bit_error) begin
                current_state <= S_DATA_BITS;
                bit_count <= 0;
                sample_count <= 0;
              end else begin
                current_state <= S_IDLE;  // Invalid start bit, return to idle
              end
            end
          end
          
          S_DATA_BITS: begin
            // Count samples
            sample_count <= sample_count + 1'b1;
            
            // Sample around the middle of the bit
            if (sample_count == 4'd7) begin
              bit_samples[0] <= rx_in_filtered;
            end else if (sample_count == 4'd8) begin
              bit_samples[1] <= rx_in_filtered;
            end else if (sample_count == 4'd9) begin
              bit_samples[2] <= rx_in_filtered;
              
              // Majority vote sampling
              sampled_bit <= ((rx_in_filtered & bit_samples[1]) | 
                             (bit_samples[1] & bit_samples[0]) | 
                             (rx_in_filtered & bit_samples[0]));
            end
            
            // At the end of the bit time
            if (sample_count == 4'd15) begin
              // Shift in the sampled bit (LSB first)
              rx_shift_reg[bit_count] <= sampled_bit;
              
              // Check if we've received all data bits
              if (bit_count == DATA_BITS-1) begin
                if (PARITY_EN)
                  current_state <= S_PARITY_BIT;
                else
                  current_state <= S_STOP_BIT1;
                  
                sample_count <= 0;
              end else begin
                bit_count <= bit_count + 1'b1;
                sample_count <= 0;
              end
            end
          end
          
          S_PARITY_BIT: begin
            // Count samples
            sample_count <= sample_count + 1'b1;
            
            // Sample around the middle of the bit
            if (sample_count == 4'd7) begin
              bit_samples[0] <= rx_in_filtered;
            end else if (sample_count == 4'd8) begin
              bit_samples[1] <= rx_in_filtered;
            end else if (sample_count == 4'd9) begin
              bit_samples[2] <= rx_in_filtered;
              
              // Majority vote sampling
              sampled_bit <= ((rx_in_filtered & bit_samples[1]) | 
                             (bit_samples[1] & bit_samples[0]) | 
                             (rx_in_filtered & bit_samples[0]));
              
              // Calculate expected parity
              expected_parity = PARITY_TYPE ? ~(^rx_shift_reg) : ^rx_shift_reg;
              
              // Set parity error flag if detected
              if (((rx_in_filtered & bit_samples[1]) | 
                  (bit_samples[1] & bit_samples[0]) | 
                  (rx_in_filtered & bit_samples[0])) != expected_parity) begin
                parity_error <= 1'b1;
              end
            end
            
            // At the end of parity bit
            if (sample_count == 4'd15) begin
              current_state <= S_STOP_BIT1;
              sample_count <= 0;
            end
          end
          
          S_STOP_BIT1: begin
            // Count samples
            sample_count <= sample_count + 1'b1;
            
            // Sample around the middle of the bit
            if (sample_count == 4'd7) begin
              bit_samples[0] <= rx_in_filtered;
            end else if (sample_count == 4'd8) begin
              bit_samples[1] <= rx_in_filtered;
            end else if (sample_count == 4'd9) begin
              bit_samples[2] <= rx_in_filtered;
              
              // Majority vote sampling
              sampled_bit <= ((rx_in_filtered & bit_samples[1]) | 
                             (bit_samples[1] & bit_samples[0]) | 
                             (rx_in_filtered & bit_samples[0]));
              
              // Check for framing error - stop bit should be high
              if (((rx_in_filtered & bit_samples[1]) | 
                  (bit_samples[1] & bit_samples[0]) | 
                  (rx_in_filtered & bit_samples[0])) != 1'b1) begin
                frame_error <= 1'b1;
              end
            end
                // At the end of first stop bit
                if (sample_count == 4'd15) begin
                  if (STOP_BITS == 2) begin
                    current_state <= S_STOP_BIT2;
                    sample_count <= 0;
                  end else begin
                    // Data reception complete - signal data available
                    rx_done <= 1'b1;
                    current_state <= S_IDLE;
                  end
                end
              end
              
              S_STOP_BIT2: begin
                // Count samples
                sample_count <= sample_count + 1'b1;
                
                // Sample around the middle of the bit
                if (sample_count == 4'd7) begin
                  bit_samples[0] <= rx_in_filtered;
                end else if (sample_count == 4'd8) begin
                  bit_samples[1] <= rx_in_filtered;
                end else if (sample_count == 4'd9) begin
                  bit_samples[2] <= rx_in_filtered;
                  
                  // Majority vote sampling
                  sampled_bit <= ((rx_in_filtered & bit_samples[1]) | 
                                 (bit_samples[1] & bit_samples[0]) | 
                                 (rx_in_filtered & bit_samples[0]));
                  
                  // Check for framing error - stop bit should be high
                  if (((rx_in_filtered & bit_samples[1]) | 
                      (bit_samples[1] & bit_samples[0]) | 
                      (rx_in_filtered & bit_samples[0])) != 1'b1) begin
                    frame_error <= 1'b1;
                  end
                end
                
                // At the end of second stop bit
                if (sample_count == 4'd15) begin
                  // Data reception complete - signal data available
                  rx_done <= 1'b1;
                  current_state <= S_IDLE;
                end
              end
              
              S_BREAK: begin
                // Wait for line to return high before exiting break state
                if (rx_in_filtered == 1'b1) begin
                  current_state <= S_IDLE;
                  break_detect <= 1'b0;
                end
              end
              
              default: current_state <= S_IDLE;
            endcase
            
            // Check for break condition from any state
            if (break_detect && current_state != S_BREAK) begin
              current_state <= S_BREAK;
            end
          end
        end
      end
  
  // Debug assertions and information
  // synthesis translate_off
  initial begin
    $display("Enhanced UART RX Configuration:");
    $display("  DATA_BITS = %0d", DATA_BITS);
    $display("  PARITY_EN = %0d", PARITY_EN);
    $display("  PARITY_TYPE = %0d (%s)", PARITY_TYPE, PARITY_TYPE ? "odd" : "even");
    $display("  STOP_BITS = %0d", STOP_BITS);
    $display("  FIFO_DEPTH = %0d", FIFO_DEPTH);
  end
  // synthesis translate_on
  
endmodule
