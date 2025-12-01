`timescale 1ns / 1ps

module bin_to_bcd_tb;

    reg [15:0] bin_in;
    wire [3:0] bcd_out [0:3];

    bin_to_bcd uut (
        .bin_in(bin_in),
        .bcd_out(bcd_out)
    );

    initial begin
        $display("=== Binary to BCD Conversion Test Start ===");
        
        bin_in = 16'd0;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in, 
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        bin_in = 16'd1234;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in,
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        bin_in = 16'd9999;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in,
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        bin_in = 16'd5678;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in,
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        bin_in = 16'd42;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in,
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        bin_in = 16'd305;
        #10;
        $display("[%0t] Input: %d => BCD: %d%d%d%d", $time, bin_in,
                 bcd_out[0], bcd_out[1], bcd_out[2], bcd_out[3]);
        
        $display("=== Binary to BCD Conversion Test Complete ===");
        $finish;
    end

endmodule