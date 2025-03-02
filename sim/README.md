# XSim Waveform Viewer Script

This bash script runs a SystemVerilog simulation using Xilinx XSim and automatically opens the waveform viewer to display the results.

## Prerequisites

- Xilinx Vivado must be installed and properly configured in your PATH
- SystemVerilog design and testbench files must exist in the expected locations

## Usage

1. Make the script executable (first time only):
   ```bash
   chmod +x path/to/run_xsim.sh
   ```

2. Run the script:
   ```bash
   ./path/to/run_xsim.sh
   ```

## What the Script Does

1. Compiles your SystemVerilog design and testbench files
2. Elaborates the design with the specified testbench top module
3. Runs the simulation and captures all waveforms
4. Automatically opens the XSim GUI waveform viewer
5. Saves timestamped waveform files in the simulation directory

## File Structure

The script expects your project to have the following structure:
- `/rtl/` - Contains your design files (currently configured for `baudrate_gen.sv`)
- `/tb/unit_tests/` - Contains your testbench files (currently configured for `baudrate_gen_tb.sv`)
- `/sim/` - Directory where simulation results will be stored

## Customization

To use this script with different design or testbench files:

1. Edit the script and modify these variables at the top:
   ```bash
   DESIGN_FILE="$PROJECT_ROOT/rtl/your_design.sv"
   TESTBENCH_FILE="$PROJECT_ROOT/tb/unit_tests/your_testbench.sv"
   TB_TOP="your_testbench_top_module"
   ```

2. Run the script as described above

## Troubleshooting

- If you see compilation errors, check that your design and testbench files are valid
- If the waveform viewer doesn't open, ensure XSim is properly installed and in your PATH
- Check the simulation directory for log files if errors occur
