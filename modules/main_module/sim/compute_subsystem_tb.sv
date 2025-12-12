`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module compute_subsystem_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic confirm_btn;
    logic [31:0] scalar_in;
    logic random_scalar;
    op_mode_t op_mode_in;
    calc_type_t calc_type_in;
    logic [31:0] settings_countdown;
    
    logic busy;
    logic done;
    logic error;
    logic [7:0] seg;
    logic [3:0] an;
    
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    logic [7:0] uart_tx_data;
    logic uart_tx_valid;
    logic uart_tx_ready;
    
    logic [ADDR_WIDTH-1:0] bram_rd_addr;
    logic [DATA_WIDTH-1:0] bram_rd_data;
    
    logic write_request;
    logic write_ready;
    logic [2:0] write_matrix_id;
    logic [7:0] write_rows;
    logic [7:0] write_cols;
    logic [7:0] write_name [0:7];
    logic [DATA_WIDTH-1:0] write_data;
    logic write_data_valid;
    logic write_done;
    logic writer_ready;

    // Mock BRAM
    logic [31:0] mock_bram [0:16383];

    // DUT Instantiation
    compute_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .random_scalar(random_scalar),
        .op_mode_in(op_mode_in),
        .calc_type_in(calc_type_in),
        .settings_countdown(settings_countdown),
        .busy(busy),
        .done(done),
        .error(error),
        .seg(seg),
        .an(an),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .bram_rd_addr(bram_rd_addr),
        .bram_rd_data(bram_rd_data),
        .write_request(write_request),
        .write_ready(write_ready),
        .write_matrix_id(write_matrix_id),
        .write_rows(write_rows),
        .write_cols(write_cols),
        .write_name(write_name),
        .write_data(write_data),
        .write_data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Mock BRAM Logic
    always @(posedge clk) begin
        bram_rd_data <= mock_bram[bram_rd_addr];
    end

    // Helper Task: Send UART Byte
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data <= data;
            uart_rx_valid <= 1;
            @(posedge clk);
            uart_rx_valid <= 0;
            repeat(5) @(posedge clk); // Wait between bytes
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

    // Helper Task: Toggle Confirm
    task toggle_confirm();
        begin
            @(posedge clk);
            confirm_btn <= 1;
            @(posedge clk);
            confirm_btn <= 0;
            repeat(10) @(posedge clk);
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize Signals
        rst_n = 0;
        start = 0;
        confirm_btn = 0;
        scalar_in = 0;
        random_scalar = 0;
        op_mode_in = OP_SINGLE; // Default to Transpose
        calc_type_in = CALC_TRANSPOSE;
        settings_countdown = 32'd1000; // Long timeout
        uart_rx_data = 0;
        uart_rx_valid = 0;
        uart_tx_ready = 1;
        write_ready = 1;
        write_done = 0;
        writer_ready = 1;

        // Initialize Mock BRAM
        // Clear BRAM
        for (int i = 0; i < 16384; i++) mock_bram[i] = 0;

        // Populate Matrix 1 (ID=1) at Slot 1 (Addr 1152)
        // Header: ID=1, Rows=2, Cols=2, Valid=1
        // Format: [31:24] ID, [23:16] Rows, [15:8] Cols, [0] Valid
        // 0x01020201
        mock_bram[1152] = 32'h01020201; 
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("Test 1: Transpose Operation");
        
        // Setup Op Mode
        op_mode_in = OP_SINGLE;
        calc_type_in = CALC_TRANSPOSE;

        // Start Selection
        start = 1;
        repeat(2) @(posedge clk);
        start = 0;

        // Wait for clear to finish
        #(CLK_PERIOD * 10);

        // 1. Input Dimensions: "2 2"
        send_string("2 2\n");
        
        // Wait for parsing
        #(CLK_PERIOD * 200);
        
        // Confirm Dimensions
        toggle_confirm();
        
        // Now it should scan matrices.
        // Wait for scanner to finish.
        #(CLK_PERIOD * 200);
        
        // 2. Select Matrix A: Input ID "1"
        send_string("1\n");
        
        // Wait for parsing
        #(CLK_PERIOD * 200);
        
        // Confirm Selection
        toggle_confirm();
        
        // Now it should be in VALIDATE -> DONE -> EXECUTING.
        
        // Wait for execution
        wait(done);
        $display("Test 1 Passed: Done signal asserted");
        
        #(CLK_PERIOD * 100);
        $finish;
    end

endmodule
