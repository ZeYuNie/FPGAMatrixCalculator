`timescale 1ns / 1ps

module input_subsystem_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst_n;
    reg mode_is_input;
    reg mode_is_gen;
    reg mode_is_settings;
    reg start;
    wire busy;
    wire done;
    wire error;
    reg [7:0] uart_rx_data;
    reg uart_rx_valid;
    
    wire [31:0] settings_max_row;
    wire [31:0] settings_max_col;
    wire [31:0] settings_data_min;
    wire [31:0] settings_data_max;
    wire [31:0] settings_countdown;
    
    wire write_request;
    reg write_ready;
    wire [2:0] matrix_id;
    wire [7:0] actual_rows;
    wire [7:0] actual_cols;
    wire [7:0] matrix_name [0:7];
    wire [DATA_WIDTH-1:0] data_in;
    wire data_valid;
    reg write_done;
    reg writer_ready;
    
    wire [ADDR_WIDTH-1:0] storage_rd_addr;
    reg [DATA_WIDTH-1:0] storage_rd_data;

    // Mock Storage RAM (to support "Find Empty Slot")
    reg [31:0] mock_storage_ram [0:8191];

    // DUT Instantiation
    input_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_is_input(mode_is_input),
        .mode_is_gen(mode_is_gen),
        .mode_is_settings(mode_is_settings),
        .start(start),
        .busy(busy),
        .done(done),
        .error(error),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .settings_countdown(settings_countdown),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(matrix_id),
        .actual_rows(actual_rows),
        .actual_cols(actual_cols),
        .matrix_name(matrix_name),
        .data_in(data_in),
        .data_valid(data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .storage_rd_addr(storage_rd_addr),
        .storage_rd_data(storage_rd_data)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Mock Storage RAM Logic
    always @(posedge clk) begin
        storage_rd_data <= mock_storage_ram[storage_rd_addr];
    end

    // Helper Task: Send UART Byte
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data <= data;
            uart_rx_valid <= 1;
            @(posedge clk);
            uart_rx_valid <= 0;
            repeat(5) @(posedge clk);
        end
    endtask

    // Helper Task: Send String
    task send_string(input string str);
        integer i;
        begin
            for (i = 0; i < str.len(); i++) begin
                send_byte(str[i]);
            end
        end
    endtask

    // Helper Task: Reset System
    // This ensures buffer is cleared by toggling modes if necessary, or just hard reset
    task reset_system();
        begin
            rst_n = 0;
            mode_is_input = 0;
            mode_is_gen = 0;
            mode_is_settings = 0;
            start = 0;
            uart_rx_data = 0;
            uart_rx_valid = 0;
            write_ready = 1;
            write_done = 0;
            writer_ready = 1;
            
            // Clear Mock RAM
            for (int i = 0; i < 8192; i++) mock_storage_ram[i] = 0;

            #(CLK_PERIOD * 10);
            rst_n = 1;
            #(CLK_PERIOD * 10);
        end
    endtask

    // Helper Task: Handle Write Request
    task handle_write_request(input int expected_count);
        int count;
        begin
            // Wait for write request
            fork
                wait(write_request);
                begin
                    repeat(200000) @(posedge clk);
                    $display("Error: Timeout waiting for write_request");
                    $stop;
                end
            join_any
            disable fork;

            $display("[%0t] Write Request: ID=%d, Rows=%d, Cols=%d", $time, matrix_id, actual_rows, actual_cols);

            @(posedge clk);
            write_ready = 0; // Busy writing
            
            // Receive data
            count = 0;
            while (count < expected_count) begin
                @(posedge clk);
                if (data_valid && writer_ready) begin
                    $display("[%0t] Data Received: %d", $time, $signed(data_in));
                    count = count + 1;
                end
                
                // Timeout check for data stream
                if ($time > 200000000) begin // Safety timeout
                     $display("Error: Timeout waiting for data stream");
                     $stop;
                end
            end
            
            // Finish Write
            #(CLK_PERIOD * 5);
            write_done = 1;
            writer_ready = 0;
            @(posedge clk);
            write_done = 0;
            writer_ready = 1;
            write_ready = 1;
        end
    endtask

    // Debug Monitors
    always @(posedge clk) begin
        if (dut.u_input_buffer.ram_wr_en) begin
            $display("[%0t] RAM Write: Addr=%d, Data=%d", $time,
                dut.u_input_buffer.ram_wr_addr,
                dut.u_input_buffer.ram_wr_data);
        end
    end

    always @(posedge clk) begin
        if (dut.u_input_buffer.converter_result_valid) begin
            $display("[%0t] Parser Output: %d", $time,
                dut.u_input_buffer.converter_result);
        end
    end

    // Test Sequence
    initial begin
        $display("========================================");
        $display("Input Subsystem Comprehensive Testbench");
        $display("========================================");

        reset_system();

        //---------------------------------------------------------------------
        // Test Group 1: Settings Mode
        // Protocol: CMD DATA (One pair per start)
        // CMD 1=MaxRow, 2=MaxCol, 3=Min, 4=Max, 5=Countdown
        //---------------------------------------------------------------------
        $display("\n--- Test Group 1: Settings Mode ---");

        // 1.1 Valid Settings: Set MaxRow to 5
        $display("\n[Test 1.1] Set MaxRow=5 (CMD=1, Data=5)");
        mode_is_settings = 1;
        send_string("1 5 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(done);
        if (settings_max_row == 5)
            $display("PASS: MaxRow updated correctly");
        else
            $display("FAIL: MaxRow mismatch (Got %d)", settings_max_row);
        
        reset_system();

        // 1.2 Invalid MaxRow (>32)
        $display("\n[Test 1.2] Invalid MaxRow: 33 (CMD=1, Data=33)");
        mode_is_settings = 1;
        send_string("1 33 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(error);
        $display("PASS: Error asserted for MaxRow > 32");
        
        reset_system();

        // 1.3 Invalid Countdown (<5)
        $display("\n[Test 1.3] Invalid Countdown: 4 (CMD=5, Data=4)");
        mode_is_settings = 1;
        send_string("5 4 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(error);
        $display("PASS: Error asserted for Countdown < 5");

        reset_system();

        //---------------------------------------------------------------------
        // Test Group 2: Matrix Input Mode
        //---------------------------------------------------------------------
        $display("\n--- Test Group 2: Matrix Input Mode ---");

        // 2.1 Anonymous Matrix (Standard)
        $display("\n[Test 2.1] Anonymous Matrix: 2x2");
        mode_is_input = 1;
        send_string("2 2 1 2 3 4 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        handle_write_request(4); // 2x2 = 4 elements
        wait(done);
        $display("PASS: Anonymous Matrix Input Done");

        reset_system();

        // 2.2 Named Matrix
        // Format: -1 ID Name1 Name2 Rows Cols Data...
        // Name1=0, Name2=0
        $display("\n[Test 2.2] Named Matrix: ID=1, 2x2");
        mode_is_input = 1;
        send_string("-1 1 0 0 2 2 5 6 7 8 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        handle_write_request(4);
        if (matrix_id == 1)
            $display("PASS: Named Matrix ID=1 Correct");
        else
            $display("FAIL: Named Matrix ID mismatch (Got %d)", matrix_id);
        wait(done);

        reset_system();

        // 2.3 Dimension Overflow
        // Set limits first: MaxRow=5
        $display("\n[Test 2.3] Dimension Overflow (Max=5, Input=10)");
        mode_is_settings = 1;
        send_string("1 5 \n"); // Set MaxRow=5
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(done);
        
        reset_system(); // Clears buffer

        // Now input large matrix
        mode_is_input = 1;
        send_string("10 10 1 2 3 \n"); // Data doesn't matter, should fail at dims
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(error);
        $display("PASS: Error asserted for Dimension Overflow");

        reset_system();

        // 2.4 Data Value Overflow
        $display("\n[Test 2.4] Data Value Overflow (Max=100, Input=200)");
        // Set Max=100 (CMD=4, Data=100)
        mode_is_settings = 1;
        send_string("4 100 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(done);
        
        reset_system();

        // Input matrix with 200
        mode_is_input = 1;
        send_string("2 2 1 200 3 4 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        
        // It might start writing but then error out when it sees 200
        fork
            begin
                wait(write_request);
                @(posedge clk);
                write_ready = 0;
                // It will stream 1, then 200. 200 should trigger error.
                while (!error && !done) @(posedge clk);
            end
            wait(error);
        join_any
        
        if (error)
            $display("PASS: Error asserted for Data Value Overflow");
        else
            $display("FAIL: Error not asserted for Data Value Overflow");

        reset_system();

        // 2.5 Insufficient Data (Padding)
        $display("\n[Test 2.5] Insufficient Data: 2x2 but only 2 numbers");
        // Ensure settings allow the data (Default Max=9)
        mode_is_settings = 1;
        send_string("4 100 \n"); // Set Max=100
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(done);
        
        reset_system();

        mode_is_input = 1;
        send_string("2 2 5 6 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        
        // Should receive 4 numbers: 5, 6, and then padded zeros (or old data if not cleared)
        // Note: If buffer is not cleared, it might read old data.
        // But we just want to verify it doesn't hang and sends 4 items.
        handle_write_request(4);
        wait(done);
        $display("PASS: Insufficient Data handled (padded/completed)");

        reset_system();

        //---------------------------------------------------------------------
        // Test Group 3: Matrix Gen Mode
        //---------------------------------------------------------------------
        $display("\n--- Test Group 3: Matrix Gen Mode ---");

        // 3.1 Valid Gen
        $display("\n[Test 3.1] Valid Gen: 3x3, Count=1");
        mode_is_gen = 1;
        send_string("3 3 1 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        handle_write_request(9); // 3x3 = 9 elements
        wait(done);
        $display("PASS: Valid Gen Done");

        reset_system();

        // 3.2 Count Error (>2)
        $display("\n[Test 3.2] Count Error: Count=5");
        mode_is_gen = 1;
        send_string("3 3 5 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(error);
        $display("PASS: Error asserted for Count > 2");

        reset_system();

        // 3.3 Dimension Error
        $display("\n[Test 3.3] Dimension Error: 40x40");
        // Set MaxRow=32 (CMD=1, Data=32)
        mode_is_settings = 1;
        send_string("1 32 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(done);
        
        reset_system();

        mode_is_gen = 1;
        send_string("40 40 1 \n");
        wait(!busy);
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait(error);
        $display("PASS: Error asserted for Dimension > 32");

        $display("\n========================================");
        $display("All Tests Completed Successfully");
        $display("========================================");
        $finish;
    end

endmodule
