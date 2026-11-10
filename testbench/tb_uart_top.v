`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench   : tb_uart_top
// Description : Top-level self-checking Verilog testbench for uart_top.
//               Verifies reset, TX serial frame & baud timing, RX reception,
//               loopback communication (single & multiple bytes), and exact
//               expected vs. actual received data matching.
//------------------------------------------------------------------------------
module tb_uart_top;

    localparam CLK_PERIOD   = 10;       // 100 MHz
    localparam BAUD_BIT_NS  = 104160;   // 651 * 16 * 10 ns (~9600 baud)
    localparam IDEAL_BIT_NS = 104167;   // 1 / 9600 s in ns

    reg        clk;
    reg        rst;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx;
    wire       tx_busy;
    wire       tx_done;

    reg        loopback_en;
    reg        rx_ext;
    wire       rx;
    wire [7:0] rx_data;
    wire       rx_busy;
    wire       rx_done;
    wire       rx_error;

    // Loopback multiplexer: external stimulus or TX->RX loopback
    assign rx = loopback_en ? tx : rx_ext;

    integer error_count;
    integer total_bytes_checked;
    integer i;
    reg       got_tx_done;
    reg       got_rx_done;
    reg [7:0] captured_rx_byte;
    reg [7:0] serial_tx_byte;
    time      t_start;
    time      t_stop;
    time      bit_period_ns;

    // Instantiate top-level UART DUT
    uart_top dut (
        .clk      (clk),
        .rst      (rst),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .rx       (rx),
        .rx_data  (rx_data),
        .rx_busy  (rx_busy),
        .rx_done  (rx_done),
        .rx_error (rx_error)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Latch 1-cycle tx_done and rx_done pulses
    always @(posedge clk) begin
        if (rst) begin
            got_tx_done      <= 1'b0;
            got_rx_done      <= 1'b0;
            captured_rx_byte <= 8'h00;
        end else begin
            if (tx_done) begin
                got_tx_done <= 1'b1;
            end
            if (rx_done) begin
                got_rx_done      <= 1'b1;
                captured_rx_byte <= rx_data;
            end
        end
    end

    // External RX frame driver (for standalone RX check)
    task send_external_rx_byte;
        input [7:0] data_byte;
        integer     b;
        begin
            @(negedge clk);
            got_rx_done = 1'b0;

            rx_ext = 1'b0; // Start bit
            #(IDEAL_BIT_NS);

            for (b = 0; b < 8; b = b + 1) begin
                rx_ext = data_byte[b]; // LSB first
                #(IDEAL_BIT_NS);
            end

            rx_ext = 1'b1; // Stop bit
            #(IDEAL_BIT_NS);

            total_bytes_checked = total_bytes_checked + 1;
            if (got_rx_done !== 1'b1 || rx_error !== 1'b0 || captured_rx_byte !== data_byte) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] Standalone RX mismatch: expected=0x%02h actual=0x%02h",
                         $time, data_byte, captured_rx_byte);
            end else begin
                $display("[PASS][%0t ns] Standalone RX matched: expected=0x%02h actual=0x%02h",
                         $time, data_byte, captured_rx_byte);
            end
        end
    endtask

    // TX -> RX loopback transaction with expected vs actual verification
    task run_loopback_byte;
        input [7:0] send_byte;
        integer     timeout;
        begin
            @(negedge clk);
            got_tx_done = 1'b0;
            got_rx_done = 1'b0;
            tx_data     = send_byte;
            tx_start    = 1'b1;
            @(negedge clk);
            tx_start    = 1'b0;

            // Wait for both TX completion and RX reception (up to ~1.5 ms = 150,000 clocks)
            timeout = 0;
            while (!(got_tx_done && got_rx_done) && timeout < 160000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            total_bytes_checked = total_bytes_checked + 1;
            if (!got_tx_done || !got_rx_done || rx_error !== 1'b0 || captured_rx_byte !== send_byte) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] Loopback mismatch: expected=0x%02h actual=0x%02h tx_done=%0b rx_done=%0b err=%0b",
                         $time, send_byte, captured_rx_byte, got_tx_done, got_rx_done, rx_error);
            end else begin
                $display("[PASS][%0t ns] Loopback MATCH: expected=0x%02h, actual=0x%02h",
                         $time, send_byte, captured_rx_byte);
            end
        end
    endtask

    initial begin
        rst                 = 1'b0;
        tx_start            = 1'b0;
        tx_data             = 8'h00;
        loopback_en         = 1'b0;
        rx_ext              = 1'b1;
        error_count         = 0;
        total_bytes_checked = 0;

        $display("====================================================================");
        $display(" Starting Top-Level UART (uart_top) Verification (9600 baud, 8N1)");
        $display("====================================================================");

        //----------------------------------------------------------------------
        // Test 1: Synchronous Reset Operation
        //----------------------------------------------------------------------
        $display("\n--- Test 1: Reset Operation ---");
        @(negedge clk);
        rst = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        if (tx !== 1'b1 || tx_busy !== 1'b0 || tx_done !== 1'b0 ||
            rx_data !== 8'h00 || rx_busy !== 1'b0 || rx_done !== 1'b0 || rx_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Reset output states incorrect");
        end else begin
            $display("[PASS] Synchronous reset verified on all TX and RX outputs");
        end

        @(negedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 2: Single-Byte TX Waveform & LSB-First Frame Check (0x9D)
        //----------------------------------------------------------------------
        $display("\n--- Test 2: Single-Byte TX Frame & Baud Check (0x9D = 8'b10011101) ---");
        @(negedge clk);
        got_tx_done = 1'b0;
        tx_data     = 8'h9D;
        tx_start    = 1'b1;
        @(negedge clk);
        tx_start    = 1'b0;

        @(negedge tx); // Start bit falling edge
        #(BAUD_BIT_NS / 2);
        t_start = $time;
        if (tx !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] TX start bit not 0");
        end
        for (i = 0; i < 8; i = i + 1) begin
            #(BAUD_BIT_NS);
            serial_tx_byte[i] = tx;
        end
        #(BAUD_BIT_NS);
        t_stop = $time;
        if (tx !== 1'b1) begin
            error_count = error_count + 1;
            $display("[FAIL] TX stop bit not 1");
        end
        bit_period_ns = (t_stop - t_start) / 9;
        i = 0;
        while (!got_tx_done && i < 10000) begin
            @(posedge clk);
            i = i + 1;
        end
        total_bytes_checked = total_bytes_checked + 1;
        if (serial_tx_byte !== 8'h9D || !got_tx_done ||
            bit_period_ns < 103000 || bit_period_ns > 105500) begin
            error_count = error_count + 1;
            $display("[FAIL] TX serial check failed: captured=0x%02h bit_period=%0t ns",
                     serial_tx_byte, bit_period_ns);
        end else begin
            $display("[PASS] TX 8N1 LSB-first verified: expected=0x9D actual=0x%02h (bit_period=%0t ns)",
                     serial_tx_byte, bit_period_ns);
        end

        //----------------------------------------------------------------------
        // Test 3: Single-Byte Standalone RX Reception (0x6B)
        //----------------------------------------------------------------------
        $display("\n--- Test 3: Single-Byte Standalone RX (0x6B) ---");
        send_external_rx_byte(8'h6B);

        //----------------------------------------------------------------------
        // Test 4: Loopback Communication (Single & Multiple Bytes)
        //----------------------------------------------------------------------
        $display("\n--- Test 4: TX -> RX Loopback (Single Byte 0xA5) ---");
        loopback_en = 1'b1;
        repeat (10) @(posedge clk);
        run_loopback_byte(8'hA5);

        $display("\n--- Test 5: Multiple-Byte Loopback (0x55, 0xAA, 0x12, 0x34, 0xF0, 0x0F) ---");
        run_loopback_byte(8'h55);
        run_loopback_byte(8'hAA);
        run_loopback_byte(8'h12);
        run_loopback_byte(8'h34);
        run_loopback_byte(8'hF0);
        run_loopback_byte(8'h0F);

        $display("\n====================================================================");
        $display(" Verification Summary");
        $display("   Total Bytes Checked : %0d", total_bytes_checked);
        $display("   Total Errors        : %0d", error_count);
        if (error_count == 0) begin
            $display("   RESULT              : ALL TESTS PASSED");
        end else begin
            $display("   RESULT              : TESTS FAILED");
        end
        $display("====================================================================");
        $finish;
    end

endmodule
