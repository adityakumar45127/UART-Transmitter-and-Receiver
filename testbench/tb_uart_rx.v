`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench   : tb_uart_rx
// Description : Self-checking Verilog testbench for UART Receiver + Baud Gen.
//               Verifies reset, single-byte reception, start-bit glitch
//               rejection, LSB-first deserialization, stop-bit error detection,
//               and multiple-byte reception at 9600 baud (8N1).
//------------------------------------------------------------------------------
module tb_uart_rx;

    localparam CLK_PERIOD      = 10;       // 100 MHz
    localparam IDEAL_BIT_NS    = 104167;   // 1 / 9600 s in ns

    reg        clk;
    reg        rst;
    reg        rx;
    wire       sample_tick;
    wire       baud_tick;
    wire       rx_sync;
    wire       rx_shift_en;
    wire       rx_latch_data;
    wire       rx_busy;
    wire       rx_done;
    wire       rx_error;
    wire [7:0] rx_data;

    integer error_count;
    reg       seen_rx_done;
    reg       seen_rx_error;
    reg [7:0] latched_byte;

    // Baud rate generator
    baud_rate_gen u_baud (
        .clk         (clk),
        .rst         (rst),
        .sample_tick (sample_tick),
        .baud_tick   (baud_tick)
    );

    // RX control FSM
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

    // UART RX datapath
    uart_rx u_uart_rx (
        .clk           (clk),
        .rst           (rst),
        .rx            (rx),
        .rx_shift_en   (rx_shift_en),
        .rx_latch_data (rx_latch_data),
        .rx_sync       (rx_sync),
        .rx_data       (rx_data)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Capture 1-cycle rx_done / rx_error events cleanly
    always @(posedge clk) begin
        if (rst) begin
            seen_rx_done  <= 1'b0;
            seen_rx_error <= 1'b0;
            latched_byte  <= 8'h00;
        end else begin
            if (rx_done) begin
                seen_rx_done <= 1'b1;
                latched_byte <= rx_data;
            end
            if (rx_error) begin
                seen_rx_error <= 1'b1;
            end
        end
    end

    // Drive an 8N1 serial frame onto rx (LSB first)
    task drive_rx_frame;
        input [7:0] tx_byte;
        input       stop_bit_val;
        integer     b;
        begin
            @(negedge clk);
            seen_rx_done  = 1'b0;
            seen_rx_error = 1'b0;

            // Start bit (0)
            rx = 1'b0;
            #(IDEAL_BIT_NS);

            // 8 data bits (LSB first)
            for (b = 0; b < 8; b = b + 1) begin
                rx = tx_byte[b];
                #(IDEAL_BIT_NS);
            end

            // Stop bit
            rx = stop_bit_val;
            #(IDEAL_BIT_NS);

            // Return to idle mark
            rx = 1'b1;
            #(IDEAL_BIT_NS / 4);
        end
    endtask

    task verify_valid_rx;
        input [7:0] expected_byte;
        begin
            drive_rx_frame(expected_byte, 1'b1);
            if (seen_rx_done !== 1'b1 || seen_rx_error !== 1'b0 || latched_byte !== expected_byte) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] RX mismatch: expected=0x%02h actual=0x%02h done=%0b err=%0b",
                         $time, expected_byte, latched_byte, seen_rx_done, seen_rx_error);
            end else begin
                $display("[PASS][%0t ns] RX byte matched: expected=0x%02h actual=0x%02h",
                         $time, expected_byte, latched_byte);
            end
        end
    endtask

    initial begin
        rst         = 1'b0;
        rx          = 1'b1;
        error_count = 0;

        $display("====================================================================");
        $display(" Starting UART Receiver Testbench (9600 baud, 8N1)");
        $display("====================================================================");

        // Reset test
        @(negedge clk);
        rst = 1'b1;
        repeat (4) @(posedge clk);
        #1;
        if (rx_data !== 8'h00 || rx_busy !== 1'b0 || rx_done !== 1'b0 || rx_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] RX reset check failed");
        end else begin
            $display("[PASS] Reset operation verified (rx_data=0x00, rx_busy=0, rx_done=0, rx_error=0)");
        end

        @(negedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        // Single-byte reception
        $display("\n--- Single-Byte Reception (0xC9) ---");
        verify_valid_rx(8'hC9);

        // False start-bit glitch rejection (low for 15 us < mid-start ~52 us)
        $display("\n--- Start-Bit Glitch Rejection ---");
        @(negedge clk);
        seen_rx_done  = 1'b0;
        seen_rx_error = 1'b0;
        rx = 1'b0;
        #15000;
        rx = 1'b1;
        #(IDEAL_BIT_NS);
        if (rx_busy !== 1'b0 || seen_rx_done !== 1'b0 || seen_rx_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Receiver failed to reject false start glitch");
        end else begin
            $display("[PASS] False start glitch rejected cleanly");
        end

        // Framing error test (invalid stop bit = 0)
        $display("\n--- Stop-Bit Framing Error Detection ---");
        drive_rx_frame(8'h7E, 1'b0);
        if (seen_rx_error !== 1'b1 || seen_rx_done !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Framing error not detected for bad stop bit");
        end else begin
            $display("[PASS] Bad stop bit detected (rx_error=1, rx_done=0)");
        end

        // Multiple-byte reception (also verifies recovery after framing error)
        $display("\n--- Multiple-Byte Reception (0x3C, 0x96, 0xFF, 0x00) ---");
        verify_valid_rx(8'h3C);
        verify_valid_rx(8'h96);
        verify_valid_rx(8'hFF);
        verify_valid_rx(8'h00);

        $display("\n====================================================================");
        if (error_count == 0) begin
            $display(" tb_uart_rx RESULT: ALL TESTS PASSED (errors=0)");
        end else begin
            $display(" tb_uart_rx RESULT: TESTS FAILED (errors=%0d)", error_count);
        end
        $display("====================================================================");
        $finish;
    end

endmodule
