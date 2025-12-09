`timescale 1ns / 1ps

module matrix_rand_gen_handler_tb;

    // Parameters
    parameter CLK_PERIOD = 10;
    
    // Signals
    logic        clk;
    logic        rst_n;
    logic        start;
    logic        error;
    logic        busy;
    logic        done;
    
    logic [31:0] settings_max_row;
    logic [31:0] settings_max_col;
    logic [31:0] settings_data_min;
    logic [31:0] settings_data_max;
    
    logic [10:0] buf_rd_addr;
    logic [31:0] buf_rd_data;
    
    logic        write_request;
    logic        write_ready;
    logic [2:0]  matrix_id;
    logic [7:0]  actual_rows;
    logic [7:0]  actual_cols;
    logic [7:0]  matrix_name [0:7];
    logic [31:0] data_in;
    logic        data_valid;
    logic        write_done;
    logic        writer_ready;
    
    logic [13:0] storage_rd_addr;
    logic [31:0] storage_rd_data;
    
    // Mock Memories
    logic [31:0] buffer_ram [0:2047];
    logic [31:0] storage_ram [0:8191];
    
    // DUT Instantiation
    matrix_rand_gen_handler dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .error(error),
        .busy(busy),
        .done(done),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(matrix_id),
        .actual_rows(actual_rows),
        .actual_cols(actual_cols),
        .matrix_name(matrix_name),
        .data_in(data_in),
        .data_valid(data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .storage_rd_addr(storage_rd_addr),
        .storage_rd_data(storage_rd_data)
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Mock Buffer RAM Read
    always_ff @(posedge clk) begin
        buf_rd_data <= buffer_ram[buf_rd_addr];
    end
    
    // Mock Storage RAM Read
    always_ff @(posedge clk) begin
        storage_rd_data <= storage_ram[storage_rd_addr];
    end
    
    // Debug Monitor
    always @(dut.state) begin
        $display("Time: %t, State: %d", $time, dut.state);
    end
    
    // Mock Writer Logic
    task automatic mock_writer_response();
        $display("Time: %t, Waiting for write_request", $time);
        // Wait for write request
        wait(write_request);
        $display("Time: %t, Got write_request", $time);
        @(posedge clk);
        write_ready = 0; // Acknowledge request
        writer_ready = 1; // Ready to receive data
        
        // Receive data
        // Wait until we are in GENERATE_STREAM to start receiving
        wait(dut.state == dut.GENERATE_STREAM);
        
        while (dut.state == dut.GENERATE_STREAM) begin
            @(posedge clk);
            if (data_valid) begin
                $display("Time: %t, Received Data: %d", $time, $signed(data_in));
            end
        end
        
        $display("Time: %t, Finished receiving data", $time);
        writer_ready = 0;
        write_done = 1;
        @(posedge clk);
        write_done = 0;
        write_ready = 1; // Ready for next request
    endtask
    
    // Test Sequence
    initial begin
        // Initialize Signals
        rst_n = 0;
        start = 0;
        settings_max_row = 32;
        settings_max_col = 32;
        settings_data_min = -100;
        settings_data_max = 100;
        write_ready = 1;
        write_done = 0;
        writer_ready = 0;
        
        // Initialize Memories
        for (int i = 0; i < 2048; i++) buffer_ram[i] = 0;
        for (int i = 0; i < 8192; i++) storage_ram[i] = 0; // All slots empty
        
        // Reset
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // Test Case 1: Generate 2 matrices of 2x3
        $display("Test Case 1: Generate 2 matrices of 2x3");
        buffer_ram[0] = 2; // m
        buffer_ram[1] = 3; // n
        buffer_ram[2] = 2; // count
        
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Handle first matrix write
        mock_writer_response();
        
        // Handle second matrix write
        mock_writer_response();
        
        wait(done);
        $display("Test Case 1 Completed");
        
        #(CLK_PERIOD*5);
        
        // Test Case 2: Error Case (Count > 2)
        $display("Test Case 2: Error Case (Count > 2)");
        rst_n = 0;
        #(CLK_PERIOD);
        rst_n = 1;
        
        buffer_ram[0] = 2;
        buffer_ram[1] = 3;
        buffer_ram[2] = 3; // Invalid count
        
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(error);
        $display("Test Case 2 Completed: Error detected as expected");
        
        #(CLK_PERIOD*5);
        
        // Test Case 3: Error Case (Dimensions too large)
        $display("Test Case 3: Error Case (Dimensions too large)");
        rst_n = 0;
        #(CLK_PERIOD);
        rst_n = 1;
        
        buffer_ram[0] = 33; // Invalid m
        buffer_ram[1] = 3;
        buffer_ram[2] = 1;
        
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(error);
        $display("Test Case 3 Completed: Error detected as expected");
        
        $finish;
    end

endmodule
