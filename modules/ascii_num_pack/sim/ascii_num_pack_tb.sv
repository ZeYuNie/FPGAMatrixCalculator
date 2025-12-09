`timescale 1ns / 1ps

module ascii_num_pack_tb;

    // Parameters
    localparam CLK_PERIOD = 10; // 100MHz

    // Signals
    logic        clk;
    logic        rst_n;
    
    logic [31:0] input_data;
    logic [1:0]  input_type;
    logic        input_valid;
    logic        input_ready;
    
    logic [7:0]  ascii_data;
    logic        ascii_valid;
    logic        ascii_ready;
    logic        busy;
    
    // DUT Instantiation
    ascii_num_pack dut (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data),
        .input_type(input_type),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .ascii_data(ascii_data),
        .ascii_valid(ascii_valid),
        .ascii_ready(ascii_ready),
        .busy(busy)
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to send data
    task send_packet(input logic [31:0] data, input logic [1:0] type_in);
        // Wait for DUT to be ready
        while (!input_ready) @(posedge clk);
        
        // Drive inputs
        input_data <= data;
        input_type <= type_in;
        input_valid <= 1;
        
        @(posedge clk);
        // Deassert valid after 1 cycle (DUT captures on posedge)
        input_valid <= 0;
        
        // Wait for DUT to finish processing (ready goes high again)
        @(posedge clk); 
        while (!input_ready) @(posedge clk);
    endtask
    
    // Monitor
    initial begin
        forever @(posedge clk) begin
            if (ascii_valid && ascii_ready) begin
                $write("%c", ascii_data);
            end
        end
    end
    
    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        input_data = 0;
        input_type = 0;
        input_valid = 0;
        ascii_ready = 1; // Always ready initially
        
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        $display("Starting Test...");
        $display("Expected Output: 123 -456 0<newline>-2147483648<newline>789");
        
        // Test 1: Simple Number
        send_packet(123, 0); // Number 123
        send_packet(0, 1);   // Space
        
        // Test 2: Negative Number
        send_packet(-456, 0); // Number -456
        send_packet(0, 1);    // Space
        
        // Test 3: Zero
        send_packet(0, 0);    // Number 0
        send_packet(0, 2);    // Newline
        
        // Test 4: INT_MIN
        send_packet(32'h80000000, 0); // -2147483648
        send_packet(0, 2);            // Newline
        
        // Test 5: Backpressure
        $display("\nTesting Backpressure (sending 789)...");
        ascii_ready <= 0; // Non-blocking
        fork
            begin
                send_packet(789, 0);
            end
            begin
                // Wait a bit then release ready
                repeat(50) @(posedge clk);
                ascii_ready <= 1; // Non-blocking to avoid race condition with monitor
            end
        join
        
        #(CLK_PERIOD*100);
        $display("\nTest Complete");
        $finish;
    end

endmodule
