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

    // Helper Task: Send UART Byte
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data <= data;
            uart_rx_valid <= 1;
            @(posedge clk);
            uart_rx_valid <= 0;
            // Small delay between bytes
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

    always @(dut.u_input_buffer.validator_done)
        $display("[%0t] Validator Done (internal) changed to: %b", $time, dut.u_input_buffer.validator_done);

    always @(dut.u_input_buffer.parser_start)
        $display("[%0t] Parser Start changed to: %b", $time, dut.u_input_buffer.parser_start);

    always @(busy)
        $display("[%0t] BUSY signal changed to: %b", $time, busy);

    // Test Sequence
    initial begin
        // Initialize
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
        storage_rd_data = 0; // Assume empty slots (0)
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        //---------------------------------------------------------------------
        // Test 1: Settings Mode
        //---------------------------------------------------------------------
        $display("Test 1: Settings Mode");
        mode_is_settings = 1;
        
        // Send Settings Data: 5 5 -10 10 100 (MaxRow, MaxCol, Min, Max, Countdown)
        // Format: "5 5 -10 10 100 \n"
        $display("[%0t] Sending Settings String...", $time);
        
        fork
            send_string("5 5 -10 10 100 \n");
            begin
                fork
                    wait(busy);
                    begin
                        repeat(100000) @(posedge clk);
                        $display("Error: Timeout waiting for busy (parsing start) in Settings Mode");
                        $stop;
                    end
                join_any
                disable fork;
                $display("[%0t] Busy detected (Settings Mode)", $time);
            end
        join

        $display("[%0t] Settings String Sent. Waiting for finish...", $time);
        wait(!busy);
        $display("[%0t] Busy finished, starting processing...", $time);

        // Start Processing
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for Done or Error
        fork
            begin
                wait(done);
                @(posedge clk); // Wait for registers to update
                $display("Settings Done asserted.");
            end
            begin
                wait(error);
                $display("Settings Error asserted!");
            end
            begin
                repeat(10000) @(posedge clk);
                $display("Error: Timeout waiting for done/error in Settings Mode");
                $stop;
            end
        join_any
        disable fork;

        $display("Settings Updated: MaxRow=%d, MaxCol=%d", settings_max_row, settings_max_col);
        
        if (settings_max_row !== 5 || settings_max_col !== 5)
            $display("Error: Settings mismatch");
        else
            $display("Success: Settings correct");
            
        mode_is_settings = 0;
        #(CLK_PERIOD * 20);
        
        //---------------------------------------------------------------------
        // Test 2: Matrix Input Mode (Anonymous)
        //---------------------------------------------------------------------
        $display("Test 2: Matrix Input Mode");
        mode_is_input = 1;
        repeat(20) @(posedge clk);
        
        // Send Matrix Data: 2 2 1 2 3 4 (2x2 Matrix)
        $display("[%0t] Sending Matrix Input String...", $time);
        
        fork
            send_string("2 2 1 2 3 4 \n");
            begin
                fork
                    wait(busy);
                    begin
                        repeat(100000) @(posedge clk);
                        $display("Error: Timeout waiting for busy (parsing start) in Input Mode");
                        $stop;
                    end
                join_any
                disable fork;
                $display("[%0t] Busy detected (Input Mode)", $time);
            end
        join

        $display("[%0t] Matrix Input String Sent. Waiting for finish...", $time);
        wait(!busy);
        $display("[%0t] Busy finished, starting processing...", $time);

        // Start Processing
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for Write Request
        fork
            wait(write_request);
            begin
                wait(error);
                $display("Error asserted in Input Mode!");
                $stop;
            end
            begin
                repeat(10000) @(posedge clk);
                $display("Error: Timeout waiting for write_request in Input Mode");
                $stop;
            end
        join_any
        disable fork;

        $display("Write Request Received: ID=%d, Rows=%d, Cols=%d", matrix_id, actual_rows, actual_cols);
        
        // Simulate Write Process
        @(posedge clk);
        write_ready = 0; // Busy writing
        
        // Wait for data valid pulses
        repeat(4) @(posedge data_valid);
        
        // Finish Write
        #(CLK_PERIOD * 10);
        write_done = 1;
        write_ready = 1;
        @(posedge clk);
        write_done = 0;
        
        wait(done);
        $display("Matrix Input Done");
        
        mode_is_input = 0;
        #(CLK_PERIOD * 20);
        
        //---------------------------------------------------------------------
        // Test 3: Matrix Gen Mode
        //---------------------------------------------------------------------
        $display("Test 3: Matrix Gen Mode");
        mode_is_gen = 1;
        repeat(20) @(posedge clk);
        
        // Send Gen Params: 3 3 1 (One 3x3 Matrix)
        $display("[%0t] Sending Gen Params String...", $time);
        
        fork
            send_string("3 3 1 \n");
            begin
                fork
                    wait(busy);
                    begin
                        repeat(100000) @(posedge clk);
                        $display("Error: Timeout waiting for busy (parsing start) in Gen Mode");
                        $stop;
                    end
                join_any
                disable fork;
                $display("[%0t] Busy detected (Gen Mode)", $time);
            end
        join

        $display("[%0t] Gen Params String Sent. Waiting for finish...", $time);
        wait(!busy);
        $display("[%0t] Busy finished, starting processing...", $time);

        // Start Processing
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for Write Request
        fork
            wait(write_request);
            begin
                wait(error);
                $display("Error asserted in Gen Mode!");
                $stop;
            end
            begin
                repeat(10000) @(posedge clk);
                $display("Error: Timeout waiting for write_request in Gen Mode");
                $stop;
            end
        join_any
        disable fork;

        $display("Gen Write Request Received: ID=%d, Rows=%d, Cols=%d", matrix_id, actual_rows, actual_cols);
        
        // Simulate Write Process
        @(posedge clk);
        write_ready = 0;
        
        // Wait for data valid pulses (3x3 = 9)
        repeat(9) @(posedge data_valid);
        
        // Finish Write
        #(CLK_PERIOD * 10);
        write_done = 1;
        write_ready = 1;
        @(posedge clk);
        write_done = 0;
        
        wait(done);
        $display("Matrix Gen Done");
        
        $finish;
    end

endmodule
