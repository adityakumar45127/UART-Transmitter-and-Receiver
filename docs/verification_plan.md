# Verification Plan

## 1. Testbench Suite (`testbench/`)

Three self-checking Verilog testbenches verify the UART modules independently and as an integrated system at true **9600 baud** (`100 MHz` system clock):

| Testbench | Target Scope | Key Verification Objectives |
| :--- | :--- | :--- |
| [`tb_uart_tx.v`](../testbench/tb_uart_tx.v) | `baud_rate_gen` + `tx_ctrl` + `uart_tx` | Reset state, single-byte TX (`0xA3`), Start bit (`0`), LSB-first bit order, Stop bit (`1`), 9600-baud bit period measurement (`~104,160 ns`), multi-byte TX (`0x55`, `0x41`, `0x0F`) |
| [`tb_uart_rx.v`](../testbench/tb_uart_rx.v) | `baud_rate_gen` + `rx_ctrl` + `uart_rx` | Reset state, single-byte RX (`0xC9`), 15 µs false-start glitch rejection, bad-stop-bit framing error (`rx_error=1`, `rx_done=0`), multi-byte RX recovery (`0x3C`, `0x96`, `0xFF`, `0x00`) |
| [`tb_uart_top.v`](../testbench/tb_uart_top.v) | `uart_top` | Reset check, standalone TX frame & baud check (`0x9D`), standalone RX check (`0x6B`), single-byte TX->RX loopback (`0xA5`), multiple-byte loopback (`0x55`, `0xAA`, `0x12`, `0x34`, `0xF0`, `0x0F`) |

## 2. Requirements Coverage Matrix

| Requirement | Verified In | Pass Condition |
| :--- | :--- | :--- |
| Reset operation | All 3 testbenches | `tx=1`, `tx_busy=0`, `tx_done=0`, `rx_data=0x00`, `rx_busy=0`, `rx_done=0`, `rx_error=0` |
| Single-byte transmission | `tb_uart_tx`, `tb_uart_top` | Frame starts on `0`, completes with `tx_done=1`, serial byte matches input |
| Single-byte reception | `tb_uart_rx`, `tb_uart_top` | `rx_done=1`, `rx_error=0`, `rx_data == expected_byte` |
| Correct start bit | `tb_uart_tx`, `tb_uart_rx`, `tb_uart_top` | TX emits `0` for 1 bit period; RX samples `0` at mid-start and rejects short glitches |
| Correct data & LSB-first | `tb_uart_tx`, `tb_uart_top` | Asymmetric bytes (`0xA3`, `0x9D`) serialized bit `0` through bit `7` sequentially |
| Correct stop bit | `tb_uart_tx`, `tb_uart_rx`, `tb_uart_top` | TX emits `1` for 1 bit period; RX asserts `rx_error=1` if stop bit is `0` |
| Baud-rate timing (9600) | `tb_uart_tx`, `tb_uart_top` | Measured average bit duration within `103,000 ns` to `105,500 ns` (`~104,160 ns`) |
| Loopback communication | `tb_uart_top` | `tx` wired directly to `rx`; received `rx_data` matches transmitted `tx_data` |
| Multiple-byte transmission | All 3 testbenches | Back-to-back bytes transmit and receive cleanly with zero dropped frames |
