# RTL Simulation Guide (Xilinx Vivado XSIM)

> **Environment Note:** Xilinx Vivado / XSIM is not installed on the authoring workstation, so actual XSIM simulation logs and `.wdb` waveform files must be generated locally in Vivado using the scripts below.

## 1. Automated Command-Line Simulation (Windows)

From `simulation/` in a Vivado Command Prompt:

```bat
run_sim.bat
```

This compiles all 6 RTL modules and all 3 testbenches (`tb_uart_tx`, `tb_uart_rx`, `tb_uart_top`) and runs them sequentially:
- `xsim_tx.log` + `tb_uart_tx_sim.wdb`
- `xsim_rx.log` + `tb_uart_rx_sim.wdb`
- `xsim_top.log` + `tb_uart_top_sim.wdb`

## 2. Inspecting TX/RX Waveforms and Baud Timing in XSIM GUI

Open the top-level waveform database with pre-configured signal groups:

```bat
xsim --gui tb_uart_top_sim.wdb -view tb_uart_top_behav.wcfg
```

### Waveform Verification Checklist

| Signal / Event | Expected Measurement |
| :--- | :--- |
| **`baud_tick` period** | Pulses once every `10,416` `clk` cycles (`104,160 ns` = `104.16 µs`, matching `9600.61 baud`) |
| **`sample_tick` period** | Pulses once every `651` `clk` cycles (`6,510 ns`, i.e., `16 × 9600` Hz) |
| **8N1 Frame (`tx` / `rx`)** | `1` Start bit (`0`, `104.16 µs`) -> `8` Data bits LSB-first -> `1` Stop bit (`1`, `104.16 µs`) |
| **TX Status (`tx_busy`, `tx_done`)** | `tx_busy=1` across frame; `tx_done` pulses `1` clock at end of Stop bit |
| **RX Sampling & Status** | `rx_done` pulses `1` clock at mid-Stop bit when `rx_sync==1`; `rx_data` updates concurrently |
| **Loopback (`loopback_en=1`)** | `rx_data` equals `tx_data` after ~`1.04 ms` per byte with `rx_error=0` |
