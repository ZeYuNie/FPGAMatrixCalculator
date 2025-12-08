`timescale 1ns / 1ps

/**
 * matrix_clearer - Matrix Metadata Clearer
 * 
 * Clears matrix metadata by writing zeros to the first 3 addresses
 * of the specified matrix block in BRAM.
 * 
 * Operation:
 *   - Address 0: 32'h00000000 (rows=0, cols=0, 16'b0)
 *   - Address 1: 32'h00000000 (name[0:3]=0)
 *   - Address 2: 32'h00000000 (name[4:7]=0)
 */
module matrix_clearer #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Clear request interface
    input  logic                  clear_request,
    output logic                  clear_ready,
    input  logic [2:0]            matrix_id,
    output logic                  clear_done,
    
    // BRAM interface
    output logic                  bram_wr_en,
    output logic [ADDR_WIDTH-1:0] bram_addr,
    output logic [DATA_WIDTH-1:0] bram_din
);

    // FSM states
    typedef enum logic [2:0] {
        IDLE,
        CLEAR_META_0,      // Clear address 0: {rows, cols, 16'b0}
        CLEAR_META_1,      // Clear address 1: name[0:3]
        CLEAR_META_2,      // Clear address 2: name[4:7]
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Base address calculation
    logic [ADDR_WIDTH-1:0] base_addr;
    logic [ADDR_WIDTH-1:0] write_addr;
    
    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mag (
        .matrix_id(matrix_id),
        .base_addr(base_addr)
    );
    
    // State transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (clear_request) begin
                    next_state = CLEAR_META_0;
                end
            end
            
            CLEAR_META_0: begin
                next_state = CLEAR_META_1;
            end
            
            CLEAR_META_1: begin
                next_state = CLEAR_META_2;
            end
            
            CLEAR_META_2: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Datapath control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr <= '0;
            bram_wr_en <= 1'b0;
            bram_addr  <= '0;
            bram_din   <= '0;
            clear_done <= 1'b0;
        end else begin
            bram_wr_en <= 1'b0;
            bram_addr  <= write_addr;
            bram_din   <= 32'h00000000;  // Always write zeros
            clear_done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    write_addr <= base_addr;
                end
                
                CLEAR_META_0: begin
                    bram_wr_en <= 1'b1;
                    bram_addr  <= write_addr;
                    bram_din   <= 32'h00000000;
                    write_addr <= write_addr + 1;
                end
                
                CLEAR_META_1: begin
                    bram_wr_en <= 1'b1;
                    bram_addr  <= write_addr;
                    bram_din   <= 32'h00000000;
                    write_addr <= write_addr + 1;
                end
                
                CLEAR_META_2: begin
                    bram_wr_en <= 1'b1;
                    bram_addr  <= write_addr;
                    bram_din   <= 32'h00000000;
                    write_addr <= write_addr + 1;
                end
                
                DONE: begin
                    clear_done <= 1'b1;
                end
                
                default: begin
                end
            endcase
        end
    end
    
    // Output ready signal
    assign clear_ready = (current_state == IDLE) || (current_state == DONE);

endmodule