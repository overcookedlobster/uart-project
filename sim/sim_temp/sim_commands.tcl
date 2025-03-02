# Create a project
create_project temp_project ./temp_project -part xc7a35tcpg236-1
set_property target_language SystemVerilog [current_project]

# Add source files
add_files /home/workinglobster/uart-project/rtl/baudrate_gen.sv
set_property FILE_TYPE SystemVerilog [get_files /home/workinglobster/uart-project/rtl/baudrate_gen.sv]
add_files -fileset sim_1 /home/workinglobster/uart-project/tb/unit_tests/baudrate_gen_tb.sv
set_property FILE_TYPE SystemVerilog [get_files /home/workinglobster/uart-project/tb/unit_tests/baudrate_gen_tb.sv]

# Set the top module for simulation
set_property top baudrate_gen_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set simulation options
set_property -name {xsim.simulate.runtime} -value 10us -objects [get_filesets sim_1]

# Launch simulation
launch_simulation

# Open waveform window and add all signals
current_wave_config
add_wave /
run 10us

# Save waveform data
set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set wave_name "/home/workinglobster/uart-project/sim/baud_gen_waves_${timestamp}"

# Save waveforms
save_wave_config ${wave_name}.wcfg
write_vcd ${wave_name}.vcd

# Exit
exit
