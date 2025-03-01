# Get command line arguments
if {$argc < 5} {
    puts "Error: Not enough arguments"
    puts "Usage: vivado -mode batch -source run_sim.tcl -tclargs <design_file> <tb_file> <tb_top> <sim_time> <wave_dir>"
    exit 1
}

set design_file [lindex $argv 0]
set tb_file [lindex $argv 1]
set tb_top [lindex $argv 2]
set sim_time [lindex $argv 3]
set wave_dir [lindex $argv 4]

# Create a project in memory
create_project -in_memory -part xc7a35tcpg236-1

# Add source files
add_files $design_file
add_files -fileset sim_1 $tb_file

# Set the top module for simulation
set_property top $tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set simulation options
set_property -name {xsim.simulate.runtime} -value $sim_time -objects [get_filesets sim_1]

# Launch simulation
launch_simulation

# Open waveform window and add all signals
set wave_obj [get_objects /]
add_wave $wave_obj

# Run simulation
run $sim_time

# Save waveform data
set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set wave_name "${wave_dir}/baud_gen_waves_${timestamp}"

# Create both VCD (open format) and WCFG (Vivado format)
save_wave_config ${wave_name}.wcfg
open_vcd ${wave_name}.vcd
