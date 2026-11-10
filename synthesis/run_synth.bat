@echo off
setlocal

echo ============================================================================
echo  Xilinx Vivado RTL Synthesis - UART Transmitter and Receiver (8N1, 9600)
echo ============================================================================

vivado -mode batch -source run_vivado_synth.tcl -log reports/vivado_synth.log -journal reports/vivado_synth.jou
if errorlevel 1 (
    echo [ERROR] Vivado synthesis failed.
    exit /b %errorlevel%
)

echo ============================================================================
echo  Synthesis completed. Inspect reports in synthesis\reports\
echo ============================================================================
endlocal
