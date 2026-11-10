//------------------------------------------------------------------------------
// Module      : uart_rx
// Description : UART Receiver datapath with 2-FF input synchronizer, 8-bit
//               serial-to-parallel shift register (LSB-first), and output latch.
//------------------------------------------------------------------------------
module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    input  wire       rx_shift_en,
    input  wire       rx_latch_data,
    output wire       rx_sync,
    output reg  [7:0] rx_data
);

    reg       rx_ff1;
    reg       rx_ff2;
    reg [7:0] rx_shift_reg;

    // 2-stage input synchronizer (idle high on reset)
    always @(posedge clk) begin
        if (rst) begin
            rx_ff1 <= 1'b1;
            rx_ff2 <= 1'b1;
        end else begin
            rx_ff1 <= rx;
            rx_ff2 <= rx_ff1;
        end
    end

    assign rx_sync = rx_ff2;

    // Serial-to-parallel shift register and parallel output latch
    always @(posedge clk) begin
        if (rst) begin
            rx_shift_reg <= 8'h00;
            rx_data      <= 8'h00;
        end else begin
            if (rx_shift_en) begin
                rx_shift_reg <= {rx_sync, rx_shift_reg[7:1]};
            end
            if (rx_latch_data) begin
                rx_data <= rx_shift_reg;
            end
        end
    end

endmodule
