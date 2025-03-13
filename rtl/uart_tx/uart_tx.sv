/*
Filename: uart_tx.sv
Description: UART transmitter with fixed issues
*/

`timescale 1ns/1ps

module uart_tx #(
  parameter int DATA_BITS = 8,
  parameter bit PARITY_EN = 1'b1,
  parameter bit PARITY_TYPE = 1'b0,  // 0=even, 1=odd
  parameter int STOP_BITS = 1
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  tick,        // Baud rate tick
  input  logic                  tx_start,    // Start transmission
  input  logic                  cts,         // Clear to Send (flow control)
  input  logic [DATA_BITS-1:0]  tx_data,     // Parallel data input
  output logic                  tx_out,      // Serial data output
  output logic                  tx_busy,     // Transmitter busy
  output logic                  tx_done      // Transmission complete
);

  // States - renamed to avoid conflicts
  typedef enum logic [2:0] {
    S_IDLE,
    S_START_BIT,
    S_DATA_BITS,
    S_PARITY_BIT,
    S_STOP_BIT1,
    S_STOP_BIT2
  } state_t;
  
  // Internal signals
  state_t current_state;
  logic [3:0] bit_count;
  logic [DATA_BITS-1:0] tx_shift_reg;
  logic [DATA_BITS-1:0] tx_data_latch;  // Latch for tx_data
  logic parity_value;
  logic flow_paused;
  logic tx_start_pending;  // Latch for tx_start signal
  
  // Debug counter for diagnosing issues
  int tick_debug_counter;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tick_debug_counter <= 0;
    end else begin
      if (tick)
        tick_debug_counter <= tick_debug_counter + 1;
    end
  end
  
  // Debug output on every tick and critical events
  always @(posedge clk) begin
    if (tick)
      $display("[TX DEBUG] Tick #%0d - State: %s, bit_count: %0d, tx_out: %b, tx_busy: %b, flow_paused: %b, tx_start_pending: %b at time %0t", 
               tick_debug_counter, current_state.name(), bit_count, tx_out, tx_busy, flow_paused, tx_start_pending, $time);
    
    if (tx_start)
      $display("[TX DEBUG] tx_start asserted with data: 0x%h at time %0t", tx_data, $time);
  end
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= S_IDLE;
      tx_out <= 1'b1;  // Idle high
      tx_busy <= 1'b0;
      tx_done <= 1'b0;
      bit_count <= 0;
      tx_shift_reg <= '0;
      tx_data_latch <= '0;
      parity_value <= 1'b0;
      flow_paused <= 1'b0;
      tx_start_pending <= 1'b0;
    end else begin
      // Default assignments
      tx_done <= 1'b0;
      
      // Latch tx_start signal on rising edge
      if (tx_start && !tx_busy && cts) begin
        tx_start_pending <= 1'b1;
        tx_data_latch <= tx_data;  // Latch the data immediately
        $display("[TX DEBUG] Latched tx_start request for data: 0x%h at time %0t", tx_data, $time);
      end
      
      // Check flow control
      if (!cts && !flow_paused && current_state != S_IDLE) begin
        flow_paused <= 1'b1;
        $display("[TX DEBUG] Flow control paused transmission at time %0t", $time);
      end
      else if (cts && flow_paused) begin
        flow_paused <= 1'b0;
        $display("[TX DEBUG] Flow control resumed transmission at time %0t", $time);
      end
      
      // Only proceed with state machine if not paused by flow control
      if (!flow_paused) begin
        case (current_state)
          S_IDLE: begin
            tx_out <= 1'b1;  // Line idles high
            tx_busy <= 1'b0;
            
            // Start transmission on tick if we have a pending request
            if (tick && tx_start_pending) begin
              tx_start_pending <= 1'b0;
              tx_shift_reg <= tx_data_latch;  // Load latched data
              parity_value <= PARITY_TYPE ? ~(^tx_data_latch) : ^tx_data_latch; // Calculate parity
              current_state <= S_START_BIT;
              tx_busy <= 1'b1;
              $display("[TX DEBUG] Starting transmission of data: 0x%h at time %0t", tx_data_latch, $time);
            end
          end
          
          S_START_BIT: begin
            // Output start bit (always low)
            tx_out <= 1'b0;
            
            // Wait for tick to move to data state
            if (tick) begin
              current_state <= S_DATA_BITS;
              bit_count <= 0;
              $display("[TX DEBUG] Start bit sent at time %0t", $time);
            end
          end
          
          S_DATA_BITS: begin
            // Output current data bit (LSB first)
            tx_out <= tx_shift_reg[0];
            
            // Handle tick
            if (tick) begin
              $display("[TX DEBUG] Sent data bit %0d: %b at time %0t", bit_count, tx_shift_reg[0], $time);
              
              // Shift data for next bit
              tx_shift_reg <= tx_shift_reg >> 1;
              
              // Check if we've sent all data bits
              if (bit_count == DATA_BITS-1) begin
                // Move to next state
                current_state <= PARITY_EN ? S_PARITY_BIT : S_STOP_BIT1;
                bit_count <= 0; // Reset for next transmission
                $display("[TX DEBUG] All data bits sent, next is %s at time %0t", 
                        PARITY_EN ? "parity" : "stop bit", $time);
              end else begin
                // Increment counter
                bit_count <= bit_count + 1'b1;
              end
            end
          end
          
          S_PARITY_BIT: begin
            // Output parity bit
            tx_out <= parity_value;
            
            if (tick) begin
              current_state <= S_STOP_BIT1;
              $display("[TX DEBUG] Parity bit sent: %b at time %0t", parity_value, $time);
            end
          end
          
          S_STOP_BIT1: begin
            // Output stop bit (always high)
            tx_out <= 1'b1;
            
            if (tick) begin
              if (STOP_BITS == 1) begin
                current_state <= S_IDLE;
                tx_done <= 1'b1;
                $display("[TX DEBUG] Transmission complete at time %0t", $time);
              end else begin
                current_state <= S_STOP_BIT2;
              end
            end
          end
          
          S_STOP_BIT2: begin
            // Output second stop bit (always high)
            tx_out <= 1'b1;
            
            if (tick) begin
              current_state <= S_IDLE;
              tx_done <= 1'b1;
              $display("[TX DEBUG] Transmission complete (2 stop bits) at time %0t", $time);
            end
          end
          
          default: current_state <= S_IDLE;
        endcase
      end
    end
  end
  
endmodule
