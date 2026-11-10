#-------------------------------------------------------------------------------
# File        : uart_top.xdc
# Description : Xilinx Vivado timing constraints for 8N1 9600-baud UART
# Target      : Generic Artix-7 (e.g., xc7a35tcpg236-1)
#-------------------------------------------------------------------------------

# Primary system clock: 100 MHz (10.000 ns period, 50% duty cycle)
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Clock uncertainty margin for synthesis timing analysis
set_clock_uncertainty 0.200 [get_clocks sys_clk]

# Input delay constraints relative to sys_clk
set_input_delay -clock sys_clk -max 2.000 [get_ports {rst tx_start tx_data[*] rx}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {rst tx_start tx_data[*] rx}]

# Output delay constraints relative to sys_clk
set_output_delay -clock sys_clk -max 2.000 [get_ports {tx tx_busy tx_done rx_data[*] rx_busy rx_done rx_error}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {tx tx_busy tx_done rx_data[*] rx_busy rx_done rx_error}]

#-------------------------------------------------------------------------------
# Optional Board Pin Mapping (Uncomment and adapt for target FPGA board)
#-------------------------------------------------------------------------------
# set_property IOSTANDARD LVCMOS33 [get_ports {clk rst tx_start tx tx_busy tx_done rx rx_busy rx_done rx_error}]
# set_property IOSTANDARD LVCMOS33 [get_ports {tx_data[*] rx_data[*]}]
