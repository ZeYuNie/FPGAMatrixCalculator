`timescale 1ns / 1ps

module bram_sim;

    parameter DATA_WIDTH = 32;
    parameter DEPTH = 128;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;

    bram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        addr = 0;
        din = 0;

        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD);

        $display("=== Writing test data ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en = 1;
            addr = i;
            din = $random;
        end

        @(posedge clk);
        wr_en = 0;
        #(CLK_PERIOD);

        $display("=== Reading back data ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            addr = i;
            @(posedge clk);
            if (i < 10 || i >= DEPTH-10)  // 只显示前后10个地址
                $display("addr=%0d, dout=0x%h", i, dout);
        end

        @(posedge clk);
        wr_en = 1;
        addr = 0;
        din = 32'hDEADBEEF;
        @(posedge clk);
        wr_en = 0;
        addr = 0;
        @(posedge clk);
        @(posedge clk);
        $display("Overwrite test: addr=0, dout=0x%h (expected 0xDEADBEEF)", dout);

        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        $display("Reset test: dout=0x%h (expected 0x00000000)", dout);
        @(posedge clk);
        rst_n = 1;

        #(CLK_PERIOD*5);
        $finish;
    end

endmodule