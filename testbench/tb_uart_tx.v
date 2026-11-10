`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench   : tb_uart_tx
// Description : Self-checking Verilog testbench for UART Transmitter + Baud Gen.
//               Verifies reset, 9600-baud bit timing, start bit, LSB-first
//               8-bit serialization, stop bit, busy protection, and multi-byte
//               transmission.
//------------------------------------------------------------------------------
module tb_uart_tx;

    localparam CLK_PERIOD  = 10;       // 100 MHz
    localparam BAUD_BIT_NS = 104160;   // 651 * 16 * 10 ns (~9600 baud)

    reg        clk;
    reg        rst;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       sample_tick;
    wire       baud_tick;
    wire       tx_load;
    wire       tx_shift_en;
    wire [1:0] tx_bit_sel;
    wire       tx_busy;
    wire       tx_done;
    wire       tx;

    integer error_count;
    integer bit_idx;
    reg [7:0] captured_bits;
    reg       got_tx_done;
    time      t_start_mid;
    time      t_stop_mid;
    time      measured_bit_ns;

    // Baud rate generator
    baud_rate_gen u_baud (
        .clk         (clk),
        .rst         (rst),
        .sample_tick (sample_tick),
        .baud_tick   (baud_tick)
    );

    // TX control FSM
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

    // UART TX datapath
    uart_tx u_uart_tx (
        .clk         (clk),
        .rst         (rst),
        .tx_data     (tx_data),
        .tx_load     (tx_load),
        .tx_shift_en (tx_shift_en),
        .tx_bit_sel  (tx_bit_sel),
        .tx          (tx)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Latch 1-cycle tx_done pulse
    always @(posedge clk) begin
        if (rst) begin
            got_tx_done <= 1'b0;
        end else if (tx_done) begin
            got_tx_done <= 1'b1;
        end
    end

    // Monitor serial frame on tx line and verify start, LSB-first data, stop, baud timing
    task send_and_verify_byte;
        input [7:0] expected_byte;
        integer     timeout;
        begin
            @(negedge clk);
            got_tx_done = 1'b0;
            tx_data     = expected_byte;
            tx_start    = 1'b1;
            @(negedge clk);
            tx_start    = 1'b0;

            // Verify tx_busy asserts immediately
            if (tx_busy !== 1'b1) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] tx_busy did not assert for byte 0x%02h", $time, expected_byte);
            end

            // Wait for Start bit falling edge
            @(negedge tx);

            // Sample middle of Start bit
            #(BAUD_BIT_NS / 2);
            t_start_mid = $time;
            if (tx !== 1'b0) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] Start bit expected 0, got %0b", $time, tx);
            end

            // Sample 8 data bits (LSB first: bit 0 -> bit 7)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #(BAUD_BIT_NS);
                captured_bits[bit_idx] = tx;
                if (tx !== expected_byte[bit_idx]) begin
                    error_count = error_count + 1;
                    $display("[FAIL][%0t ns] Bit[%0d] mismatch: expected=%0b actual=%0b",
                             $time, bit_idx, expected_byte[bit_idx], tx);
                end
            end

            // Sample middle of Stop bit
            #(BAUD_BIT_NS);
            t_stop_mid = $time;
            if (tx !== 1'b1) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] Stop bit expected 1, got %0b", $time, tx);
            end

            // Verify baud rate bit period (~104,160 ns)
            measured_bit_ns = (t_stop_mid - t_start_mid) / 9;
            if (measured_bit_ns < 103000 || measured_bit_ns > 105500) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] Bit period out of 9600-baud range: %0t ns",
                         $time, measured_bit_ns);
            end

            // Wait for tx_done pulse
            timeout = 0;
            while (!got_tx_done && timeout < 20000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!got_tx_done) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] tx_done pulse timed out", $time);
            end

            if (captured_bits === expected_byte) begin
                $display("[PASS][%0t ns] TX byte=0x%02h (LSB-first serial match, bit_period=%0t ns)",
                         $time, captured_bits, measured_bit_ns);
            end else begin
                $display("[FAIL][%0t ns] TX byte mismatch: expected=0x%02h actual=0x%02h",
                         $time, expected_byte, captured_bits);
            end
        end
    endtask

    initial begin
        rst         = 1'b0;
        tx_start    = 1'b0;
        tx_data     = 8'h00;
        error_count = 0;

        $display("====================================================================");
        $display(" Starting UART Transmitter Testbench (9600 baud, 8N1)");
        $display("====================================================================");

        // Reset test
        @(negedge clk);
        rst = 1'b1;
        repeat (4) @(posedge clk);
        #1;
        if (tx !== 1'b1 || tx_busy !== 1'b0 || tx_done !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] TX reset check failed: tx=%0b tx_busy=%0b tx_done=%0b",
                     tx, tx_busy, tx_done);
        end else begin
            $display("[PASS] Reset operation verified (tx=1, tx_busy=0, tx_done=0)");
        end

        @(negedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        // Single-byte transmission (non-palindromic byte to verify LSB-first order)
        $display("\n--- Single-Byte Transmission (0xA3 = 8'b10100011) ---");
        send_and_verify_byte(8'hA3);

        // Multiple-byte transmission
        $display("\n--- Multiple-Byte Transmission (0x55, 0x41, 0x0F) ---");
        send_and_verify_byte(8'h55);
        send_and_verify_byte(8'h41);
        send_and_verify_byte(8'h0F);

        $display("\n====================================================================");
        if (error_count == 0) begin
            $display(" tb_uart_tx RESULT: ALL TESTS PASSED (errors=0)");
        end else begin
            $display(" tb_uart_tx RESULT: TESTS FAILED (errors=%0d)", error_count);
        end
        $display("====================================================================");
        $finish;
    end

endmodule
