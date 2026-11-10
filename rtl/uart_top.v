//------------------------------------------------------------------------------
// Module      : uart_top
// Description : Top-level 8N1 9600-baud UART Transmitter and Receiver
//               integrating baud rate generator, TX/RX control FSMs, and
//               TX/RX datapaths.
//------------------------------------------------------------------------------
module uart_top (
    input  wire       clk,
    input  wire       rst,
    // Transmitter interface
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy,
    output wire       tx_done,
    // Receiver interface
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_busy,
    output wire       rx_done,
    output wire       rx_error
);

    localparam integer CLK_FREQ   = 100_000_000;
    localparam integer BAUD_RATE  = 9600;
    localparam integer OVERSAMPLE = 16;

    // Baud rate generator ticks
    wire       sample_tick;
    wire       baud_tick;

    // Transmitter internal signals
    wire       tx_load;
    wire       tx_shift_en;
    wire [1:0] tx_bit_sel;

    // Receiver internal signals
    wire       rx_sync;
    wire       rx_shift_en;
    wire       rx_latch_data;

    // 1. Baud Rate Generator (9600 baud from 100 MHz clock)
    baud_rate_gen #(
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .OVERSAMPLE (OVERSAMPLE)
    ) u_baud_rate_gen (
        .clk         (clk),
        .rst         (rst),
        .sample_tick (sample_tick),
        .baud_tick   (baud_tick)
    );

    // 2. Transmitter Control Logic
    tx_ctrl u_tx_ctrl (
        .clk         (clk),
        .rst         (rst),
        .tx_start    (tx_start),
        .baud_tick   (baud_tick),
        .tx_load     (tx_load),
        .tx_shift_en (tx_shift_en),
        .tx_bit_sel  (tx_bit_sel),
        .tx_busy     (tx_busy),
        .tx_done     (tx_done)
    );

    // 3. UART Transmitter Datapath
    uart_tx u_uart_tx (
        .clk         (clk),
        .rst         (rst),
        .tx_data     (tx_data),
        .tx_load     (tx_load),
        .tx_shift_en (tx_shift_en),
        .tx_bit_sel  (tx_bit_sel),
        .tx          (tx)
    );

    // 4. Receiver Control Logic
    rx_ctrl u_rx_ctrl (
        .clk           (clk),
        .rst           (rst),
        .rx_sync       (rx_sync),
        .sample_tick   (sample_tick),
        .rx_shift_en   (rx_shift_en),
        .rx_latch_data (rx_latch_data),
        .rx_busy       (rx_busy),
        .rx_done       (rx_done),
        .rx_error      (rx_error)
    );

    // 5. UART Receiver Datapath
    uart_rx u_uart_rx (
        .clk           (clk),
        .rst           (rst),
        .rx            (rx),
        .rx_shift_en   (rx_shift_en),
        .rx_latch_data (rx_latch_data),
        .rx_sync       (rx_sync),
        .rx_data       (rx_data)
    );

endmodule
