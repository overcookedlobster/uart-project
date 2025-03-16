#!/bin/bash
# ==============================================================================
# UART Project - Vivado Simulation Script (Updated)
# ==============================================================================

# Exit on error
set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL_DIR="$PROJECT_ROOT/rtl"
TB_DIR="$PROJECT_ROOT/tb"
SIM_DIR="$PROJECT_ROOT/sim"
WORK_DIR="$SIM_DIR/vivado_sim"

# Default test to run
TEST_NAME="uart_tx_basic_test"
VERBOSITY="UVM_MEDIUM"

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -t|--test)
      TEST_NAME="$2"
      shift
      shift
      ;;
    -v|--verbosity)
      VERBOSITY="$2"
      shift
      shift
      ;;
    -c|--clean)
      CLEAN_BUILD=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -t, --test TEST_NAME      Specify the UVM test to run (default: uart_tx_basic_test)"
      echo "  -v, --verbosity LEVEL     Set UVM verbosity (UVM_LOW, UVM_MEDIUM, UVM_HIGH, UVM_DEBUG)"
      echo "  -c, --clean               Clean simulation directory before running"
      echo "  -h, --help                Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create work directory if it doesn't exist
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clean if requested
if [ -n "$CLEAN_BUILD" ]; then
  echo "Cleaning simulation directory..."
  rm -rf xsim.dir
  rm -f *.log *.jou *.pb *.wdb
  rm -f webtalk*
  rm -f xvlog.log xvlog.pb
  rm -f xelab.log xelab.pb
  rm -f xsim.log xsim.jou
  rm -f *.wcfg
fi

echo "======================================"
echo "Starting UART TX UVM Simulation"
echo "Test: $TEST_NAME"
echo "Verbosity: $VERBOSITY"
echo "======================================"

# Create a filelist.f for Vivado with specific compilation order
cat > filelist.f << EOD
# RTL files
$RTL_DIR/uart_tx/baudrate_gen.sv
$RTL_DIR/uart_tx/uart_tx.sv

# TB Interface
$TB_DIR/uart_interface.sv

# TB Package and Top
$TB_DIR/uart_tb_pkg.sv
$TB_DIR/uart_tb_top.sv
EOD

# Create a Tcl script for waveform setup
cat > wave_config.tcl << EOD
log_wave -recursive *
run -all
EOD

# Create a xsim_config.tcl script for simulation settings
cat > xsim_config.tcl << EOD
add_wave -recursive *
run -all
EOD

echo "Compiling files with xvlog..."
xvlog -sv -L uvm -f filelist.f \
      -i $TB_DIR \
      --include "$XILINX_VIVADO/data/system_verilog/uvm_1.2" \
      --uvm_version 1.2 || {
  echo "Compilation failed! Check logs for errors.";
  exit 1;
}

echo "Elaborating design with xelab..."
xelab -L uvm -debug typical --relax -s uart_sim work.uart_tb_top \
      -timescale 1ns/1ps || {
  echo "Elaboration failed! Check logs for errors.";
  exit 1;
}

echo "Running simulation..."
xsim uart_sim -tclbatch wave_config.tcl -sv_seed random \
     -testplusarg "UVM_TESTNAME=$TEST_NAME" \
     -testplusarg "UVM_VERBOSITY=$VERBOSITY" || {
  echo "Simulation failed!";
  exit 1;
}

# Open GUI with waveform if desired
if [ -z "$NO_GUI" ]; then
  echo "Opening waveform viewer..."
  xsim --gui uart_sim.wdb &
fi

echo "======================================"
echo "Simulation complete!"
echo "======================================"
