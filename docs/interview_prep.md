# VLSI Placement Interview Preparation Guide (UART)

## 1. Protocol & Architecture Questions

**Q1. What does 8N1 mean, and what is the bit efficiency of 8N1 UART?**
- **8N1** = **8** data bits, **N**o parity bit, **1** stop bit (+ 1 start bit = **10 total bits per byte**).
- Frame overhead is 2 bits per 8 data bits -> **80% payload efficiency** (max payload rate at 9600 baud = `960 bytes/sec`).

**Q2. Which bit is transmitted first in UART, and how do shift registers implement it?**
- **LSB first** (`bit[0]` to `bit[7]`).
- Transmitter right-shifts (`{1'b0, tx_shift_reg[7:1]}`) and outputs `tx_shift_reg[0]`.
- Receiver right-shifts incoming bits into the MSB (`{rx_sync, rx_shift_reg[7:1]}`), so after 8 shifts the first-received LSB rests at bit `[0]` and MSB rests at bit `[7]`.

**Q3. Why does the UART receiver use 16× oversampling instead of 1× baud ticks?**
- Because UART has **no shared clock wire** between sender and receiver (asynchronous serial framing), the receiver cannot predict when an incoming Start bit begins.
- Sampling at `16 × 9600 = 153.6 kHz` locates the falling Start-bit edge within `1/16`th of a bit period, verifies the Start bit at `~7.5` ticks (mid-bit, rejecting short noise glitches), and samples every subsequent bit at `16`-tick intervals near the **center of the eye** where setup/hold margins are widest.

**Q4. Calculate the baud divider for 100 MHz -> 9600 baud with 16× oversampling.**
- $\text{SAMPLE\_DIV} = \frac{100,000,000}{16 \times 9600} = 651.04 \approx 651$.
- Actual baud rate = $\frac{100,000,000}{651 \times 16} = 9,600.61\text{ bps}$ (`+0.0064%` error, far within the ~`±2%` UART clock mismatch tolerance across a 10-bit frame).

## 2. RTL Design & Vivado Questions

**Q5. Why include a 2-FF synchronizer on `rx` inside `uart_rx`?**
- External serial `rx` transitions asynchronously relative to the FPGA's `100 MHz` `clk`. A 2-stage flip-flop synchronizer (`rx_ff1 -> rx_ff2`) isolates metastability before `rx_ctrl` and `uart_rx` evaluate `rx_sync`, ensuring both blocks see an identical synchronized value.

**Q6. Why use falling-edge detection (`rx_sync_d & ~rx_sync`) in `RX_IDLE` instead of level detection (`rx_sync == 0`)?**
- If a framing error occurs (Stop bit sampled as `0` at mid-bit), `RX_STOP` finishes while `rx` is still low for the second half of that bad stop bit. Level detection would immediately re-trigger a false frame; falling-edge detection waits until the line returns high and a genuine new `1 -> 0` Start transition occurs.

**Q7. Why use synchronous reset (`always @(posedge clk) if (rst)`) on Xilinx 7-series FPGAs?**
- Xilinx 7-series slice registers (`FDRE`/`FDSE`) natively support synchronous reset/set. Synchronous reset guarantees reset deassertion meets STA setup/hold timing cleanly and eliminates asynchronous reset recovery/removal issues.

**Q8. Why is `tx` registered in `uart_tx` rather than assigned combinationally from FSM state?**
- Registering `tx` on `posedge clk` guarantees the serial output pin never glitches when FSM state bits or mux select lines switch mid-cycle.
