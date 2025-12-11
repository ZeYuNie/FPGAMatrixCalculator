`timescale 1ns / 1ps

module main_module_tb;

    // Parameters
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 10; // 100MHz
    parameter BIT_PERIOD = 1000000000 / BAUD_RATE; // ns

    // Signals
    reg clk;
    reg rst_n;
    reg uart_rx;
    wire uart_tx;
    reg [7:0] switches;
    reg confirm_btn;
    wire led_ready;
    wire led_busy;
    wire led_error;
    wire [7:0] seg;
    wire [3:0] an;

    // DUT Instantiation
    main_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .switches(switches),
        .confirm_btn(confirm_btn),
        .led_ready(led_ready),
        .led_busy(led_busy),
        .led_error(led_error),
        .seg(seg),
        .an(an)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper Task: Send UART Byte (Bit-banged)
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // Start Bit
            uart_rx = 0;
            #(BIT_PERIOD);
            
            // Data Bits
            for (i = 0; i < 8; i++) begin
                uart_rx = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit
            uart_rx = 1;
            #(BIT_PERIOD);
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        uart_rx = 1; // Idle high
        switches = 0;
        confirm_btn = 0;
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        $display("Test 1: Check Reset State");
        if (led_ready !== 1) $display("Error: LED Ready should be 1 after reset");
        
        //---------------------------------------------------------------------
        // Test 2: Switch to Input Mode
        //---------------------------------------------------------------------
        $display("Test 2: Switch to Input Mode");
        switches = 8'b10000000; // SW[7] = Input Mode
        #(CLK_PERIOD * 10);
        
        // Press Confirm Button to Start
        confirm_btn = 1;
        #(CLK_PERIOD * 1000); // Debounce time is usually long, but simulation might be faster
        // Assuming debounce module needs some time.
        // Let's hold it for a while.
        confirm_btn = 0;
        #(CLK_PERIOD * 10);
        
        // Check status
        // It should be busy waiting for input or processing
        // Since we didn't send UART data, it might be idle or waiting.
        
        //---------------------------------------------------------------------
        // Test 3: Switch to Calc Mode (Transpose)
        //---------------------------------------------------------------------
        $display("Test 3: Switch to Calc Mode (Transpose)");
        switches = 8'b00010000; // SW[4] = Calc Mode, SW[2:0] = 000 (Transpose)
        #(CLK_PERIOD * 10);
        
        confirm_btn = 1;
        #(CLK_PERIOD * 1000);
        confirm_btn = 0;
        #(CLK_PERIOD * 10);
        
        // In Calc Mode, it should start the Selector.
        // Selector waits for UART input.
        
        $display("Testbench Completed");
        $finish;
    end

endmodule
