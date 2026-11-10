#-------------------------------------------------------------------------------
# File        : create_vivado_project.tcl
# Description : Creates a Vivado GUI project (.xpr) with RTL sources,
#               testbenches, waveform configuration, and XDC constraints.
# Usage       : In Vivado Tcl Console: source create_vivado_project.tcl
#-------------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ".."]]
set vivado_dir [file join $script_dir "vivado_project"]

if {[info exists ::env(VIVADO_PART)] && $::env(VIVADO_PART) ne ""} {
    set fpga_part $::env(VIVADO_PART)
} else {
    set fpga_part "xc7a35tcpg236-1"
}

create_project uart_vivado $vivado_dir -part $fpga_part -force

# Add RTL design sources
add_files -fileset sources_1 [list \
    [file join $proj_root "rtl" "baud_rate_gen.v"] \
    [file join $proj_root "rtl" "tx_ctrl.v"] \
    [file join $proj_root "rtl" "uart_tx.v"] \
    [file join $proj_root "rtl" "rx_ctrl.v"] \
    [file join $proj_root "rtl" "uart_rx.v"] \
    [file join $proj_root "rtl" "uart_top.v"] \
]
set_property top uart_top [get_filesets sources_1]

# Add simulation testbenches and waveform configuration
add_files -fileset sim_1 [list \
    [file join $proj_root "testbench" "tb_uart_tx.v"] \
    [file join $proj_root "testbench" "tb_uart_rx.v"] \
    [file join $proj_root "testbench" "tb_uart_top.v"] \
    [file join $proj_root "simulation" "tb_uart_top_behav.wcfg"] \
]
set_property top tb_uart_top [get_filesets sim_1]

# Add timing constraints
add_files -fileset constrs_1 [file join $proj_root "constraints" "uart_top.xdc"]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: Vivado project created at $vivado_dir"
