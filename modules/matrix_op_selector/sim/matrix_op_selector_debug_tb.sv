`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module matrix_op_selector_debug_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 100MHz

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic confirm_btn;
    
    // New Inputs
    logic [31:0] scalar_in;
    logic random_scalar;
    op_mode_t op_mode_in;
    calc_type_t calc_type_in;
    logic [31:0] countdown_time_in;
    
    // Input Buffer Interface
    logic [31:0] buf_rd_data;
    logic [10:0] num_count;
    logic buf_clear_req;
    logic [3:0] buf_rd_addr;
    
    // Matrix Storage Interface
    logic [31:0] bram_rd_data;
    logic [13:0] bram_addr;
    
    // UART Interface
    logic uart_tx_ready;
    logic [7:0] uart_tx_data;
    logic uart_tx_valid;
    
    // Outputs
    logic led_error;
    logic [7:0] seg;
    logic [3:0] an;
    logic result_valid;
    logic abort;
    calc_type_t result_op;
    logic [2:0] result_matrix_a;
    logic [2:0] result_matrix_b;
    logic [31:0] result_scalar;

    // Internal Buffer Simulation
    logic [31:0] input_buffer [0:15];

    // DUT Instantiation
    matrix_op_selector u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .random_scalar(random_scalar),
        .op_mode_in(op_mode_in),
        .calc_type_in(calc_type_in),
        .countdown_time_in(countdown_time_in),
        
        // UART Interface
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        
        // Buffer Interface
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data),
        .num_count(num_count),
        .buf_clear_req(buf_clear_req),
        
        // BRAM Interface
        .bram_addr(bram_addr),
        .bram_data(bram_rd_data),
        
        // Status / Output
        .led_error(led_error),
        .seg(seg),
        .an(an),
        
        // Result Output
        .result_valid(result_valid),
        .abort(abort),
        .result_op(result_op),
        .result_matrix_a(result_matrix_a),
        .result_matrix_b(result_matrix_b),
        .result_scalar(result_scalar)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Buffer Logic
    always_ff @(posedge clk) begin
        if (buf_rd_addr < 16) begin
            buf_rd_data <= input_buffer[buf_rd_addr];
        end else begin
            buf_rd_data <= 32'h0;
        end
    end

    // BRAM Logic (Simulate Matrix Headers)
    // Address map: ID * 1152. Header at offset 0.
    // Header format: [31:24] Rows, [23:16] Cols, [15:0] Reserved
    always_ff @(posedge clk) begin
        case (bram_addr)
            14'd0: bram_rd_data <= {8'd3, 8'd3, 16'h0}; // Matrix 0: 3x3
            14'd1152: bram_rd_data <= {8'd2, 8'd2, 16'h0}; // Matrix 1: 2x2
            14'd2304: bram_rd_data <= {8'd3, 8'd3, 16'h0}; // Matrix 2: 3x3
            default: bram_rd_data <= 32'h0;
        endcase
    end

    // UART Ready Logic
    initial begin
        uart_tx_ready = 1;
    end
    
    // Simulate UART busy/ready behavior
    always @(posedge clk) begin
        if (uart_tx_valid) begin
            uart_tx_ready <= 0;
            repeat(10) @(posedge clk); // Simulate transmission time
            uart_tx_ready <= 1;
        end
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        rst_n = 0;
        start = 0;
        confirm_btn = 0;
        scalar_in = 0;
        random_scalar = 0;
        op_mode_in = OP_DOUBLE; // Matrix Add (Double Operand)
        calc_type_in = CALC_ADD;
        countdown_time_in = 32'd1000; // Short timeout for sim
        num_count = 0;
        
        // Initialize Buffer
        for (int i = 0; i < 16; i++) input_buffer[i] = 0;

        // Reset
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);

        $display("Test Started: Matrix Op Selector Debug");

        // Scenario: User inputs "3 3" via UART (simulated by filling buffer)
        // 1. Fill Buffer
        input_buffer[0] = 3;
        input_buffer[1] = 3;
        num_count = 2;
        $display("Buffer Filled: 3 3");

        // 2. User presses Start (S4)
        #(CLK_PERIOD*10);
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        $display("Start Signal Sent");

        // Monitor State
        wait(u_dut.state == SCAN_MATRICES);
        $display("State: SCAN_MATRICES reached");
        
        wait(u_dut.state == DISPLAY_LIST);
        $display("State: DISPLAY_LIST reached");

        // Wait for Display List to finish (it sends UART data)
        // In DISPLAY_LIST state, it waits for reader_done.
        // matrix_reader sends data via UART.
        
        // Let it run for a while
        #(CLK_PERIOD*2000);
        
        if (u_dut.state == DISPLAY_LIST) begin
             $display("Still in DISPLAY_LIST...");
        end else if (u_dut.state == SELECT_A) begin
             $display("Moved to SELECT_A");
        end else begin
             $display("Current State: %d", u_dut.state);
        end

        // Simulate User Selection (Matrix ID 0)
        // User inputs "0"
        input_buffer[0] = 0;
        num_count = 1;
        // Note: In real hardware, input_subsystem would reset count and fill buffer again.
        // Here we just overwrite.
        
        // User presses Confirm (S4)
        #(CLK_PERIOD*100);
        confirm_btn = 1;
        #(CLK_PERIOD);
        confirm_btn = 0;
        $display("Confirm Button Pressed (Select A)");

        #(CLK_PERIOD*1000);
        $display("Current State: %d", u_dut.state);

        $finish;
    end

    // Monitor internal signals
    always @(posedge clk) begin
        if (u_dut.state == GET_DIMS) $display("Time %t: State GET_DIMS, input_count=%d", $time, num_count);
        if (u_dut.state == WAIT_M) $display("Time %t: State WAIT_M", $time);
        if (u_dut.state == READ_M) $display("Time %t: State READ_M, data=%d", $time, buf_rd_data);
        if (u_dut.state == WAIT_N) $display("Time %t: State WAIT_N", $time);
        if (u_dut.state == READ_N) $display("Time %t: State READ_N, data=%d", $time, buf_rd_data);
        
        if (u_dut.scanner_start) $display("Time %t: Scanner Start Pulse", $time);
        if (u_dut.scanner_done) $display("Time %t: Scanner Done Pulse", $time);
        if (u_dut.state == WAIT_SCANNER && u_dut.scanner_busy) $display("Time %t: Waiting for Scanner...", $time);
        if (u_dut.state == ERROR_WAIT) $display("Time %t: State ERROR_WAIT reached (valid_mask=%b)", $time, u_dut.valid_mask);
        
        if (u_dut.scanner_busy) $display("Time %t: Scanner Busy. Addr=%d, Data=%h", $time, bram_addr, bram_rd_data);
        if (u_dut.state == SCAN_MATRICES) $display("Time %t: Target M=%d, N=%d", $time, u_dut.target_m, u_dut.target_n);
    end

endmodule
