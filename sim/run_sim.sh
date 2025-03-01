#!/bin/bash

# Get the absolute path to the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Configuration variables
DESIGN_FILE="$PROJECT_ROOT/rtl/baudrate_gen.sv"
TESTBENCH_FILE="$PROJECT_ROOT/tb/unit_tests/baudrate_gen_tb.sv"
TB_TOP="baudrate_gen_tb"
SIM_DIR="$PROJECT_ROOT/sim"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Vivado XSim directly...${NC}"
echo -e "Design file: $DESIGN_FILE"
echo -e "Testbench file: $TESTBENCH_FILE"

# Check if the files exist
if [ ! -f "$DESIGN_FILE" ]; then
    echo -e "${RED}Error: Design file not found: $DESIGN_FILE${NC}"
    exit 1
fi

if [ ! -f "$TESTBENCH_FILE" ]; then
    echo -e "${RED}Error: Testbench file not found: $TESTBENCH_FILE${NC}"
    exit 1
fi

# Create simulation directory
mkdir -p "$SIM_DIR"

# Clean any previous simulation files
rm -rf "$SIM_DIR/xsim.dir"
rm -f "$SIM_DIR/xelab.*"
rm -f "$SIM_DIR/xvlog.*"
rm -f "$SIM_DIR/xsim.*"

# Go to the simulation directory
cd "$SIM_DIR"

# Compile the design and testbench (SystemVerilog)
echo -e "${YELLOW}Compiling files...${NC}"
xvlog -sv "$DESIGN_FILE" "$TESTBENCH_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed${NC}"
    exit 1
fi

# Elaborate the design
echo -e "${YELLOW}Elaborating design...${NC}"
xelab -debug typical -s sim_snapshot "$TB_TOP"
if [ $? -ne 0 ]; then
    echo -e "${RED}Elaboration failed${NC}"
    exit 1
fi

# Run the simulation
echo -e "${YELLOW}Running simulation...${NC}"
xsim sim_snapshot -R -onfinish quit

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Simulation completed successfully${NC}"
    
    # Create a timestamp for the waveform file
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Convert to VCD if needed (optional)
    echo -e "${YELLOW}Generating VCD file...${NC}"
    xsim sim_snapshot -tclbatch <(echo "open_vcd baud_gen_waves_${TIMESTAMP}.vcd; log_vcd /*; run all; close_vcd; exit")
    
    echo -e "${GREEN}Simulation artifacts saved to: $SIM_DIR${NC}"
else
    echo -e "${RED}Simulation failed${NC}"
fi
