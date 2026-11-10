# RTL Synthesis Guide (Xilinx Vivado)

> **Environment Note:** Xilinx Vivado is not installed on the authoring workstation, so actual Vivado synthesis reports (`utilization_synth.rpt`, `timing_summary_synth.rpt`, etc.) must be generated locally in Vivado using the scripts below.

## 1. Automated Command-Line Synthesis

From `synthesis/` in a Vivado Command Prompt:

```bat
run_synth.bat
```

To target a different FPGA part (default: `xc7a35tcpg236-1`), set `VIVADO_PART` beforehand:

```bat
set VIVADO_PART=xc7a100tcsg324-1
run_synth.bat
```

### Vivado GUI Project Setup (Optional)

In the **Vivado Tcl Console**, run:

```tcl
cd <path-to-repo>/UART_Design/synthesis
source create_vivado_project.tcl
```

## 2. Generated Reports (`synthesis/reports/`)

| Report File | Contents |
| :--- | :--- |
| `utilization_synth.rpt` | Hierarchical Slice LUT and Flip-Flop (`FDRE`/`FDSE`) counts across `baud_rate_gen`, `tx_ctrl`, `uart_tx`, `rx_ctrl`, and `uart_rx` |
| `timing_summary_synth.rpt` | Setup (`WNS`, `TNS`) and Hold (`WHS`, `THS`) slack at `100 MHz` (`10.000 ns` clock period) |
| `clock_utilization_synth.rpt` | Clock buffer (`BUFG`) utilization |
| `drc_synth.rpt` | Design Rule Check summary |
| `power_synth.rpt` | Static and dynamic power estimation |

## 3. What to Examine in the Reports

1. **Flip-Flop Utilization (`FDRE`/`FDSE`)**:
   - `baud_rate_gen`: 10-bit `sample_cnt` + 4-bit `oversample_cnt` + 2 tick FFs = 16 FFs.
   - `tx_ctrl`: 3-bit FSM `state` + 3-bit `bit_idx` + `tx_done` = 7 FFs.
   - `uart_tx`: 8-bit `tx_shift_reg` + 1-bit `tx` = 9 FFs.
   - `rx_ctrl`: 2-bit `state` + 4-bit `sample_cnt` + 3-bit `bit_idx` + `rx_sync_d`, `rx_done`, `rx_error` = 12 FFs.
   - `uart_rx`: 2-FF input synchronizer + 8-bit `rx_shift_reg` + 8-bit `rx_data` = 18 FFs.
   - Verify exact synthesized counts (after FSM encoding / one-hot optimization) in `utilization_synth.rpt`.
2. **LUT Utilization**:
   - Inspect comparator/incrementer LUTs in `baud_rate_gen` and FSM decode logic in `tx_ctrl` / `rx_ctrl`, confirming zero inferred latches.
3. **Timing Reports (`timing_summary_synth.rpt`)**:
   - Confirm positive `WNS` and `WHS` at `100 MHz`.
