//------------------------------------------------------------------------------
// Module      : uart_tx
// Description : UART Transmitter datapath with 8-bit LSB-first shift register
//               and registered glitch-free serial output.
//------------------------------------------------------------------------------
module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_load,
    input  wire       tx_shift_en,
    input  wire [1:0] tx_bit_sel,
    output reg        tx
);

    reg [7:0] tx_shift_reg;

    always @(posedge clk) begin
        if (rst) begin
            tx_shift_reg <= 8'h00;
            tx           <= 1'b1;
        end else begin
            if (tx_load) begin
                tx_shift_reg <= tx_data;
            end else if (tx_shift_en) begin
                tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
            end

            case (tx_bit_sel)
                2'b00:   tx <= 1'b1;            // Idle
                2'b01:   tx <= 1'b0;            // Start bit
                2'b10:   tx <= tx_shift_reg[0]; // Data bit (LSB first)
                2'b11:   tx <= 1'b1;            // Stop bit
                default: tx <= 1'b1;
            endcase
        end
    end

endmodule
