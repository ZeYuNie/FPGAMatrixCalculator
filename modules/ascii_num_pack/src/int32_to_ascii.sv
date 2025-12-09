`timescale 1ns / 1ps

// Integer to ASCII Converter
// Converts a 32-bit signed integer to a stream of ASCII characters.
// Handles negative numbers and variable length.
module int32_to_ascii (
    input  logic                clk,
    input  logic                rst_n,
    
    // Control Interface
    input  logic                start,
    input  logic signed [31:0]  int32_in,
    output logic                busy,
    output logic                done,
    
    // Output Stream Interface
    output logic [7:0]          char_out,
    output logic                char_valid,
    input  logic                char_ready
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        CHECK_SIGN,
        CONVERT,
        OUTPUT_SIGN,
        OUTPUT_DIGITS,
        FINISH
    } state_t;

    state_t state;

    // Internal registers
    logic [31:0] abs_value;
    logic        is_negative;
    logic [7:0]  digit_stack [0:11]; // Max 10 digits + sign (handled separately) -> actually just digits
    logic [3:0]  stack_ptr;          // Pointer to top of stack
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            abs_value <= 0;
            is_negative <= 0;
            stack_ptr <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        state <= CHECK_SIGN;
                        // Capture input
                        if (int32_in == 32'h80000000) begin
                            is_negative <= 1'b1;
                            abs_value <= 32'h80000000; 
                        end else if (int32_in < 0) begin
                            is_negative <= 1'b1;
                            abs_value <= -int32_in;
                        end else begin
                            is_negative <= 1'b0;
                            abs_value <= int32_in;
                        end
                    end
                end
                
                CHECK_SIGN: begin
                    stack_ptr <= 0;
                    state <= CONVERT;
                end
                
                CONVERT: begin
                    // Simple iterative division by 10
                    // We extract LSB first.
                    
                    digit_stack[stack_ptr] <= (abs_value % 10) + 8'd48; // Convert to ASCII
                    stack_ptr <= stack_ptr + 1;
                    
                    if (abs_value < 10) begin
                        // Done converting
                        if (is_negative) begin
                            state <= OUTPUT_SIGN;
                        end else begin
                            state <= OUTPUT_DIGITS;
                        end
                    end else begin
                        abs_value <= abs_value / 10;
                        state <= CONVERT;
                    end
                end
                
                OUTPUT_SIGN: begin
                    if (char_ready) begin
                        state <= OUTPUT_DIGITS;
                    end
                end
                
                OUTPUT_DIGITS: begin
                    if (stack_ptr > 0) begin
                        if (char_ready) begin
                            stack_ptr <= stack_ptr - 1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Output Logic (Combinational)
    always_comb begin
        char_out = 8'h00;
        char_valid = 1'b0;
        
        case (state)
            OUTPUT_SIGN: begin
                char_out = "-";
                char_valid = 1'b1;
            end
            
            OUTPUT_DIGITS: begin
                if (stack_ptr > 0) begin
                    char_out = digit_stack[stack_ptr - 1];
                    char_valid = 1'b1;
                end
            end
            
            default: begin
                char_out = 8'h00;
                char_valid = 1'b0;
            end
        endcase
    end

endmodule
