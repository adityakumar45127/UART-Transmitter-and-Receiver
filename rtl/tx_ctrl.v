//------------------------------------------------------------------------------
// Module      : tx_ctrl
// Description : Transmitter Control Logic FSM for 8N1 serial transmission
//               (1 start bit, 8 data bits LSB-first, 1 stop bit, no parity).
//------------------------------------------------------------------------------
module tx_ctrl (
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire       baud_tick,
    output wire       tx_load,
    output wire       tx_shift_en,
    output reg  [1:0] tx_bit_sel,
    output wire       tx_busy,
    output reg        tx_done
);

    localparam [2:0] TX_IDLE      = 3'd0,
                     TX_WAIT_TICK = 3'd1,
                     TX_START     = 3'd2,
                     TX_DATA      = 3'd3,
                     TX_STOP      = 3'd4;

    reg [2:0] state;
    reg [2:0] bit_idx;

    // Sequential FSM and bit index counter
    always @(posedge clk) begin
        if (rst) begin
            state   <= TX_IDLE;
            bit_idx <= 3'd0;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                TX_IDLE: begin
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        state <= TX_WAIT_TICK;
                    end
                end

                TX_WAIT_TICK: begin
                    if (baud_tick) begin
                        state <= TX_START;
                    end
                end

                TX_START: begin
                    if (baud_tick) begin
                        bit_idx <= 3'd0;
                        state   <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    if (baud_tick) begin
                        if (bit_idx == 3'd7) begin
                            state <= TX_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end
                end

                TX_STOP: begin
                    if (baud_tick) begin
                        state   <= TX_IDLE;
                        tx_done <= 1'b1;
                    end
                end

                default: begin
                    state   <= TX_IDLE;
                    bit_idx <= 3'd0;
                end
            endcase
        end
    end

    // Datapath control outputs
    assign tx_busy     = (state != TX_IDLE);
    assign tx_load     = (state == TX_IDLE) && tx_start;
    assign tx_shift_en = (state == TX_DATA) && baud_tick && (bit_idx != 3'd7);

    always @(*) begin
        case (state)
            TX_IDLE:      tx_bit_sel = 2'b00; // Mark / idle high
            TX_WAIT_TICK: tx_bit_sel = 2'b00; // Wait aligned to baud boundary
            TX_START:     tx_bit_sel = 2'b01; // Start bit (0)
            TX_DATA:      tx_bit_sel = 2'b10; // Data bit (shift register LSB)
            TX_STOP:      tx_bit_sel = 2'b11; // Stop bit (1)
            default:      tx_bit_sel = 2'b00;
        endcase
    end

endmodule
