/*
xvlog -sv uart_error_manager_tb.sv ../uart_error_manager.sv && xelab -R uart_error_manager
*/
///////////////////////////////////////////////////////////////////////////////
// File: uart_error_manager.sv
// 
// Description: UART Receiver Error Manager
// 
// This module detects, processes, and reports error conditions in the UART 
// receiver. It handles frame errors, parity errors, break conditions, and 
// timeout detection. It provides status signals and error flags for the 
// system to respond to error conditions.
///////////////////////////////////////////////////////////////////////////////

module uart_error_manager #(
  parameter CLK_FREQ_HZ    = 100_000_000,  // Default 100 MHz system clock
  parameter TIMEOUT_BIT_PERIODS = 3        // Timeout in bit periods (idle time)
) (
  input  logic        clk,             // System clock
  input  logic        rst_n,           // Active-low reset
  
  // Error inputs from state machine
  input  logic        frame_error,     // Stop bit error from state machine
  input  logic        parity_error,    // Parity error from state machine
  input  logic        frame_active,    // Active frame indicator
  input  logic        bit_valid,       // Valid bit indication
  input  logic        rx_filtered,     // Filtered RX input
  
  // Configuration
  input  logic [31:0] baud_rate,       // Current baud rate setting
  input  logic        error_clear,     // Clear error flags
  
  // Error outputs
  output logic        error_detected,  // Any error detected
  output logic        framing_error,   // Framing error status
  output logic        parity_err,      // Parity error status
  output logic        break_detect,    // Break condition detected
  output logic        timeout_detect   // Timeout detected
);

  // Calculated timeout in clock cycles
  logic [31:0] timeout_cycles;
  logic [31:0] idle_counter;
  logic        prev_frame_active;
  logic        prev_rx;
  
  // Break detection - looking for sustained low signal
  localparam BREAK_BITS = 10;  // 10 bits of continuous low indicates break
  logic [3:0] break_counter;
  logic       potential_break;
  
  // Calculate timeout based on baud rate
  // Number of clock cycles in one bit period = CLK_FREQ_HZ / baud_rate
  // Total timeout = bit period * TIMEOUT_BIT_PERIODS
  assign timeout_cycles = (CLK_FREQ_HZ / baud_rate) * TIMEOUT_BIT_PERIODS;
  
  // Error detection and latching
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      framing_error <= 1'b0;
      parity_err <= 1'b0;
      break_detect <= 1'b0;
      timeout_detect <= 1'b0;
      error_detected <= 1'b0;
      
      idle_counter <= '0;
      prev_frame_active <= 1'b0;
      prev_rx <= 1'b1;  // Idle high state
      break_counter <= '0;
      potential_break <= 1'b0;
    end
    else begin
      // Previous state tracking
      prev_frame_active <= frame_active;
      prev_rx <= rx_filtered;
      
      // Clear errors on external request
      if (error_clear) begin
        framing_error <= 1'b0;
        parity_err <= 1'b0;
        break_detect <= 1'b0;
        timeout_detect <= 1'b0;
        error_detected <= 1'b0;
      end
      
      // Latch framing error from state machine
      if (frame_error) begin
        framing_error <= 1'b1;
        error_detected <= 1'b1;
      end
      
      // Latch parity error from state machine
      if (parity_error) begin
        parity_err <= 1'b1;
        error_detected <= 1'b1;
      end
      
      // Break detection - count consecutive low bits
      if (frame_active && bit_valid) begin
        if (rx_filtered) begin
          // Reset break detection when any high bit is seen
          break_counter <= '0;
          potential_break <= 1'b0;
        end
        else begin
          // Count consecutive low bits
          if (break_counter < BREAK_BITS) begin
            break_counter <= break_counter + 1'b1;
          end
          
          // Set potential break when we've seen enough consecutive low bits
          if (break_counter == BREAK_BITS - 1) begin
            potential_break <= 1'b1;
          end
        end
      end
      
      // Confirm break condition at end of frame if potential_break was set
      if (prev_frame_active && !frame_active && potential_break) begin
        break_detect <= 1'b1;
        error_detected <= 1'b1;
        break_counter <= '0;
        potential_break <= 1'b0;
      end
      
      // Timeout detection - reset counter during active frames or RX transitions
      if (frame_active || (prev_rx != rx_filtered)) begin
        idle_counter <= '0;
      end
      else begin
        // Increment counter in idle state
        if (idle_counter < timeout_cycles) begin
          idle_counter <= idle_counter + 1'b1;
        end
        
        // Detect timeout
        if (idle_counter == timeout_cycles - 1) begin
          timeout_detect <= 1'b1;
        end
      end

      // Setting error_detected when any error is active
      error_detected <= framing_error || parity_err || break_detect || timeout_detect;
    end
  end

endmodule
