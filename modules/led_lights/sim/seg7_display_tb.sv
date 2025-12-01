`timescale 1ns / 1ps

module seg7_display_tb;

    reg clk;
    reg rst_n;
    reg valid;
    reg [3:0] bcd_data_0;
    reg [3:0] bcd_data_1;
    reg [3:0] bcd_data_2;
    reg [3:0] bcd_data_3;
    wire [7:0] seg;
    wire [3:0] an;

    seg7_display uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .bcd_data_0(bcd_data_0),
        .bcd_data_1(bcd_data_1),
        .bcd_data_2(bcd_data_2),
        .bcd_data_3(bcd_data_3),
        .seg(seg),
        .an(an)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== 7-Segment Display Test Start ===");
        
        rst_n = 0;
        valid = 0;
        bcd_data_0 = 4'd0;
        bcd_data_1 = 4'd0;
        bcd_data_2 = 4'd0;
        bcd_data_3 = 4'd0;
        #20;
        
        $display("[%0t] Reset released", $time);
        rst_n = 1;
        #20;
        
        $display("[%0t] Display 1234", $time);
        valid = 1;
        bcd_data_0 = 4'd1;
        bcd_data_1 = 4'd2;
        bcd_data_2 = 4'd3;
        bcd_data_3 = 4'd4;
        #1000;
        
        $display("[%0t] Display 9876", $time);
        bcd_data_0 = 4'd9;
        bcd_data_1 = 4'd8;
        bcd_data_2 = 4'd7;
        bcd_data_3 = 4'd6;
        #1000;
        
        $display("[%0t] Display disabled", $time);
        valid = 0;
        #500;
        
        $display("[%0t] Display 0000", $time);
        valid = 1;
        bcd_data_0 = 4'd0;
        bcd_data_1 = 4'd0;
        bcd_data_2 = 4'd0;
        bcd_data_3 = 4'd0;
        #1000;
        
        $display("=== 7-Segment Display Test Complete ===");
        $finish;
    end

    always @(an or seg) begin
        if (valid)
            $display("[%0t] AN=%b SEG=%b", $time, an, seg);
    end

endmodule