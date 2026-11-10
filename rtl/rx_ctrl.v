//------------------------------------------------------------------------------
// Module      : rx_ctrl
// Description : Receiver Control Logic FSM using 16x oversampling to detect
//               the start bit, sample 8 data bits at mid-bit, and verify the
//               stop bit (8N1 format).
//------------------------------------------------------------------------------
module rx_ctrl (
    input  wire clk,
    input  wire rst,
    input  wire rx_sync,
    input  wire sample_tick,
    output wire rx_shift_en,
    output wire rx_latch_data,
    output wire rx_busy,
    output reg  rx_done,
    output reg  rx_error
);

    localparam [1:0] RX_IDLE  = 2'd0,
                     RX_START = 2'd1,
                     RX_DATA  = 2'd2,
                     RX_STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] sample_cnt;
    reg [2:0] bit_idx;
    reg       rx_sync_d;

    wire start_edge;
    assign start_edge = rx_sync_d & ~rx_sync;

    always @(posedge clk) begin
        if (rst) begin
            state      <= RX_IDLE;
            sample_cnt <= 4'd0;
            bit_idx    <= 3'd0;
            rx_sync_d  <= 1'b1;
            rx_done    <= 1'b0;
            rx_error   <= 1'b0;
        end else begin
            rx_sync_d <= rx_sync;
            rx_done   <= 1'b0;

            case (state)
                RX_IDLE: begin
                    sample_cnt <= 4'd0;
                    bit_idx    <= 3'd0;
                    // Detect high-to-low start bit edge
                    if (start_edge) begin
                        state <= RX_START;
                    end
                end

                RX_START: begin
                    if (sample_tick) begin
                        if (sample_cnt == 4'd7) begin
                            sample_cnt <= 4'd0;
                            if (rx_sync == 1'b0) begin
                                // Confirmed valid start bit at mid-bit
                                bit_idx <= 3'd0;
                                state   <= RX_DATA;
                            end else begin
                                // False start glitch: abort back to idle
                                state <= RX_IDLE;
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 4'd1;
                        end
                    end
                end

                RX_DATA: begin
                    if (sample_tick) begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= 4'd0;
                            if (bit_idx == 3'd7) begin
                                state <= RX_STOP;
                            end else begin
                                bit_idx <= bit_idx + 3'd1;
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 4'd1;
                        end
                    end
                end

                RX_STOP: begin
                    if (sample_tick) begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= 4'd0;
                            state      <= RX_IDLE;
                            if (rx_sync == 1'b1) begin
                                // Valid stop bit verified
                                rx_done  <= 1'b1;
                                rx_error <= 1'b0;
                            end else begin
                                // Framing error (stop bit low)
                                rx_error <= 1'b1;
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 4'd1;
                        end
                    end
                end

                default: begin
                    state      <= RX_IDLE;
                    sample_cnt <= 4'd0;
                    bit_idx    <= 3'd0;
                end
            endcase
        end
    end

    assign rx_busy       = (state != RX_IDLE);
    assign rx_shift_en   = (state == RX_DATA) && sample_tick && (sample_cnt == 4'd15);
    assign rx_latch_data = (state == RX_STOP) && sample_tick && (sample_cnt == 4'd15) && (rx_sync == 1'b1);

endmodule
