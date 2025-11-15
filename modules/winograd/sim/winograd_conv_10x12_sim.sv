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
    
    always @(posedge clk) begin
        if (dut.state == dut.ST_LOAD) begin
            $display("=== Debug ST_LOAD Round %d ===", dut.round_idx);
            $display("Before extract_tile call - TC0 tile_in:");
            for (int i = 0; i < 6; i++) begin
                $write("  ");
                for (int j = 0; j < 6; j++) begin
                    $write("%4d ", dut.tc0_tile_in[i][j]);
                end
                $write("\n");
            end
        end
        
        if (dut.state == dut.ST_LOAD) begin
            $display("=== Debug TC0 Signals Round %d ===", dut.round_idx);
            $display("tc0_start: %b", dut.tc0_start);
            $display("tc0_kernel_in:");
            for (int i = 0; i < 3; i++) begin
                $write("  ");
                for (int j = 0; j < 3; j++) begin
                    $write("%4d ", dut.tc0_kernel_in[i][j]);
                end
                $write("\n");
            end
            $display("");
        end
        
        if (dut.state == dut.ST_WRITE) begin
            $display("=== Debug ST_WRITE Round %d ===", dut.round_idx);
            if (dut.TC0_VALID[dut.round_idx]) begin
                $display("TC0: Processing tile from image(%d,%d) -> output(%d,%d)",
                        dut.TC0_ROW[dut.round_idx], dut.TC0_COL[dut.round_idx],
                        dut.TC0_ROW[dut.round_idx], dut.TC0_COL[dut.round_idx]);
                
                $display("TC0 done signal: %b", dut.tc0_done);
                $display("TC0 Input Tile 6x6:");
                for (int i = 0; i < 6; i++) begin
                    $write("  ");
                    for (int j = 0; j < 6; j++) begin
                        $write("%4d ", dut.tc0_tile_in[i][j]);
                    end
                    $write("\n");
                end
                
                if (dut.round_idx == 2) begin
                    $display("TC0 Round 2 Extract Verification:");
                    $display("  TC0_ROW[2]=%d, TC0_COL[2]=%d", dut.TC0_ROW[2], dut.TC0_COL[2]);
                    for (int i = 0; i < 6; i++) begin
                        for (int j = 0; j < 6; j++) begin
                            int img_row = dut.TC0_ROW[2] + i;  // 4 + i
                            int img_col = dut.TC0_COL[2] + j;  // 4 + j
                            if (img_row < 10 && img_col < 12) begin
                                $display("    extract[%d][%d] = image[%d][%d] = %d expected vs tile[%d][%d] = %d actual",
                                        i, j, img_row, img_col, dut.image_reg[img_row][img_col], i, j, dut.tc0_tile_in[i][j]);
                            end else begin
                                $display("    extract[%d][%d] = PADDING (img_pos %d,%d) = 0 expected vs tile[%d][%d] = %d actual",
                                        i, j, img_row, img_col, i, j, dut.tc0_tile_in[i][j]);
                            end
                        end
                    end
                end
                
                $display("TC0 Output Result 4x4:");
                for (int i = 0; i < 4; i++) begin
                    $write("  ");
                    for (int j = 0; j < 4; j++) begin
                        $write("%6d ", dut.tc0_result_out[i][j]);
                    end
                    $write("\n");
                end
                
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        int out_row = dut.TC0_ROW[dut.round_idx] + i;
                        int out_col = dut.TC0_COL[dut.round_idx] + j;
                        if (out_row < 8 && out_col < 10) begin
                            $display("  TC0: Writing result_out[%d][%d] = %d",
                                    out_row, out_col, dut.tc0_result_out[i][j]);
                        end
                    end
                end
            end
            
            if (dut.TC1_VALID[dut.round_idx]) begin
                $display("TC1: Processing tile from image(%d,%d) -> output(%d,%d)",
                        dut.TC1_ROW[dut.round_idx], dut.TC1_COL[dut.round_idx],
                        dut.TC1_ROW[dut.round_idx], dut.TC1_COL[dut.round_idx]);
                        
                $display("TC1 Input Tile 6x6:");
                for (int i = 0; i < 6; i++) begin
                    $write("  ");
                    for (int j = 0; j < 6; j++) begin
                        $write("%4d ", dut.tc1_tile_in[i][j]);
                    end
                    $write("\n");
                end
                
                $display("TC1 Output Result 4x4:");
                for (int i = 0; i < 4; i++) begin
                    $write("  ");
                    for (int j = 0; j < 4; j++) begin
                        $write("%6d ", dut.tc1_result_out[i][j]);
                    end
                    $write("\n");
                end
            end
            $display("");
        end
    end
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        start = 0;
        
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
        
        $display("=== Test 1: All ones ===");
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
        
        $display("\n=== Test 2: Sequential values ===");
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
        
        #100 $finish;
    end
    
    task display_input;
        $display("Input Image 10x12:");
        for (int i = 0; i < 10; i++) begin
            $write("  ");
            for (int j = 0; j < 12; j++) begin
                $write("%6d ", image_in[i][j]);
            end
            $write("\n");
        end
        $display("Kernel 3x3:");
        for (int i = 0; i < 3; i++) begin
            $write("  ");
            for (int j = 0; j < 3; j++) begin
                $write("%6d ", kernel_in[i][j]);
            end
            $write("\n");
        end
        $display("");
    endtask
    
    task display_result;
        $display("Result 8x10:");
        for (int i = 0; i < 8; i++) begin
            $write("  ");
            for (int j = 0; j < 10; j++) begin
                $write("%6d ", result_out[i][j]);
            end
            $write("\n");
        end
    endtask

endmodule