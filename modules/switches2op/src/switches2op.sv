`timescale 1ns / 1ps

module switches2op (
    input  logic       sw_mat_input,
    input  logic       sw_gen,
    input  logic       sw_show,
    input  logic       sw_calculate,
    output logic [2:0] op
);

always_comb begin
    case ({sw_mat_input, sw_gen, sw_show, sw_calculate})
        4'b0001: op = 3'd0; // Calculate
        4'b0010: op = 3'd1; // Show
        4'b0100: op = 3'd2; // Generate
        4'b1000: op = 3'd3; // Matrix Input
        default: op = 3'd4; // Invalid
    endcase
end

endmodule