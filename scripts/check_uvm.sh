#!/bin/bash
# ==============================================================================
# UART Project - UVM Availability Check Script
# ==============================================================================

# Exit on error
set -e

echo "Checking UVM availability in Vivado..."

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Create a simple UVM test file
cat > uvm_test.sv << EOF
module uvm_test;
  import uvm_pkg::*;
  \`include "uvm_macros.svh"

  class simple_test extends uvm_test;
    \`uvm_component_utils(simple_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      \`uvm_info("TEST", "UVM is working correctly", UVM_LOW)
    endfunction
  endclass

  initial begin
    run_test("simple_test");
  end
endmodule
EOF

echo "Compiling UVM test..."
if xvlog -sv uvm_test.sv -L uvm > xvlog.log 2>&1; then
  echo "✓ Compilation successful"
else
  echo "✗ Compilation failed"
  echo "Compilation error details:"
  cat xvlog.log
  echo ""
  echo "Possible issues:"
  echo "1. UVM package not found - check Vivado installation"
  echo "2. UVM macros not recognized - check UVM version"
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "Elaborating UVM test..."
if xelab -L uvm work.uvm_test -s uvm_sim > xelab.log 2>&1; then
  echo "✓ Elaboration successful"
else
  echo "✗ Elaboration failed"
  echo "Elaboration error details:"
  cat xelab.log
  echo ""
  echo "Possible issues:"
  echo "1. UVM library not properly linked"
  echo "2. UVM version mismatch"
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "Running UVM test..."
if xsim uvm_sim -R > xsim.log 2>&1; then
  echo "✓ Simulation successful"
  echo "UVM version information:"
  grep -i "uvm_info" xsim.log
else
  echo "✗ Simulation failed"
  echo "Simulation error details:"
  cat xsim.log
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "UVM check completed successfully!"
echo "Your Vivado installation appears to have a working UVM library."
