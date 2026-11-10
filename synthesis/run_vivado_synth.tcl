#-------------------------------------------------------------------------------
# File        : run_vivado_synth.tcl
# Description : Vivado Non-Project RTL synthesis script for uart_top.
#               Generates hierarchical LUT/FF utilization, timing summary,
#               clock utilization, DRC, and power reports.
#-------------------------------------------------------------------------------

set script_dir  [file dirname [file normalize [info script]]]
set proj_root   [file normalize [file join $script_dir ".."]]
set rtl_dir     [file join $proj_root "rtl"]
set xdc_file    [file join $proj_root "constraints" "uart_top.xdc"]
set report_dir  [file join $script_dir "reports"]

file mkdir $report_dir

if {[info exists ::env(VIVADO_PART)] && $::env(VIVADO_PART) ne ""} {
    set fpga_part $::env(VIVADO_PART)
} else {
    set fpga_part "xc7a35tcpg236-1"
}

puts "INFO: Synthesizing uart_top for part $fpga_part"

# Read RTL sources
read_verilog [list \
    [file join $rtl_dir "baud_rate_gen.v"] \
    [file join $rtl_dir "tx_ctrl.v"] \
    [file join $rtl_dir "uart_tx.v"] \
    [file join $rtl_dir "rx_ctrl.v"] \
    [file join $rtl_dir "uart_rx.v"] \
    [file join $rtl_dir "uart_top.v"] \
]

# Read timing constraints
read_xdc $xdc_file

# Run RTL Synthesis
synth_design -top uart_top -part $fpga_part

# Export synthesis reports
report_utilization -hierarchical -file [file join $report_dir "utilization_synth.rpt"]
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -file [file join $report_dir "timing_summary_synth.rpt"]
report_clock_utilization -file [file join $report_dir "clock_utilization_synth.rpt"]
report_drc -file [file join $report_dir "drc_synth.rpt"]
report_power -file [file join $report_dir "power_synth.rpt"]

# Save post-synthesis checkpoint
write_checkpoint -force [file join $report_dir "uart_top_synth.dcp"]

puts "INFO: Synthesis complete. Reports written to $report_dir"
exit
