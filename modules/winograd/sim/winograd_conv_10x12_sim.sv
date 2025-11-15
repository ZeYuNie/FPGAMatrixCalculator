`timescale 1ns / 1ps

module winograd_conv_10x12_sim;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [15:0] image_in  [0:9][0:11];
    logic [15:0] kernel_in [0:2][0:2];
    logic [15:0] result_out [0:7][0:9];
    logic        done;
    
    winograd_conv_10x12 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .image_in(image_in),
        .kernel_in(kernel_in),
        .result_out(result_out),
        .done(done)
    );
    
    // 监控状态转换和处理进度
    always @(posedge clk) begin
        if (dut.state == dut.ST_LOAD) begin
            $display("=== Round %d: ST_LOAD ===", dut.round_idx);
            $display("Tile position: [%d][%d]", dut.tile_i, dut.tile_j);
            $display("TC Start: %b", dut.tc_start);
            
            $display("Kernel:");
            for (int i = 0; i < 3; i++) begin
                $write("  ");
                for (int j = 0; j < 3; j++) begin
                    $write("%4d ", dut.tc_kernel_in[i][j]);
                end
                $write("\n");
            end
            
            $display("Input Tile 6x6:");
            for (int i = 0; i < 6; i++) begin
                $write("  ");
                for (int j = 0; j < 6; j++) begin
                    $write("%4d ", dut.tc_tile_in[i][j]);
                end
                $write("\n");
            end
            $display("");
        end
        
        if (dut.state == dut.ST_WAIT) begin
            if (dut.tc_done) begin
                $display("=== Round %d: TC Done ===", dut.round_idx);
                $display("Output Result 4x4:");
                for (int i = 0; i < 4; i++) begin
                    $write("  ");
                    for (int j = 0; j < 4; j++) begin
                        $write("%6d ", dut.tc_result_out[i][j]);
                    end
                    $write("\n");
                end
                $display("");
            end
        end
        
        if (dut.state == dut.ST_WRITE) begin
            $display("=== Round %d: ST_WRITE ===", dut.round_idx);
            $display("Writing to result_tiles[%d][%d]", dut.tile_i, dut.tile_j);
            $display("");
        end
        
        if (dut.state == dut.ST_FINISH) begin
            $display("=== ST_FINISH: All tiles processed ===");
            $display("Final result_tiles (3x3 tiles of 4x4):");
            for (int ti = 0; ti < 3; ti++) begin
                for (int tj = 0; tj < 3; tj++) begin
                    $display("Tile [%d][%d]:", ti, tj);
                    for (int i = 0; i < 4; i++) begin
                        $write("  ");
                        for (int j = 0; j < 4; j++) begin
                            $write("%6d ", dut.result_tiles[ti][tj][i][j]);
                        end
                        $write("\n");
                    end
                end
            end
            $display("");
        end
    end
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 测试序列
    initial begin
        rst_n = 0;
        start = 0;
        
        // 初始化输入为全1
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                image_in[i][j] = 16'd1;
            end
        end
        
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 16'd1;
            end
        end
        
        #30 rst_n = 1;
        #50;
        
        $display("========================================");
        $display("=== Test 1: All ones (简单测试) ===");
        $display("========================================");
        display_input();
        
        @(posedge clk);
        #1 start = 1;
        @(posedge clk);
        #1 start = 0;
        
        wait(done == 1'b1);
        @(posedge clk);
        #1;
        
        display_result();
        
        #100;
        
        $display("========================================");
        $display("=== Test 2: Sequential values (顺序值测试) ===");
        $display("========================================");
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                image_in[i][j] = i * 12 + j;
            end
        end
        
        display_input();
        
        @(posedge clk);
        #1 start = 1;
        @(posedge clk);
        #1 start = 0;
        
        wait(done == 1'b1);
        @(posedge clk);
        #1;
        
        display_result();
        
        #100;
        
        $display("========================================");
        $display("=== Test 3: Custom pattern (自定义模式) ===");
        $display("========================================");
        // 创建一个简单的边缘检测卷积核
        kernel_in[0][0] = -1; kernel_in[0][1] = -1; kernel_in[0][2] = -1;
        kernel_in[1][0] = -1; kernel_in[1][1] =  8; kernel_in[1][2] = -1;
        kernel_in[2][0] = -1; kernel_in[2][1] = -1; kernel_in[2][2] = -1;
        
        // 创建一个有变化的图像
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                if (i < 5 && j < 6)
                    image_in[i][j] = 16'd10;
                else
                    image_in[i][j] = 16'd5;
            end
        end
        
        display_input();
        
        @(posedge clk);
        #1 start = 1;
        @(posedge clk);
        #1 start = 0;
        
        wait(done == 1'b1);
        @(posedge clk);
        #1;
        
        display_result();
        
        #100 $finish;
    end
    
    // 显示输入图像和卷积核
    task display_input;
        $display("Input Image 10x12:");
        for (int i = 0; i < 10; i++) begin
            $write("  ");
            for (int j = 0; j < 12; j++) begin
                $write("%6d ", $signed(image_in[i][j]));
            end
            $write("\n");
        end
        $display("Kernel 3x3:");
        for (int i = 0; i < 3; i++) begin
            $write("  ");
            for (int j = 0; j < 3; j++) begin
                $write("%6d ", $signed(kernel_in[i][j]));
            end
            $write("\n");
        end
        $display("");
    endtask
    
    // 显示输出结果
    task display_result;
        $display("Output Result 8x10:");
        for (int i = 0; i < 8; i++) begin
            $write("  ");
            for (int j = 0; j < 10; j++) begin
                $write("%6d ", $signed(result_out[i][j]));
            end
            $write("\n");
        end
        $display("");
    endtask

endmodule