`timescale 1ns / 1ps

module matrix_reader_all #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control Interface
    input  logic                  start,
    output logic                  busy,
    output logic                  done,
    
    // BRAM Read Interface
    output logic [ADDR_WIDTH-1:0] bram_addr,
    input  logic [31:0]           bram_data,
    
    // ASCII Output Interface
    output logic [7:0]            ascii_data,
    output logic                  ascii_valid,
    input  logic                  ascii_ready
);

    // Internal Signals
    logic [2:0]  current_id;
    logic        reader_start;
    logic        reader_busy;
    logic        reader_done;
    logic [ADDR_WIDTH-1:0] reader_bram_addr;
    logic [7:0]  reader_ascii_data;
    logic        reader_ascii_valid;
    logic        reader_ascii_ready;
    
    logic [ADDR_WIDTH-1:0] check_bram_addr;
    
    // State Machine
    typedef enum logic [3:0] {
        IDLE,
        READ_META,
        WAIT_META,
        CHECK_VALID,
        START_READER,
        WAIT_READER,
        SEND_SEP_1,
        SEND_SEP_2,
        NEXT_ID,
        DONE_STATE
    } state_t;
    
    state_t state;
    
    // Matrix Reader Instance
    matrix_reader #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_reader (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (reader_start),
        .matrix_id  (current_id),
        .busy       (reader_busy),
        .done       (reader_done),
        .bram_addr  (reader_bram_addr),
        .bram_data  (bram_data),
        .ascii_data (reader_ascii_data),
        .ascii_valid(reader_ascii_valid),
        .ascii_ready(reader_ascii_ready)
    );
    
    // State Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_id <= 0;
            reader_start <= 0;
            done <= 0;
        end else begin
            // Default
            reader_start <= 0;
            done <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_id <= 0;
                        state <= READ_META;
                    end
                end
                
                READ_META: state <= WAIT_META;
                
                WAIT_META: begin
                    // Check rows and cols
                    logic [7:0] r, c;
                    r = bram_data[31:24];
                    c = bram_data[23:16];
                    
                    if (r > 0 && c > 0) begin
                        state <= START_READER;
                    end else begin
                        state <= NEXT_ID;
                    end
                end
                
                START_READER: begin
                    reader_start <= 1;
                    state <= WAIT_READER;
                end
                
                WAIT_READER: begin
                    if (reader_done) begin
                        state <= SEND_SEP_1;
                    end
                end
                
                SEND_SEP_1: begin
                    if (ascii_ready) state <= SEND_SEP_2;
                end
                
                SEND_SEP_2: begin
                    if (ascii_ready) state <= NEXT_ID;
                end
                
                NEXT_ID: begin
                    if (current_id == 7) begin
                        state <= DONE_STATE;
                    end else begin
                        current_id <= current_id + 1;
                        state <= READ_META;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Output Logic
    always_comb begin
        busy = (state != IDLE);
        
        // BRAM Address Mux
        if (state == READ_META || state == WAIT_META) begin
            bram_addr = current_id * BLOCK_SIZE;
        end else begin
            bram_addr = reader_bram_addr;
        end
        
        // ASCII Output Mux
        if (state == SEND_SEP_1 || state == SEND_SEP_2) begin
            ascii_data = 8'h0A; // Newline
            ascii_valid = 1'b1;
            reader_ascii_ready = 1'b0;
        end else if (state == WAIT_READER || state == START_READER) begin
            ascii_data = reader_ascii_data;
            ascii_valid = reader_ascii_valid;
            reader_ascii_ready = ascii_ready;
        end else begin
            ascii_data = 0;
            ascii_valid = 0;
            reader_ascii_ready = 0;
        end
    end

endmodule
