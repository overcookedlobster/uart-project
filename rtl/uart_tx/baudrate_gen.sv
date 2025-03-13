/*
Filename: baudrate_gen.sv
Description: configurable baudrate generator for UART communicaton

Parameters:
  - CLK_FREQ_HZ: input clock frequency in HZ (default 50MHz)
  - BAUD_RATE: target baud rate (default 9600)
  - OVERSAMPLING: sample rate multiple (16x for standard RX)
*/

`timescale 1ns/1ps;
module baudrate_gen #(
  parameter int CLK_FREQ_HZ = 50_000_000,
  parameter int BAUD_RATE = 9600,
  parameter int OVERSAMPLING = 16
) (
  input  logic clk,
  input  logic rst_n,
  input  logic enable,
  output logic tick,
  output logic tick_16x
);

  // Calculation of divider counter
  localparam int BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE - 1;
  localparam int BAUD_DIV_16X = CLK_FREQ_HZ / (BAUD_RATE * OVERSAMPLING) - 1;

  // Counter width calculation
  localparam int BAUD_CNT_WIDTH = $clog2(BAUD_DIV + 1);
  localparam int BAUD_CNT_16X_WIDTH = $clog2(BAUD_DIV_16X + 1);

  // Baud rate counters
  logic [BAUD_CNT_WIDTH-1:0] baud_counter;
  logic [BAUD_CNT_16X_WIDTH-1:0] baud_counter_16x;

  // 1x tick baudgen
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_counter <= '0;
      tick <= 1'b0;
    end else if (enable) begin
      if (baud_counter == BAUD_DIV) begin
        baud_counter <= '0;
        tick <= 1'b1;
      end else begin
        baud_counter <= baud_counter + 1'b1;
        tick <= 1'b0;
      end
    end else begin
      // When disabled, reset counter and don't generate ticks
      baud_counter <= '0;
      tick <= 1'b0;
    end
  end

  // 16x tick baudgen for RX module
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_counter_16x <= '0;
      tick_16x <= 1'b0;
    end else if (enable) begin
      if (baud_counter_16x == BAUD_DIV_16X) begin
        baud_counter_16x <= '0;
        tick_16x <= 1'b1;
      end else begin
        baud_counter_16x <= baud_counter_16x + 1'b1;
        tick_16x <= 1'b0;
      end
    end else begin
      // When disabled, reset counter and don't generate ticks
      baud_counter_16x <= '0;
      tick_16x <= 1'b0;
    end
  end

  // Debug display
  initial begin
    $display("Baud Rate Generator Configuration:");
    $display("  CLK_FREQ_HZ = %0d", CLK_FREQ_HZ);
    $display("  BAUD_RATE = %0d", BAUD_RATE);
    $display("  OVERSAMPLING = %0d", OVERSAMPLING);
    $display("  BAUD_DIV = %0d", BAUD_DIV);
    $display("  BAUD_DIV_16X = %0d", BAUD_DIV_16X);
  end

  // synthesis translate_off

  initial begin
    // check if integer division results in significant rounding error
    // what is defined as a significant rounding error and why? what parameters would increase/decrease the rounding error
    automatic real exact_div = real'(CLK_FREQ_HZ) / real'(BAUD_RATE) - 1.0;
    automatic real exact_div_16x = real'(CLK_FREQ_HZ) / (real'(BAUD_RATE) * real'(OVERSAMPLING)) - 1.0;
    automatic real error = (exact_div - real'(BAUD_DIV)) / exact_div * 100;
    automatic real error_16x = (exact_div_16x - real'(BAUD_DIV_16X)) / exact_div_16x * 100;

    if(error > 2.0) begin
      $warning("baud rate error exceeds 2.0%%!, Error = %f%%", error);
      $warning("CLK_FREQ_HZ=%d, BAUD_RATE=%d, BAUD_DIV=%d ", CLK_FREQ_HZ, BAUD_RATE, BAUD_DIV);
    end
    if(error_16x > 2.0) begin
      $warning("baud rate ovesampling error exceeds 2.0%%!, Error = %f%%", error_16x);
      $warning("CLK_FREQ_HZ_16X=%d, BAUD_RATE*oversampling=%d, BAUD_RATE_16X_DIV=%d ", CLK_FREQ_HZ, BAUD_RATE*OVERSAMPLING, BAUD_DIV_16X);
    end
  end
endmodule
