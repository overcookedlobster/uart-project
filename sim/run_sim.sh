#!/bin/bash

# Get the absolute path to the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Configuration variables
DESIGN_FILES=(
    "$PROJECT_ROOT/rtl/uart_tx/uart_tx.sv"
    "$PROJECT_ROOT/rtl/uart_tx/baudrate_gen.sv"
    # Add more design files as needed
)
TESTBENCH_FILE="$PROJECT_ROOT/tb/unit_tests/uart_tx/uart_tx_tb.sv"
TB_TOP="uart_tx_tb"
SIM_DIR="$PROJECT_ROOT/sim"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Vivado XSim directly...${NC}"
echo -e "Design files: ${DESIGN_FILES[*]}"
echo -e "Testbench file: $TESTBENCH_FILE"

# Check if the files exist
for DESIGN_FILE in "${DESIGN_FILES[@]}"; do
    if [ ! -f "$DESIGN_FILE" ]; then
        echo -e "${RED}Error: Design file not found: $DESIGN_FILE${NC}"
        exit 1
    fi
done

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
xvlog -sv "${DESIGN_FILES[@]}" "$TESTBENCH_FILE"
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

# Generate waveform database file
echo -e "${YELLOW}Running simulation and creating waveform database...${NC}"
# Create a timestamp for the waveform file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WAVE_FILE="baud_gen_waves_${TIMESTAMP}.wdb"

xsim sim_snapshot -tclbatch <(echo "log_wave -recursive *; run all; write_waveform $WAVE_FILE; exit")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Simulation completed successfully${NC}"
    echo -e "${GREEN}Waveform database saved to: $SIM_DIR/$WAVE_FILE${NC}"
    
    # Open the waveform viewer
    echo -e "${YELLOW}Opening waveform viewer...${NC}"
    xsim -gui sim_snapshot -view $WAVE_FILE &
    
    echo -e "${GREEN}Simulation artifacts saved to: $SIM_DIR${NC}"
else
    echo -e "${RED}Simulation failed${NC}"
fi

# Wait a moment to ensure the viewer has time to open and load the files
sleep 2

# NOW clean all generated files - MOVED AFTER the viewer is opened
# rm -rf "$SIM_DIR/xsim.dir"
# rm -f "$SIM_DIR/xelab.*"
# rm -f "$SIM_DIR/xvlog.*"
# rm -f "$SIM_DIR/xsim.*"
# rm -f "$SIM_DIR"/*.wdb
