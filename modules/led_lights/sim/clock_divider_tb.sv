`timescale 1ns / 1ps

module clock_divider_tb;

    reg clk;
    reg rst_n;
    reg enable;
    wire tick;

    clock_divider #(.DIV_VALUE(10)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .tick(tick)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Clock Divider Test Start ===");
        
        rst_n = 0;
        enable = 0;
        #20;
        
        $display("[%0t] Reset released", $time);
        rst_n = 1;
        #20;
        
        $display("[%0t] Enable divider", $time);
        enable = 1;
        
        repeat(30) @(posedge clk);
        
        $display("[%0t] Disable divider", $time);
        enable = 0;
        #50;
        
        $display("[%0t] Re-enable divider", $time);
        enable = 1;
        
        repeat(30) @(posedge clk);
        
        $display("=== Clock Divider Test Complete ===");
        $finish;
    end

    always @(posedge tick) begin
        $display("[%0t] Tick pulse generated", $time);
    end

endmodule