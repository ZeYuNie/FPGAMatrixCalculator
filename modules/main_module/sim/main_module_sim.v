//=============================================================================
// Testbench: main_module_sim
// Description: Simple testbench for main_module
//=============================================================================

`timescale 1ns/1ps

module main_module_sim;

// Clock and Reset
reg clk;
reg rst_n;

// GPIO Interface
reg [7:0] gpio_in;
wire [7:0] gpio_out;

// Status LEDs
wire led_ready;
wire led_busy;
wire led_error;

// DUT instantiation
main_module u_main_module (
    .clk(clk),
    .rst_n(rst_n),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .led_ready(led_ready),
    .led_busy(led_busy),
    .led_error(led_error)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// Test stimulus
initial begin
    // Initialize
    rst_n = 0;
    gpio_in = 8'h00;
    
    $display("Starting main_module testbench...");
    
    // Reset test
    #20;
    rst_n = 1;
    #10;
    
    // GPIO loopback tests
    gpio_in = 8'h55;
    #20;
    if (gpio_out != 8'h55) $display("ERROR: Expected 0x55, got 0x%02h", gpio_out);
    
    gpio_in = 8'hAA;
    #20;
    if (gpio_out != 8'hAA) $display("ERROR: Expected 0xAA, got 0x%02h", gpio_out);
    
    gpio_in = 8'hFF;
    #20;
    if (gpio_out != 8'hFF) $display("ERROR: Expected 0xFF, got 0x%02h", gpio_out);
    
    gpio_in = 8'h00;
    #20;
    if (gpio_out != 8'h00) $display("ERROR: Expected 0x00, got 0x%02h", gpio_out);
    
    $display("Test completed");
    #50;
    $finish;
end

// VCD dump
initial begin
    $dumpfile("main_module_sim.vcd");
    $dumpvars(0, main_module_sim);
end

endmodule