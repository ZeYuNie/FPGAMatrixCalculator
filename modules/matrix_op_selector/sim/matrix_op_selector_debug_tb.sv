`timescale 1ns / 1ps

module matrix_op_selector_debug_tb;

    // Parameters
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115200;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic confirm_btn;
    logic [31:0] scalar_in;
    logic random_scalar;
    logic [1:0] op_mode_in; // op_mode_t is enum, use logic for TB
    logic [2:0] calc_type_in; // calc_type_t is enum
    logic [31:0] countdown_time_in;
    
    logic [7:0] uart_tx_data;
    logic uart_tx_valid;
    logic uart_tx_ready;
    
    logic [3:0] buf_rd_addr;
    logic [31:0] buf_rd_data;
    logic [10:0] num_count;
    logic buf_clear_req;

    logic [13:0] bram_addr;
    logic [31:0] bram_rd_data;
    
    logic led_error;
    logic [7:0] seg;
    logic [3:0] an;
    
    logic result_valid;
    logic abort;
    logic [2:0] result_op;
    logic [2:0] result_matrix_a;
    logic [2:0] result_matrix_b;
    logic [31:0] result_scalar;

    // Instantiate DUT
    matrix_op_selector #(
        .BLOCK_SIZE(1152),
        .ADDR_WIDTH(14)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .random_scalar(random_scalar),
        .op_mode_in(op_mode_in), // 0: Single, 1: Double, 2: Scalar
        .calc_type_in(calc_type_in), // 0: Transpose
        .countdown_time_in(countdown_time_in),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data),
        .num_count(num_count),
        .buf_clear_req(buf_clear_req),
        .bram_addr(bram_addr),
        .bram_data(bram_rd_data),
        .led_error(led_error),
        .seg(seg),
        .an(an),
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
        forever #10 clk = ~clk; // 50MHz
    end

    // BRAM Simulation
    logic [31:0] bram_mem [0:16383]; // Larger BRAM

    always_ff @(posedge clk) begin
        bram_rd_data <= bram_mem[bram_addr];
    end

    // Input Buffer Simulation
    logic [31:0] input_buffer [0:15];
    
    always_comb begin
        buf_rd_data = input_buffer[buf_rd_addr];
    end

    always_ff @(posedge clk) begin
        if (buf_clear_req) begin
            num_count <= 0;
        end
    end

    // Initialize BRAM with a 4x4 matrix at ID 0
    initial begin
        // Clear BRAM
        for (int i = 0; i < 16384; i++) bram_mem[i] = 0;

        // Matrix 0: 4x4
        // Addr 0: Rows/Cols = 0x04040000
        bram_mem[0] = 32'h04040000;
        // Addr 1: Name Part 1 = "MATA"
        bram_mem[1] = 32'h4D415441;
        // Addr 2: Name Part 2 = "    "
        bram_mem[2] = 32'h20202020;
        // Data...
        for (int i = 0; i < 16; i++) begin
            bram_mem[3+i] = i + 1;
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
        op_mode_in = 0; // Single (Transpose)
        calc_type_in = 0; // Transpose
        countdown_time_in = 10; // 10 seconds
        uart_tx_ready = 1; // Always ready
        num_count = 0;
        
        // Reset
        #100;
        rst_n = 1;
        #100;

        $display("Starting Test...");

        // 1. Start Selection
        start = 1;
        #20;
        start = 0;

        // Wait for GET_DIMS
        wait(u_dut.state == 1); // GET_DIMS
        $display("State: GET_DIMS reached");

        // 2. Simulate User Input "4 4"
        input_buffer[0] = 4;
        input_buffer[1] = 4;
        num_count = 2;
        
        #100;
        
        // 3. Press Confirm
        confirm_btn = 1;
        #20;
        confirm_btn = 0;

        // Wait for SCAN_MATRICES
        wait(u_dut.state == 6); // SCAN_MATRICES
        $display("State: SCAN_MATRICES reached");

        // Wait for DISPLAY_LIST
        wait(u_dut.state == 8); // DISPLAY_LIST
        $display("State: DISPLAY_LIST reached");

        // Monitor Reader
        fork
            begin
                wait(u_dut.state == 10); // SELECT_A
                $display("State: SELECT_A reached");
            end
            begin
                #1000000; // Increase timeout
                $display("Timeout waiting for SELECT_A");
            end
        join_any

        #1000;
        $finish;
    end

    // Monitor Internal Signals
    always @(posedge clk) begin
        if (u_dut.state == 8 || u_dut.state == 9) begin // DISPLAY_LIST or WAIT_READER_LIST
            if (u_dut.reader_start) $display("Reader Start Pulse at %t", $time);
            if (u_dut.reader_done) $display("Reader Done Pulse at %t", $time);
            if (u_dut.uart_tx_valid) $display("UART TX Valid: %c at %t", u_dut.uart_tx_data, $time);
        end
    end

endmodule
