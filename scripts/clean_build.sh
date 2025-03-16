#!/bin/bash
# ==============================================================================
# UART Project - Clean Build Script
# ==============================================================================

# Exit on error
set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_DIR="$PROJECT_ROOT/sim"
VIVADO_SIM_DIR="$SIM_DIR/vivado_sim"

# Process command line arguments
CLEAN_ALL=0
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -a|--all)
      CLEAN_ALL=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -a, --all      Clean all generated files, including logs"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Cleaning Vivado simulation files..."

# Clean standard simulation files
if [ -d "$VIVADO_SIM_DIR" ]; then
  cd "$VIVADO_SIM_DIR"
  rm -rf xsim.dir
  rm -f *.wdb
  rm -f xelab.*
  rm -f xvlog.*
  rm -f xsim.*
  rm -f filelist.f
  rm -f wave_config.tcl
  rm -f xsim_config.tcl

  # Remove logs only if clean all is requested
  if [ "$CLEAN_ALL" -eq 1 ]; then
    echo "Removing all log files..."
    rm -f *.log
    rm -f *.jou
    rm -f *.pb
    rm -f webtalk*
  fi

  echo "Vivado simulation files cleaned."
else
  echo "Vivado simulation directory not found. Nothing to clean."
fi

# Clean other generated files if clean all is requested
if [ "$CLEAN_ALL" -eq 1 ]; then
  echo "Cleaning all generated project files..."

  # Find and remove common backup files
  find "$PROJECT_ROOT" -name "*.bak" -delete
  find "$PROJECT_ROOT" -name "*~" -delete
  find "$PROJECT_ROOT" -name "*.swp" -delete
  find "$PROJECT_ROOT" -name "*.swo" -delete

  # Clean any Vivado project files outside the simulation directory
  find "$PROJECT_ROOT" -name "*.jou" -delete
  find "$PROJECT_ROOT" -name "*.log" -not -path "$SIM_DIR/*" -delete

  echo "All generated files cleaned."
fi

echo "Cleanup complete!"
