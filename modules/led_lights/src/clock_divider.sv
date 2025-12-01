`timescale 1ns / 1ps

module clock_divider #(
    parameter DIV_VALUE = 100_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    output reg  tick
);

    reg [26:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 27'd0;
            tick <= 1'b0;
        end else if (enable) begin
            if (counter == DIV_VALUE - 1) begin
                counter <= 27'd0;
                tick <= 1'b1;
            end else begin
                counter <= counter + 27'd1;
                tick <= 1'b0;
            end
        end else begin
            counter <= 27'd0;
            tick <= 1'b0;
        end
    end

endmodule