`timescale 1ns / 1ps

import matrix_op_defs_pkg::*;

module matrix_op_conv_tb;

    // Parameters
    parameter int BLOCK_SIZE = 1024; // Smaller for sim
    parameter int ADDR_WIDTH = 14;
    parameter int DATA_WIDTH = 32;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic [2:0] matrix_src_id;
    logic busy;
    matrix_op_status_e status;
    
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [DATA_WIDTH-1:0] data_out;
    
    logic write_request;
    logic write_ready;
    logic [2:0] matrix_id;
    logic [7:0] actual_rows;
    logic [7:0] actual_cols;
    logic [7:0] matrix_name [0:7];
    logic [DATA_WIDTH-1:0] data_in;
    logic data_valid;
    logic writer_ready;
    logic write_done;
    logic [31:0] cycle_count;

    // BRAM Simulation
    logic [DATA_WIDTH-1:0] bram [0:BLOCK_SIZE*8-1];

    // DUT Instance
    matrix_op_conv #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_src_id(matrix_src_id),
        .busy(busy),
        .status(status),
        .read_addr(read_addr),
        .data_out(data_out),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(matrix_id),
        .actual_rows(actual_rows),
        .actual_cols(actual_cols),
        .matrix_name(matrix_name),
        .data_in(data_in),
        .data_valid(data_valid),
        .writer_ready(writer_ready),
        .write_done(write_done),
        .cycle_count(cycle_count)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // BRAM Logic
    always_ff @(posedge clk) begin
        data_out <= bram[read_addr];
    end

    // Writer Simulation
    initial begin
        write_ready = 1;
        writer_ready = 0;
        write_done = 0;
    end

    // Test Sequence
    initial begin
        int write_count;
        rst_n = 0;
        start = 0;
        matrix_src_id = 0;
        
        // Initialize BRAM with a 3x3 matrix at ID 1
        // Metadata: rows=3, cols=3
        bram[1*BLOCK_SIZE] = {8'd3, 8'd3, 16'd0}; 
        // Data: 1 to 9
        for (int i = 0; i < 9; i++) begin
            bram[1*BLOCK_SIZE + MATRIX_METADATA_WORDS + i] = i + 1;
        end

        #20 rst_n = 1;
        #20;

        $display("Starting Test...");

        // Start Operation
        matrix_src_id = 1;
        start = 1;
        #10 start = 0;

        // Wait for Write Request
        wait(write_request);
        $display("Write Request Received");
        
        #20;
        writer_ready = 1;
        
        // Monitor Writes
        write_count = 0;
        while (write_count < 80) begin
            @(posedge clk);
            if (data_valid && writer_ready) begin
                $display("Writing Data[%0d]: %d (State: %0d)", write_count, data_in, dut.state);
                write_count++;
            end
        end
        
        $display("All 80 items written.");
        writer_ready = 0;
        #20 write_done = 1;
        #10 write_done = 0;
        
        // Wait for busy to drop with timeout
        fork
            begin
                wait(!busy);
                $display("Busy dropped. Operation Done.");
            end
            begin
                #1000;
                $display("TIMEOUT waiting for busy to drop. State: %0d", dut.state);
                $finish;
            end
        join_any
        disable fork;

        $display("Operation Done. Status: %d", status);
        $display("Cycle Count: %d", cycle_count);
        
        if (status == MATRIX_OP_STATUS_SUCCESS) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end

        #100 $finish;
    end

endmodule
