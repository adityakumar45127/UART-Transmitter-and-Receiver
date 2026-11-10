//------------------------------------------------------------------------------
// Module      : baud_rate_gen
// Description : Fixed 9600-baud generator from 100 MHz system clock.
//               Outputs 16x oversampling tick (sample_tick) for UART RX and
//               1x baud-rate tick (baud_tick) for UART TX.
//------------------------------------------------------------------------------
module baud_rate_gen #(
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE  = 9600,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst,
    output reg  sample_tick,
    output reg  baud_tick
);

    // 100_000_000 / (9600 * 16) = 651 clocks per 16x sample tick
    localparam integer SAMPLE_DIV = CLK_FREQ / (BAUD_RATE * OVERSAMPLE);
    localparam [9:0]   SAMPLE_MAX = SAMPLE_DIV - 1;
    localparam [3:0]   BAUD_MAX   = OVERSAMPLE - 1;

    reg [9:0] sample_cnt;
    reg [3:0] oversample_cnt;

    always @(posedge clk) begin
        if (rst) begin
            sample_cnt     <= 10'd0;
            oversample_cnt <= 4'd0;
            sample_tick    <= 1'b0;
            baud_tick      <= 1'b0;
        end else begin
            // Generate 16x oversampling tick
            if (sample_cnt == SAMPLE_MAX) begin
                sample_cnt  <= 10'd0;
                sample_tick <= 1'b1;

                // Divide by 16 to generate 1x 9600-baud TX tick
                if (oversample_cnt == BAUD_MAX) begin
                    oversample_cnt <= 4'd0;
                    baud_tick      <= 1'b1;
                end else begin
                    oversample_cnt <= oversample_cnt + 4'd1;
                    baud_tick      <= 1'b0;
                end
            end else begin
                sample_cnt  <= sample_cnt + 10'd1;
                sample_tick <= 1'b0;
                baud_tick   <= 1'b0;
            end
        end
    end

endmodule
