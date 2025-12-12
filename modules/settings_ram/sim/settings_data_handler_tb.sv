`timescale 1ns / 1ps

module settings_data_handler_tb;

    // Clock and reset
    logic        clk;
    logic        rst_n;

    // Control signals
    logic        start;
    logic        busy;
    logic        done;
    logic        error;

    // RAM interface
    logic [10:0] buf_rd_addr;
    logic [31:0] buf_rd_data;
    logic [31:0] buffer_ram [0:15];

    // Settings output
    logic        settings_wr_en;
    logic [31:0] settings_max_row;
    logic [31:0] settings_max_col;
    logic [31:0] settings_data_min;
    logic [31:0] settings_data_max;
    logic [31:0] settings_countdown;

    // Instantiate DUT
    settings_data_handler dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .busy               (busy),
        .done               (done),
        .error              (error),
        .buf_rd_addr        (buf_rd_addr),
        .buf_rd_data        (buf_rd_data),
        .settings_wr_en     (settings_wr_en),
        .settings_max_row   (settings_max_row),
        .settings_max_col   (settings_max_col),
        .settings_data_min  (settings_data_min),
        .settings_data_max  (settings_data_max),
        .settings_countdown (settings_countdown)
    );

    // RAM read logic
    assign buf_rd_data = buffer_ram[buf_rd_addr];

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test counter
    int test_num = 0;

    // Task to reset the system
    task reset_system();
        rst_n = 0;
        start = 0;
        #20;
        rst_n = 1;
        #20;
    endtask

    // Task to load RAM with command and data
    task load_ram(input [31:0] cmd, input [31:0] data);
        buffer_ram[0] = cmd;
        buffer_ram[1] = data;
    endtask

    // Task to trigger start signal
    task trigger_start();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
    endtask

    // Task to wait for completion
    task wait_done();
        wait(done || error);
        @(posedge clk); // Wait for write cycle to complete
        @(posedge clk); // Wait one more cycle for RAM output to update
    endtask

    // Main test sequence
    initial begin
        $display("=== Settings Data Handler Testbench ===");
        
        // Initialize signals
        rst_n = 0;
        start = 0;
        
        // Reset system
        reset_system();
        
        // ===== Test 1: Set max row to 10 =====
        test_num = 1;
        $display("\n[Test %0d] Set max_row = 10", test_num);
        load_ram(32'd1, 32'd10);
        trigger_start();
        wait_done();
        
        if (!error && settings_max_row == 32'd10) begin
            $display("[Test %0d] PASSED: max_row = %0d", test_num, settings_max_row);
        end else begin
            $display("[Test %0d] FAILED: error=%b, max_row=%0d",
                     test_num, error, settings_max_row);
        end
        
        // ===== Test 2: Set max col to 20 =====
        test_num = 2;
        $display("\n[Test %0d] Set max_col = 20", test_num);
        load_ram(32'd2, 32'd20);
        trigger_start();
        wait_done();
        
        if (!error && settings_max_col == 32'd20) begin
            $display("[Test %0d] PASSED: max_col = %0d", test_num, settings_max_col);
        end else begin
            $display("[Test %0d] FAILED: error=%b, max_col=%0d",
                     test_num, error, settings_max_col);
        end
        
        // ===== Test 3: Set data_min to -100 =====
        test_num = 3;
        $display("\n[Test %0d] Set data_min = -100", test_num);
        load_ram(32'd3, 32'hFFFFFF9C); // -100 in two's complement
        trigger_start();
        wait_done();
        
        if (!error && settings_data_min == 32'hFFFFFF9C) begin
            $display("[Test %0d] PASSED: data_min = %0d (signed: %0d)",
                     test_num, settings_data_min, $signed(settings_data_min));
        end else begin
            $display("[Test %0d] FAILED: error=%b, data_min=%0d",
                     test_num, error, settings_data_min);
        end
        
        // ===== Test 4: Set data_max to 65535 =====
        test_num = 4;
        $display("\n[Test %0d] Set data_max = 65535", test_num);
        load_ram(32'd4, 32'd65535);
        trigger_start();
        wait_done();
        
        if (!error && settings_data_max == 32'd65535) begin
            $display("[Test %0d] PASSED: data_max = %0d", test_num, settings_data_max);
        end else begin
            $display("[Test %0d] FAILED: error=%b, data_max=%0d",
                     test_num, error, settings_data_max);
        end
        
        // ===== Test 5: Invalid command (should trigger error) =====
        test_num = 5;
        $display("\n[Test %0d] Invalid command = 6", test_num);
        reset_system(); // Clear error flag
        load_ram(32'd6, 32'd100); // Command 6 is invalid (valid are 1-5)
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for invalid command", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b (expected error=1, wr_en=0)", 
                     test_num, error, settings_wr_en);
        end
        
        // ===== Test 6: Row count = 0 (should trigger error) =====
        test_num = 6;
        $display("\n[Test %0d] max_row = 0 (invalid)", test_num);
        reset_system();
        load_ram(32'd1, 32'd0);
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for row=0", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b", test_num, error, settings_wr_en);
        end
        
        // ===== Test 7: Row count > 32 (should trigger error) =====
        test_num = 7;
        $display("\n[Test %0d] max_row = 33 (invalid)", test_num);
        reset_system();
        load_ram(32'd1, 32'd33);
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for row=33", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b", test_num, error, settings_wr_en);
        end
        
        // ===== Test 8: Col count = 32 (boundary test) =====
        test_num = 8;
        $display("\n[Test %0d] max_col = 32 (boundary)", test_num);
        reset_system();
        load_ram(32'd2, 32'd32);
        trigger_start();
        wait_done();
        
        if (!error && settings_max_col == 32'd32) begin
            $display("[Test %0d] PASSED: max_col = 32", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, max_col=%0d",
                     test_num, error, settings_max_col);
        end
        
        // ===== Test 9: data_max = 65536 (should trigger error) =====
        test_num = 9;
        $display("\n[Test %0d] data_max = 65536 (invalid)", test_num);
        reset_system();
        load_ram(32'd4, 32'd65536);
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for data_max=65536", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b", test_num, error, settings_wr_en);
        end
        
        // ===== Test 10: Error persistence test =====
        test_num = 10;
        $display("\n[Test %0d] Error persistence (try to start while error is set)", test_num);
        // Error should still be set from test 9
        load_ram(32'd1, 32'd10);
        trigger_start();
        #100; // Wait some cycles
        
        if (error && !busy) begin
            $display("[Test %0d] PASSED: Module rejected start while error is set", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, busy=%b (should not be busy)", 
                     test_num, error, busy);
        end
        
        // ===== Test 11: Multiple valid operations after reset =====
        test_num = 11;
        $display("\n[Test %0d] Multiple operations after reset", test_num);
        reset_system();
        
        // Set max_row = 8
        load_ram(32'd1, 32'd8);
        trigger_start();
        wait_done();
        if (!error && settings_max_row == 32'd8) begin
            $display("[Test %0d.1] PASSED: max_row = 8", test_num);
        end else begin
            $display("[Test %0d.1] FAILED", test_num);
        end
        
        // Set max_col = 12
        load_ram(32'd2, 32'd12);
        trigger_start();
        wait_done();
        if (!error && settings_max_col == 32'd12) begin
            $display("[Test %0d.2] PASSED: max_col = 12", test_num);
        end else begin
            $display("[Test %0d.2] FAILED", test_num);
        end

        // ===== Test 12: Set countdown time to 12 (valid) =====
        test_num = 12;
        $display("\n[Test %0d] Set countdown_time = 12", test_num);
        load_ram(32'd5, 32'd12);
        trigger_start();
        wait_done();
        
        if (!error && settings_countdown == 32'd12) begin
            $display("[Test %0d] PASSED: countdown_time = 12", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, countdown_time=%0d",
                     test_num, error, settings_countdown);
        end

        // ===== Test 13: Set countdown time to 4 (invalid) =====
        test_num = 13;
        $display("\n[Test %0d] Set countdown_time = 4 (invalid)", test_num);
        reset_system();
        load_ram(32'd5, 32'd4);
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for countdown_time=4", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b", test_num, error, settings_wr_en);
        end

        // ===== Test 14: Set countdown time to 16 (invalid) =====
        test_num = 14;
        $display("\n[Test %0d] Set countdown_time = 16 (invalid)", test_num);
        reset_system();
        load_ram(32'd5, 32'd16);
        trigger_start();
        wait_done();
        
        if (error && !settings_wr_en) begin
            $display("[Test %0d] PASSED: Error detected for countdown_time=16", test_num);
        end else begin
            $display("[Test %0d] FAILED: error=%b, wr_en=%b", test_num, error, settings_wr_en);
        end
        
        // Final summary
        $display("\n=== Test Complete ===");
        #100;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #50000;
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

    // Optional: Waveform dumping
    initial begin
        $dumpfile("settings_data_handler_tb.vcd");
        $dumpvars(0, settings_data_handler_tb);
    end

endmodule