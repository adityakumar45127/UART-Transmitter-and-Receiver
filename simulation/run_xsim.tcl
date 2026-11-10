#-------------------------------------------------------------------------------
# File        : run_xsim.tcl
# Description : Vivado XSIM Tcl batch script to capture waveforms (.wdb) and
#               execute the selected UART testbench to completion.
#-------------------------------------------------------------------------------
log_wave -recursive *
run all
quit
