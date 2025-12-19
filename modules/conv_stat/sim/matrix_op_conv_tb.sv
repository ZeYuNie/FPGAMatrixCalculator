`timescale 1ns / 1ps

import matrix_op_defs_pkg::*;

module matrix_op_conv_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter ADDR_WIDTH = 14;
    parameter DATA_WIDTH = 32;

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

    // BRAM Memory
    logic [DATA_WIDTH-1:0] bram_mem [0:BLOCK_SIZE*8-1];

    // DUT Instantiation
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

    // BRAM Read Logic (1 cycle latency)
    always_ff @(posedge clk) begin
        data_out <= bram_mem[read_addr];
    end

    // Test Sequence
    initial begin
        // Initialize Signals
        rst_n = 0;
        start = 0;
        matrix_src_id = 1; // Use Matrix 1 as kernel source
        write_ready = 1;   // Always ready to write
        writer_ready = 1;
        write_done = 0;

        // Initialize BRAM with Kernel (Matrix 1)
        // Base address = 1 * 1152 = 1152
        // Metadata (Word 0): Rows=3, Cols=3.
        // Packed: {8'd3, 8'd3, 16'b0} = 0x03030000
        bram_mem[1152] = 32'h03030000;
        
        // Kernel Data (1 2 3 4 5 6 7 8 9)
        // Data starts at offset 3 (after 3 metadata words)
        bram_mem[1152 + 3] = 1;
        bram_mem[1152 + 4] = 2;
        bram_mem[1152 + 5] = 3;
        bram_mem[1152 + 6] = 4;
        bram_mem[1152 + 7] = 5;
        bram_mem[1152 + 8] = 6;
        bram_mem[1152 + 9] = 7;
        bram_mem[1152 + 10] = 8;
        bram_mem[1152 + 11] = 9;

        // Reset
        #20;
        rst_n = 1;
        #20;

        // Start Operation
        $display("Starting Convolution Test...");
        start = 1;
        #10;
        start = 0;

        // Wait for completion
        wait(busy == 0);
        #100;
        
        $display("Test Completed.");
        $finish;
    end

    // Monitor Write Data
    initial begin
        forever begin
            @(posedge clk);
            if (data_valid && writer_ready) begin
                $display("Output Data: %d", signed'(data_in));
            end
        end
    end

    // Debug X
    initial begin
        wait(start);
        @(posedge clk);
        $display("Debug: read_addr=%h, data_out=%h", read_addr, data_out);
        
        wait(dut.u_conv_wrapper.state == 1); // ST_LOAD_IMAGE
        @(posedge clk);
        $display("Debug: ROM addr=%d, data=%h", dut.u_conv_wrapper.rom_inst.addr, dut.u_conv_wrapper.rom_data);
        
        wait(dut.u_conv_wrapper.state == 2); // ST_CONV
        @(posedge clk);
        $display("Debug: Kernel[0][0]=%d", dut.u_conv_wrapper.conv_kernel_in[0][0]);
        $display("Debug: Image[0][0]=%d", dut.u_conv_wrapper.conv_image_in[0][0]);
    end
    
    // Handle Write Handshake
    always @(posedge clk) begin
        if (write_request && write_ready) begin
            // Simulate writer starting
            #20; // Delay
            // writer_ready is already 1
        end
        
        // Simulate write_done pulse when busy goes low? 
        // No, write_done comes from writer.
        // Here we just simulate it.
        if (dut.state == dut.WAIT_WRITE_DONE) begin
             #10;
             write_done = 1;
             #10;
             write_done = 0;
        end
    end

endmodule
