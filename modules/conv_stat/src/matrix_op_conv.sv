`timescale 1ns / 1ps

import matrix_op_defs_pkg::*;

module matrix_op_conv #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control
    input  logic                  start,
    input  logic [2:0]            matrix_src_id,
    output logic                  busy,
    output matrix_op_status_e     status,
    
    // BRAM Read
    output logic [ADDR_WIDTH-1:0] read_addr,
    input  logic [DATA_WIDTH-1:0] data_out,
    
    // Storage Manager Write
    output logic                  write_request,
    input  logic                  write_ready,
    output logic [2:0]            matrix_id,
    output logic [7:0]            actual_rows,
    output logic [7:0]            actual_cols,
    output logic [7:0]            matrix_name [0:7],
    output logic [DATA_WIDTH-1:0] data_in,
    output logic                  data_valid,
    input  logic                  writer_ready,
    input  logic                  write_done,
    output logic [31:0]           cycle_count
);

    // Internal States
    typedef enum logic [3:0] {
        IDLE,
        READ_METADATA,
        CHECK_DIMENSIONS,
        READ_KERNEL,
        WAIT_READ,
        EXECUTE,
        WAIT_EXECUTE,
        REQ_WRITE,
        WAIT_WRITE_ENABLE,
        WRITE_DATA,
        WAIT_WRITE_DONE,
        DONE,
        ERROR
    } state_t;

    state_t state;
    
    // Internal Signals
    logic [ADDR_WIDTH-1:0] base_addr_src;
    logic [3:0] read_count;
    logic [31:0] kernel_buffer [0:2][0:2];
    logic [31:0] result_buffer [0:7][0:9];
    
    logic conv_start;
    logic conv_done;
    
    logic [6:0] write_idx; // 0 to 79
    
    // Wrapper Instance
    conv_stat_wrapper u_conv_wrapper (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv_start),
        .kernel_in(kernel_buffer),
        .result_out(result_buffer),
        .done(conv_done),
        .cycle_count(cycle_count)
    );

    // Base Address Calculation
    assign base_addr_src = matrix_src_id * BLOCK_SIZE;

    // Output Assignments
    assign matrix_id = 0; // Always write to matrix 0 (Ans)
    assign actual_rows = 8;
    assign actual_cols = 10;
    
    // Name "CONV_RES"
    assign matrix_name[0] = "C";
    assign matrix_name[1] = "O";
    assign matrix_name[2] = "N";
    assign matrix_name[3] = "V";
    assign matrix_name[4] = "_";
    assign matrix_name[5] = "R";
    assign matrix_name[6] = "E";
    assign matrix_name[7] = "S";

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            status <= MATRIX_OP_STATUS_IDLE;
            read_addr <= 0;
            write_request <= 0;
            data_in <= 0;
            data_valid <= 0;
            conv_start <= 0;
            read_count <= 0;
            write_idx <= 0;
            kernel_buffer <= '{default: 0};
        end else begin
            // Default pulses
            conv_start <= 0;
            
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (start) begin
                        busy <= 1;
                        status <= MATRIX_OP_STATUS_BUSY;
                        state <= READ_METADATA;
                        // Read rows/cols (word 0 contains rows/cols packed)
                        read_addr <= base_addr_src; 
                    end
                end
                
                READ_METADATA: begin
                    // Wait one cycle for BRAM data (already happened in IDLE->READ transition if we set addr there)
                    // But we set addr in IDLE, so data is available now?
                    // Standard BRAM has 1 or 2 cycle latency. Assuming 1 cycle latency from addr change.
                    // If we set addr in IDLE, data is valid in next cycle (this one).
                    state <= CHECK_DIMENSIONS;
                end
                
                CHECK_DIMENSIONS: begin
                    matrix_shape_t shape;
                    shape = decode_shape_word(data_out);
                    
                    if (shape.rows == 3 && shape.cols == 3) begin
                        read_count <= 0;
                        state <= READ_KERNEL;
                    end else begin
                        status <= MATRIX_OP_STATUS_ERR_DIM;
                        state <= ERROR;
                    end
                end
                
                READ_KERNEL: begin
                    if (read_count < 9) begin
                        // Read data at index read_count
                        // Address = base + metadata_words + read_count
                        read_addr <= base_addr_src + MATRIX_METADATA_WORDS + read_count;
                        state <= WAIT_READ;
                    end else begin
                        state <= EXECUTE;
                    end
                end
                
                WAIT_READ: begin
                    // Data available next cycle
                    // Store data
                    logic [1:0] r, c;
                    r = read_count / 3;
                    c = read_count % 3;
                    kernel_buffer[r][c] <= data_out;
                    
                    read_count <= read_count + 1;
                    state <= READ_KERNEL;
                end
                
                EXECUTE: begin
                    conv_start <= 1;
                    state <= WAIT_EXECUTE;
                end
                
                WAIT_EXECUTE: begin
                    if (conv_done) begin
                        state <= REQ_WRITE;
                    end
                end
                
                REQ_WRITE: begin
                    if (write_ready) begin
                        write_request <= 1;
                        state <= WAIT_WRITE_ENABLE;
                    end
                end
                
                WAIT_WRITE_ENABLE: begin
                    // Keep request high until writer_ready
                    write_request <= 1;
                    if (writer_ready) begin
                        write_request <= 0;
                        write_idx <= 0;
                        state <= WRITE_DATA;
                    end
                end
                
                WRITE_DATA: begin
                    if (write_idx < 80) begin
                        if (writer_ready) begin
                            logic [2:0] r;
                            logic [3:0] c;
                            r = write_idx / 10;
                            c = write_idx % 10;
                            
                            data_in <= result_buffer[r][c];
                            data_valid <= 1;
                            write_idx <= write_idx + 1;
                        end
                    end else begin
                        data_valid <= 0;
                        state <= WAIT_WRITE_DONE;
                    end
                end
                
                WAIT_WRITE_DONE: begin
                    data_valid <= 0;
                    if (write_done) begin
                        status <= MATRIX_OP_STATUS_SUCCESS;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    busy <= 0;
                    state <= IDLE;
                end
                
                ERROR: begin
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
