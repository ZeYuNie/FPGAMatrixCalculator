`timescale 1ns / 1ps

module main_module (
    input  wire       clk,
    input  wire       rst_n,
    
    // UART Interface
    input  wire       uart_rx,
    output wire       uart_tx,
    
    // User Interface
    input  wire [7:0] switches,
    input  wire       confirm_btn, // Button for confirmation/start
    
    // Status LEDs
    output wire       led_ready,
    output wire       led_busy,
    output wire       led_error,
    
    // 7-Segment Display
    output wire [7:0] seg,
    output wire [3:0] an
);

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    
    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    
    // UART Signals
    wire [7:0] rx_data;
    wire       rx_done; // Used as valid signal
    wire [7:0] tx_data;
    wire       tx_start; // Used as valid signal
    wire       tx_busy;
    wire       tx_ready;
    
    assign tx_ready = !tx_busy;
    
    // Debounced Button
    wire confirm_btn_debounced;
    
    //-------------------------------------------------------------------------
    // Module Instantiations
    //-------------------------------------------------------------------------
    
    // 1. UART RX
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );
    
    // 2. UART TX
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );
    
    // 3. Key Debounce
    key_debounce u_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(confirm_btn),
        .key_out(confirm_btn_debounced)
    );
    
    // 4. System Top
    system_top #(
        .BLOCK_SIZE(1152),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(14)
    ) u_system_top (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .confirm_btn(confirm_btn_debounced),
        .uart_rx_data(rx_data),
        .uart_rx_valid(rx_done),
        .uart_tx_data(tx_data),
        .uart_tx_valid(tx_start),
        .uart_tx_ready(tx_ready),
        .led_ready(led_ready),
        .led_busy(led_busy),
        .led_error(led_error),
        .seg(seg),
        .an(an)
    );

endmodule
