`timescale 1ns / 1ps

module input_subsystem_watchdog_tb;

    // Parameters
    localparam BLOCK_SIZE = 1152;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 14;
    localparam CLK_PERIOD = 20; // 50MHz

    // Signals
    logic clk;
    logic rst_n;
    logic mode_is_input;
    logic mode_is_gen;
    logic mode_is_settings;
    logic start;
    logic busy;
    logic done;
    logic error;
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    
    // Settings (Inputs)
    logic [31:0] settings_max_row = 32'd10;
    logic [31:0] settings_max_col = 32'd10;
    logic [31:0] settings_data_min = 32'd0;
    logic [31:0] settings_data_max = 32'd100;
    logic [31:0] settings_countdown = 32'd5000;

    // Storage Interface (Mocked)
    logic write_request;
    logic write_ready = 1'b1;
    logic [2:0] matrix_id;
    logic [7:0] actual_rows;
    logic [7:0] actual_cols;
    logic [7:0] matrix_name [0:7];
    logic [31:0] data_in;
    logic data_valid;
    logic write_done = 1'b0;
    logic writer_ready = 1'b1;
    logic [ADDR_WIDTH-1:0] storage_rd_addr;
    logic [DATA_WIDTH-1:0] storage_rd_data = 32'd0;

    // Instantiate DUT
    input_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_is_input(mode_is_input),
        .mode_is_gen(mode_is_gen),
        .mode_is_settings(mode_is_settings),
        .start(start),
        .busy(busy),
        .done(done),
        .error(error),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .settings_countdown(settings_countdown),
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

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        mode_is_input = 0;
        mode_is_gen = 0;
        mode_is_settings = 0;
        start = 0;
        uart_rx_data = 0;
        uart_rx_valid = 0;

        // Reset
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);

        $display("Test 1: Normal Generation Mode");
        mode_is_gen = 1;
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for busy
        wait(busy);
        $display("System Busy (Normal)");
        
        // Simulate completion (mock write_done)
        #(CLK_PERIOD*100);
        write_done = 1;
        #(CLK_PERIOD);
        write_done = 0;
        
        wait(done);
        $display("System Done (Normal)");
        #(CLK_PERIOD*20);
        
        // ---------------------------------------------------------
        
        $display("Test 2: Watchdog Trigger (Simulated Stuck)");
        mode_is_gen = 1;
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        wait(busy);
        $display("System Busy (Stuck)");
        
        // Do NOT assert write_done. Let it hang.
        // Wait for watchdog timeout (0.5s = 25,000,000 cycles)
        // In simulation, we can force the timer to speed up
        // NOTE: Must release force to allow countdown!
        force dut.watchdog_timer = 25'd10;
        #(CLK_PERIOD);
        release dut.watchdog_timer;
        
        // Wait for reset pulse
        wait(dut.force_reset_pulse);
        $display("Watchdog Triggered! Force Reset Pulse Detected.");
        
        // Check if busy goes low
        wait(!busy);
        $display("System Busy Cleared by Watchdog.");
        
        #(CLK_PERIOD*20);
        
        // ---------------------------------------------------------
        
        $display("Test 3: ASCII Validator Stuck (Simulated)");
        mode_is_input = 1;
        mode_is_gen = 0;
        
        // Force internal signals to simulate stuck state
        // validator_done = 1, all_done = 0 -> processing = 1 -> busy = 1
        force dut.u_input_buffer.validator_done = 1'b1;
        force dut.u_input_buffer.all_done = 1'b0;
        
        #(CLK_PERIOD*10);
        if (busy) $display("System Busy (Forced ASCII Stuck)");
        else $error("System should be busy!");
        
        // Speed up watchdog
        force dut.watchdog_timer = 25'd10;
        #(CLK_PERIOD);
        release dut.watchdog_timer;
        
        wait(dut.force_reset_pulse);
        $display("Watchdog Triggered again.");
        
        // Now, check if sub_rst_n clears the stuck state
        // Note: Since we FORCED the signals, they won't clear unless we release them.
        // But in real hardware, sub_rst_n would clear the registers driving these signals.
        // So we should release them when reset occurs and see if they stay low (simulating reset behavior).
        
        wait(dut.sub_rst_n == 0);
        $display("Sub-module Reset Asserted.");
        
        release dut.u_input_buffer.validator_done;
        release dut.u_input_buffer.all_done;
        
        // After reset, validator_done should be 0 (because of rst_n logic in validator)
        // We need to wait a bit for the reset to propagate if it was synchronous, 
        // but here it's asynchronous or synchronous reset.
        
        #(CLK_PERIOD*10);
        
        if (!busy) $display("System Recovered from ASCII Stuck.");
        else $error("System failed to recover!");
        
        $finish;
    end

endmodule
