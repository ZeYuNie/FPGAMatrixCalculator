`timescale 1ns / 1ps

module matrix_reader_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter ADDR_WIDTH = 14;
    
    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic [2:0] matrix_id;
    logic busy;
    logic done;
    logic [ADDR_WIDTH-1:0] bram_addr;
    logic [31:0] bram_data;
    logic [7:0] ascii_data;
    logic ascii_valid;
    logic ascii_ready;
    
    // BRAM Simulation
    logic [31:0] bram_mem [0:8191];
    
    // DUT Instance
    matrix_reader #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_id(matrix_id),
        .busy(busy),
        .done(done),
        .bram_addr(bram_addr),
        .bram_data(bram_data),
        .ascii_data(ascii_data),
        .ascii_valid(ascii_valid),
        .ascii_ready(ascii_ready)
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // BRAM Logic (Read Latency = 1)
    always_ff @(posedge clk) begin
        bram_data <= bram_mem[bram_addr];
    end
    
    // Monitor Logic
    initial begin
        $display("Time | Char | Hex");
        forever begin
            @(posedge clk);
            if (ascii_valid && ascii_ready) begin
                if (ascii_data == 8'h0A)
                    $display("%t | \\n   | %h", $time, ascii_data);
                else
                    $write("%c", ascii_data);
            end
        end
    end
    
    // Test Stimulus
    initial begin
        // Initialize BRAM
        // Matrix 0: 2x2, Name "TESTMAT0"
        // Addr 0: Rows=2, Cols=2
        bram_mem[0] = {8'd2, 8'd2, 16'd0};
        // Addr 1: "TEST"
        bram_mem[1] = "TEST";
        // Addr 2: "MAT0"
        bram_mem[2] = "MAT0";
        // Data: 1, 2, 3, 4
        bram_mem[3] = 1;
        bram_mem[4] = 2;
        bram_mem[5] = 3;
        bram_mem[6] = 4;
        
        // Matrix 1: 2x3, Name "MATRIXX "
        // Addr 1152: Rows=2, Cols=3
        bram_mem[1152] = {8'd2, 8'd3, 16'd0};
        bram_mem[1153] = "MATR";
        bram_mem[1154] = "IXX ";
        bram_mem[1155] = 10;
        bram_mem[1156] = 20;
        bram_mem[1157] = 30;
        bram_mem[1158] = 40;
        bram_mem[1159] = 50;
        bram_mem[1160] = 60;
        
        // Reset
        rst_n = 0;
        start = 0;
        matrix_id = 0;
        ascii_ready = 0;
        #20;
        rst_n = 1;
        #20;
        
        // Test 1: Read Matrix 0
        $display("\n--- Test 1: Read Matrix 0 ---");
        matrix_id = 0;
        start = 1;
        ascii_ready = 1; // Always ready
        #10;
        start = 0;
        
        wait(done);
        #20;
        
        // Test 2: Read Matrix 1 with Backpressure
        $display("\n\n--- Test 2: Read Matrix 1 with Backpressure ---");
        matrix_id = 1;
        start = 1;
        #10;
        start = 0;
        
        // Toggle ready signal
        repeat(200) begin
            ascii_ready <= ~ascii_ready;
            @(posedge clk);
        end
        ascii_ready = 1;
        
        wait(done);
        #20;
        
        $display("\nTest Complete");
        $finish;
    end

endmodule
