`timescale 1ns / 1ps

module matrix_op_selector_tb;

    import matrix_op_selector_pkg::*;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter ADDR_WIDTH = 14;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic confirm_btn;
    logic [31:0] scalar_in;
    op_mode_t op_mode_in;
    calc_type_t calc_type_in;
    logic [31:0] countdown_time_in;
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    logic [7:0] uart_tx_data;
    logic uart_tx_valid;
    logic uart_tx_ready;
    logic [ADDR_WIDTH-1:0] bram_addr;
    logic [31:0] bram_data;
    logic led_error;
    logic [7:0] seg;
    logic [3:0] an;
    logic result_valid;
    calc_type_t result_op;
    logic [2:0] result_matrix_a;
    logic [2:0] result_matrix_b;
    logic [31:0] result_scalar;

    // DUT
    matrix_op_selector #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .op_mode_in(op_mode_in),
        .calc_type_in(calc_type_in),
        .countdown_time_in(countdown_time_in),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .bram_addr(bram_addr),
        .bram_data(bram_data),
        .led_error(led_error),
        .seg(seg),
        .an(an),
        .result_valid(result_valid),
        .result_op(result_op),
        .result_matrix_a(result_matrix_a),
        .result_matrix_b(result_matrix_b),
        .result_scalar(result_scalar)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Mock BRAM
    logic [31:0] mock_bram [0:16383]; // Increased size to cover address space
    
    always_ff @(posedge clk) begin
        bram_data <= mock_bram[bram_addr];
    end

    // Helper Tasks
    task send_uart_byte(input [7:0] data);
        @(posedge clk);
        uart_rx_data <= data;
        uart_rx_valid <= 1;
        @(posedge clk);
        uart_rx_valid <= 0;
        #100; // Wait a bit
    endtask

    task send_string(input string s);
        for (int i = 0; i < s.len(); i++) begin
            send_uart_byte(s[i]);
        end
    endtask

    // Debug Monitor
    always @(dut.state) begin
        $display("[%0t] DUT State changed to: %0d", $time, dut.state);
    end

    always @(dut.valid_mask) begin
        $display("[%0t] Valid Mask changed to: %b", $time, dut.valid_mask);
    end

    always @(dut.input_count) begin
        $display("[%0t] Input Count changed to: %0d", $time, dut.input_count);
    end

    always @(dut.u_input_parser.pkt_payload_last) begin
        $display("[%0t] Payload Last changed to: %b", $time, dut.u_input_parser.pkt_payload_last);
    end

    always @(dut.u_input_parser.validator_done) begin
        $display("[%0t] Validator Done changed to: %b", $time, dut.u_input_parser.validator_done);
    end

    always @(dut.input_clear) begin
        $display("[%0t] Input Clear changed to: %b", $time, dut.input_clear);
    end

    // Test Sequence
    initial begin
        $display("[%0t] Starting Simulation", $time);
        // Initialize
        rst_n = 0;
        start = 0;
        confirm_btn = 0;
        scalar_in = 0;
        op_mode_in = OP_DOUBLE; // Add
        calc_type_in = CALC_ADD;
        countdown_time_in = 32'd5; // 5 seconds
        uart_rx_data = 0;
        uart_rx_valid = 0;
        uart_tx_ready = 1;
        
        // Setup Mock BRAM
        // Matrix 0: 3x3
        mock_bram[0 * BLOCK_SIZE] = {8'd3, 8'd3, 16'd0};
        // Initialize data for Matrix 0
        for (int i = 0; i < 9; i++) begin
            mock_bram[0 * BLOCK_SIZE + 3 + i] = i;
        end

        // Matrix 1: 3x3
        mock_bram[1 * BLOCK_SIZE] = {8'd3, 8'd3, 16'd0};
        // Initialize data for Matrix 1
        for (int i = 0; i < 9; i++) begin
            mock_bram[1 * BLOCK_SIZE + 3 + i] = i + 10;
        end

        // Matrix 2: 4x4
        mock_bram[2 * BLOCK_SIZE] = {8'd4, 8'd4, 16'd0};
        
        #100;
        rst_n = 1;
        $display("[%0t] Reset Released", $time);
        #100;
        
        // Start
        start = 1;
        #10;
        start = 0;
        $display("[%0t] Module Started", $time);
        
        // 1. Input Dimensions: 3 3
        // Send newline to trigger packet processing
        send_string("3 3\n");
        #1000;
        $display("[%0t] Dimensions Sent", $time);
        
        confirm_btn = 1;
        #10;
        confirm_btn = 0;
        $display("[%0t] Dimensions Confirmed", $time);
        
        // Wait for scan and display
        #5000;
        
        // 2. Select Matrix A: 0
        send_string("0\n");
        #1000;
        $display("[%0t] Matrix A Selection Sent", $time);
        
        confirm_btn = 1;
        #10;
        confirm_btn = 0;
        $display("[%0t] Matrix A Confirmed", $time);
        
        // Wait for display A
        #2000;
        
        // 3. Select Matrix B: 1
        send_string("1\n");
        #1000;
        $display("[%0t] Matrix B Selection Sent", $time);
        
        confirm_btn = 1;
        #10;
        confirm_btn = 0;
        $display("[%0t] Matrix B Confirmed", $time);
        
        // Wait for validation and done
        $display("[%0t] Waiting for Result...", $time);
        wait(result_valid);
        $display("[%0t] Result Valid! Op: %0d, A: %0d, B: %0d", $time, result_op, result_matrix_a, result_matrix_b);
        
        if (result_op == CALC_ADD && result_matrix_a == 0 && result_matrix_b == 1)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
            
        #1000;
        $finish;
    end

endmodule
