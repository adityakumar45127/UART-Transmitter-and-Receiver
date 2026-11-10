@echo off
setlocal

echo ============================================================================
echo  Vivado XSIM RTL Simulation - UART Transmitter and Receiver (8N1, 9600)
echo ============================================================================

xvlog ^
    ../rtl/baud_rate_gen.v ^
    ../rtl/tx_ctrl.v ^
    ../rtl/uart_tx.v ^
    ../rtl/rx_ctrl.v ^
    ../rtl/uart_rx.v ^
    ../rtl/uart_top.v ^
    ../testbench/tb_uart_tx.v ^
    ../testbench/tb_uart_rx.v ^
    ../testbench/tb_uart_top.v
if errorlevel 1 (
    echo [ERROR] xvlog compilation failed.
    exit /b %errorlevel%
)

echo --- Running tb_uart_tx ---
xelab -debug typical tb_uart_tx -s tb_uart_tx_sim
if errorlevel 1 exit /b %errorlevel%
xsim tb_uart_tx_sim -tclbatch run_xsim.tcl -log xsim_tx.log
if errorlevel 1 exit /b %errorlevel%

echo --- Running tb_uart_rx ---
xelab -debug typical tb_uart_rx -s tb_uart_rx_sim
if errorlevel 1 exit /b %errorlevel%
xsim tb_uart_rx_sim -tclbatch run_xsim.tcl -log xsim_rx.log
if errorlevel 1 exit /b %errorlevel%

echo --- Running tb_uart_top ---
xelab -debug typical tb_uart_top -s tb_uart_top_sim
if errorlevel 1 exit /b %errorlevel%
xsim tb_uart_top_sim -tclbatch run_xsim.tcl -log xsim_top.log
if errorlevel 1 exit /b %errorlevel%

echo ============================================================================
echo  All simulations completed. Review xsim_tx.log, xsim_rx.log, xsim_top.log
echo  Open top waveform: xsim --gui tb_uart_top_sim.wdb -view tb_uart_top_behav.wcfg
echo ============================================================================
endlocal
