//-----------------------------------------------------------------------------
// Title       : UART TX Testbench Package
// Description : Main package containing all UVM components for the testbench
//-----------------------------------------------------------------------------

`ifndef UART_TB_PKG_SV
`define UART_TB_PKG_SV

package uart_tb_pkg;
  // Import UVM packages - this is the ONLY place we should import UVM
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Forward declarations for cross-references
  typedef class uart_tx_config;
  typedef class uart_tx_seq_item;
  typedef class uart_tx_sequencer;
  typedef class uart_tx_driver;
  typedef class uart_tx_monitor;
  typedef class uart_tx_agent;
  typedef class uart_tx_scoreboard;
  typedef class uart_tx_env;
  typedef class uart_tx_base_sequence;
  typedef class uart_tx_base_test;

  // Include files in proper dependency order
  `include "uart_transaction.sv"
  `include "uart_config.sv"
  `include "uart_sequence.sv"
  `include "uart_sequencer.sv"
  `include "uart_driver.sv"
  `include "uart_monitor.sv"
  `include "uart_agent.sv"
  `include "uart_env.sv"
  `include "uart_test.sv"
endpackage : uart_tb_pkg

`endif // UART_TB_PKG_SV
