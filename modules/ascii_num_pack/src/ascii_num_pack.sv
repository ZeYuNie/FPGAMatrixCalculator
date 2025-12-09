`timescale 1ns / 1ps

// ASCII Number Packer Top Module
// Receives 32-bit integers or control flags and outputs an ASCII stream.
module ascii_num_pack (
    input  logic                clk,
    input  logic                rst_n,
    
    // Input Interface (Streaming)
    input  logic [31:0]         input_data,
    input  logic [1:0]          input_type, // 0: Number, 1: Space, 2: Newline
    input  logic                input_valid,
    output logic                input_ready,
    
    // Output Interface (ASCII Stream)
    output logic [7:0]          ascii_data,
    output logic                ascii_valid,
    input  logic                ascii_ready,
    
    // Status
    output logic                busy
);

    // Input Type Definitions
    localparam TYPE_NUMBER  = 2'd0;
    localparam TYPE_SPACE   = 2'd1;
    localparam TYPE_NEWLINE = 2'd2;
    localparam TYPE_CHAR    = 2'd3;
    
    // ASCII Constants
    localparam CHAR_SPACE   = 8'h20;
    localparam CHAR_NEWLINE = 8'h0A;

    // Internal Signals
    logic        converter_start;
    logic        converter_busy;
    logic        converter_done;
    logic [7:0]  converter_char;
    logic        converter_char_valid;
    logic        converter_char_ready;
    
    // State Machine
    typedef enum logic [1:0] {
        IDLE,
        PROCESS_NUMBER,
        PROCESS_CHAR
    } state_t;
    
    state_t state;
    logic [7:0] char_to_send;
    logic [31:0] latched_data;
    
    // Converter Instance
    int32_to_ascii u_converter (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (converter_start),
        .int32_in   (latched_data),
        .busy       (converter_busy),
        .done       (converter_done),
        .char_out   (converter_char),
        .char_valid (converter_char_valid),
        .char_ready (converter_char_ready)
    );
    
    // Main Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            converter_start <= 1'b0;
            char_to_send <= 8'h00;
        end else begin
            // Default
            converter_start <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (input_valid && input_ready) begin
                        case (input_type)
                            TYPE_NUMBER: begin
                                converter_start <= 1'b1;
                                latched_data <= input_data;
                                state <= PROCESS_NUMBER;
                            end
                            TYPE_SPACE: begin
                                char_to_send <= CHAR_SPACE;
                                state <= PROCESS_CHAR;
                            end
                            TYPE_NEWLINE: begin
                                char_to_send <= CHAR_NEWLINE;
                                state <= PROCESS_CHAR;
                            end
                            TYPE_CHAR: begin
                                char_to_send <= input_data[7:0];
                                state <= PROCESS_CHAR;
                            end
                            default: begin
                                // Ignore unknown types, stay IDLE
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                
                PROCESS_NUMBER: begin
                    if (converter_done) begin
                        state <= IDLE;
                    end
                end
                
                PROCESS_CHAR: begin
                    if (ascii_valid && ascii_ready) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Output Logic
    always_comb begin
        // Defaults
        input_ready = 1'b0;
        ascii_data = 8'h00;
        ascii_valid = 1'b0;
        converter_char_ready = 1'b0;
        busy = (state != IDLE);
        
        case (state)
            IDLE: begin
                input_ready = 1'b1; // Ready to accept new input
            end
            
            PROCESS_NUMBER: begin
                // Route converter output to main output
                ascii_data = converter_char;
                ascii_valid = converter_char_valid;
                converter_char_ready = ascii_ready;
            end
            
            PROCESS_CHAR: begin
                ascii_data = char_to_send;
                ascii_valid = 1'b1;
            end
        endcase
    end

endmodule
