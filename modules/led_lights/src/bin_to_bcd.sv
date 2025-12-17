`timescale 1ns / 1ps

module bin_to_bcd (
    input  wire [15:0] bin_in,
    output reg  [3:0]  bcd_out [0:3]
);

    // Double Dabble (Shift-Add-3) Algorithm
    integer i;
    reg [31:0] shift_reg; // 16-bit bin + 4*4-bit bcd = 32 bits
    
    always @(*) begin
        shift_reg = 0;
        shift_reg[15:0] = bin_in;
        
        for (i = 0; i < 16; i = i + 1) begin
            // Check if any BCD digit is >= 5
            if (shift_reg[19:16] >= 5) shift_reg[19:16] = shift_reg[19:16] + 3;
            if (shift_reg[23:20] >= 5) shift_reg[23:20] = shift_reg[23:20] + 3;
            if (shift_reg[27:24] >= 5) shift_reg[27:24] = shift_reg[27:24] + 3;
            if (shift_reg[31:28] >= 5) shift_reg[31:28] = shift_reg[31:28] + 3;
            
            // Shift left by 1
            shift_reg = shift_reg << 1;
        end
        
        // Assign outputs
        // Leading zero suppression logic
        if (shift_reg[31:28] != 0) begin
            bcd_out[3] = shift_reg[31:28];
            bcd_out[2] = shift_reg[27:24];
            bcd_out[1] = shift_reg[23:20];
            bcd_out[0] = shift_reg[19:16];
        end else if (shift_reg[27:24] != 0) begin
            bcd_out[3] = 4'd15; // Blank
            bcd_out[2] = shift_reg[27:24];
            bcd_out[1] = shift_reg[23:20];
            bcd_out[0] = shift_reg[19:16];
        end else if (shift_reg[23:20] != 0) begin
            bcd_out[3] = 4'd15;
            bcd_out[2] = 4'd15;
            bcd_out[1] = shift_reg[23:20];
            bcd_out[0] = shift_reg[19:16];
        end else begin
            bcd_out[3] = 4'd15;
            bcd_out[2] = 4'd15;
            bcd_out[1] = 4'd15;
            bcd_out[0] = shift_reg[19:16]; // Always show last digit (0)
        end
    end

endmodule
