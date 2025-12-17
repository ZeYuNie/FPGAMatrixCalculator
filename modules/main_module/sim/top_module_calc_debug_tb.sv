`timescale 1ns / 1ps

module top_module_calc_debug_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 100MHz clock (to match top_module's expectation of generating 50MHz internally)

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
    // 115200 baud -> 8680ns per bit
    localparam BIT_PERIOD = 8680;

    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start Bit (Low)
            uart_rx = 0;
            #(BIT_PERIOD);
            
            // Data Bits (LSB first)
            for (i = 0; i < 8; i++) begin
                uart_rx = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit (High)
            uart_rx = 1;
            #(BIT_PERIOD);
        end
    endtask

    task send_string(input string str);
        integer i;
        begin
            for (i = 0; i < str.len(); i++) begin
                send_byte(str[i]);
                #(BIT_PERIOD); // Small delay between bytes
            end
        end
    endtask
    
    // Button Helper (Active Low)
    task press_btn();
        begin
            $display("[%0t] Pressing Button...", $time);
            btn = 0;
            #(60000000); // 60ms hold for debounce (since clk is effectively 25MHz in sim, debounce needs 40ms)
            btn = 1;
            #(60000000); // Release delay (needs to be long enough for debounce to register release)
            $display("[%0t] Button Released", $time);
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
        
        $display("Starting Top Module Calc Debug Test...");

        // -------------------------------------------------------
        // 0. Backdoor Initialize BRAM with a 4x4 Matrix
        // -------------------------------------------------------
        // Matrix ID 0
        // Addr 0: Rows/Cols = 0x04040000
        dut.u_storage_mgr.bram_inst.mem[0] = 32'h04040000;
        // Addr 1: Name "MATA"
        dut.u_storage_mgr.bram_inst.mem[1] = 32'h4D415441;
        // Addr 2: Name "    "
        dut.u_storage_mgr.bram_inst.mem[2] = 32'h20202020;
        // Data (16 elements)
        for (int i = 0; i < 16; i++) begin
            dut.u_storage_mgr.bram_inst.mem[3+i] = i + 1;
        end
        
        $display("BRAM Initialized with 4x4 Matrix at ID 0");

        // Monitor internal signals
        $monitor("[%t] State=%d, ModeCalc=%b, BtnPulse=%b, Start=%b, NumCount=%d",
                 $time, dut.u_compute_sub.u_selector.state, dut.mode_is_calc, dut.btn_pressed_pulse, dut.u_compute_sub.start, dut.u_compute_sub.u_input_buffer.num_count);

        // -------------------------------------------------------
        // 1. Enter Calculate Mode (SW[4]=1)
        // -------------------------------------------------------
        sw = 8'b00010000; // SW4 = 1
        // SW[2:0] = 000 (Transpose)
        #(CLK_PERIOD * 100);
        
        $display("Switched to Calculate Mode");

        // -------------------------------------------------------
        // 2. Confirm Mode (Press S4)
        // -------------------------------------------------------
        press_btn();
        
        // Wait for state transition to GET_DIMS
        // Add timeout to avoid infinite wait
        fork
            begin
                wait(dut.u_compute_sub.u_selector.state == 1); // GET_DIMS
                $display("State: GET_DIMS reached");
            end
            begin
                #100000000; // 100ms timeout
                $display("Timeout waiting for GET_DIMS");
                $finish;
            end
        join_any
        disable fork;

        // -------------------------------------------------------
        // 3. Send "4 4\n" via UART (Simulate User Input)
        // -------------------------------------------------------
        $display("Sending '4 4\\n'...");
        send_string("4 4\n");
        
        #(2000000); // Wait for parsing

        // Check num_count
        $display("Current num_count: %d", dut.u_compute_sub.u_input_buffer.num_count);

        // Try to Confirm
        $display("Pressing Confirm...");
        press_btn();

        // Check if state changed
        if (dut.u_compute_sub.u_selector.state == 1) begin
            $display("State is still GET_DIMS (STUCK!)");
        end else begin
            $display("State moved to %d (Success!)", dut.u_compute_sub.u_selector.state);
        end

        // Wait for SCAN and DISPLAY
        #(5000000);
        
        // Check if we reached SELECT_A (State 10)
        if (dut.u_compute_sub.u_selector.state == 10) begin
             $display("Reached SELECT_A");
        end else begin
             $display("Did NOT reach SELECT_A. Current State: %d", dut.u_compute_sub.u_selector.state);
        end

        $finish;
    end

endmodule
