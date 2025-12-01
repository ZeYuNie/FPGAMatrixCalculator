`timescale 1ns / 1ps

module bin_to_bcd (
    input  wire [15:0] bin_in,
    output reg  [3:0]  bcd_out [0:3]
);

    integer i;
    reg [15:0] temp;

    always @(*) begin
        temp = bin_in;
        bcd_out[3] = temp % 10;
        temp = temp / 10;
        bcd_out[2] = temp % 10;
        temp = temp / 10;
        bcd_out[1] = temp % 10;
        temp = temp / 10;
        bcd_out[0] = temp % 10;
    end

endmodule