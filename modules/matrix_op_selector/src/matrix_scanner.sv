`timescale 1ns / 1ps

module matrix_scanner #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start,
    input  logic [7:0]            target_rows,
    input  logic [7:0]            target_cols,
    
    output logic [ADDR_WIDTH-1:0] bram_addr,
    input  logic [31:0]           bram_data,
    
    output logic [7:0]            valid_mask,
    output logic                  done,
    output logic                  busy
);

    logic [2:0] current_id;
    
    typedef enum logic [2:0] {
        IDLE,
        READ_META,
        WAIT_META,
        CHECK,
        NEXT,
        DONE_STATE
    } state_t;
    
    state_t state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_mask <= 8'b0;
            done <= 1'b0;
            busy <= 1'b0;
            current_id <= 3'd0;
            bram_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        valid_mask <= 8'b0;
                        current_id <= 3'd0;
                        state <= READ_META;
                    end else begin
                        busy <= 1'b0;
                    end
                end
                
                READ_META: begin
                    bram_addr <= current_id * BLOCK_SIZE;
                    state <= WAIT_META;
                end
                
                WAIT_META: begin
                    // Wait for BRAM read latency (1 cycle)
                    state <= CHECK;
                end
                
                CHECK: begin
                    // Check if dimensions match and matrix is not empty (0x0)
                    $display("Scanner CHECK: ID=%d, Data=%h, Target=%d,%d", current_id, bram_data, target_rows, target_cols);
                    if (bram_data[31:24] == target_rows && bram_data[23:16] == target_cols && bram_data[31:24] != 0 && bram_data[23:16] != 0) begin
                        valid_mask[current_id] <= 1'b1;
                        $display("  -> Match Found!");
                    end
                    state <= NEXT;
                end
                
                NEXT: begin
                    if (current_id == 3'd7) begin
                        state <= DONE_STATE;
                    end else begin
                        current_id <= current_id + 1'b1;
                        state <= READ_META;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
