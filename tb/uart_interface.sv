//-----------------------------------------------------------------------------
// Title       : UART TX Interface
// Description : SystemVerilog interface for UART TX signals
//-----------------------------------------------------------------------------

`ifndef UART_INTERFACE_SV
`define UART_INTERFACE_SV

interface uart_tx_if #(
  parameter int DATA_BITS = 8,
  parameter bit PARITY_EN = 1'b1,
  parameter bit PARITY_TYPE = 1'b0, // 0=even, 1=odd
  parameter int STOP_BITS = 1
)(
  input bit clk,
  input bit rst_n
);
  // Signals
  // UVM interface signals corresponding to inputs of the RTL module
  logic tick; // Baud rate tick
  logic tx_start; // Start transmission
  logic cts;    // Clear to Send (flow control)
  logic [DATA_BITS-1:0] tx_data; // Parallel data input

  // UVM interface signals corresponding to output of the RTL module
  logic tx_out;
  logic tx_busy;
  logic tx_done;

  // Clocking block for synchronizing signal changes
  clocking cb @(posedge clk);
    default input #1step output #0;
    output tx_start;
    output tick;
    output cts;
    output tx_data;
    input tx_out;
    input tx_busy;
    input tx_done;
  endclocking

  // Modports
  modport driver (
    clocking cb, output tx_start, tick, cts, tx_data
  );

  modport monitor (
    clocking cb, input tx_out, tx_busy, tx_done
  );

  // Tasks/Functions
  modport dut (
    input clk, rst_n, tick, tx_start, cts, tx_data,
    output tx_out, tx_busy, tx_done
  );
endinterface

`endif // UART_INTERFACE_SV
