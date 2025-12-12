`timescale 1ns / 1ps

module top_module_tb;

    // Parameters
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst_n;
    logic uart_rx;
    logic uart_tx;
    logic [7:0] sw;
    logic btn;
    logic [7:0] led;
    logic [7:0] seg;
    logic [3:0] an;

    // DUT Instantiation
    top_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .sw(sw),
        .btn(btn),
        .led(led),
        .seg(seg),
        .an(an)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // UART Helper Tasks
    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start Bit
            uart_rx = 0;
            #(8680); // 115200 baud -> 8.68us per bit. 
                     // Simulation time unit is 1ns. 8680ns.
            
            // Data Bits
            for (i = 0; i < 8; i++) begin
                uart_rx = data[i];
                #(8680);
            end
            
            // Stop Bit
            uart_rx = 1;
            #(8680);
        end
    endtask

    task send_string(input string str);
        integer i;
        begin
            for (i = 0; i < str.len(); i++) begin
                send_byte(str[i]);
                #(10000); // Inter-byte delay
            end
        end
    endtask
    
    // Button Helper
    task press_btn();
        begin
            btn = 0; // Active low press
            #(20000000 + 1000); // > 20ms debounce
            btn = 1; // Release
            #(1000000);
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        uart_rx = 1; // Idle high
        sw = 0;
        btn = 1; // Active low released
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 100);
        
        $display("Starting Top Module Test...");
        
        // -------------------------------------------------------
        // 1. Matrix Input Mode (SW[7]=1, Mode=1)
        // -------------------------------------------------------
        $display("Test 1: Matrix Input Mode");
        sw = 8'b10000000; // Input Mode
        #(CLK_PERIOD * 10);
        
        // Input Matrix A (2x2): [[1,2],[3,4]]
        // Format: "2 2 1 2 3 4"
        send_string("2 2 1 2 3 4\n");
        
        // Wait for processing
        #(1000000);
        
        // Confirm (Store)
        press_btn();
        
        // Wait for storage
        #(1000000);
        
        // -------------------------------------------------------
        // 2. Matrix Show Mode (SW[5]=1, Mode=3)
        // -------------------------------------------------------
        $display("Test 2: Matrix Show Mode");
        sw = 8'b00100000; // Show Mode
        #(CLK_PERIOD * 10);
        
        // Trigger Show
        press_btn();
        
        // Wait for UART TX (Visual check in waveform)
        #(5000000);
        
        // -------------------------------------------------------
        // 3. Calculate Mode (SW[4]=1, Mode=4) - Transpose
        // -------------------------------------------------------
        $display("Test 3: Calculate Mode - Transpose");
        sw = 8'b00010000; // Calc Mode
        // SW[2:0] = 000 (Transpose)
        #(CLK_PERIOD * 10);
        
        // Start Calculation Selection
        press_btn();
        
        // Input Dimensions: "2 2"
        send_string("2 2\n");
        #(1000000);
        press_btn(); // Confirm Dims
        
        // Select Matrix: "0" (The one we just input, ID 0)
        // Wait, input subsystem assigns IDs. First one is 0.
        send_string("0\n");
        #(1000000);
        press_btn(); // Confirm Matrix
        
        // Wait for execution
        #(2000000);
        
        $display("Test Done");
        $finish;
    end

endmodule
