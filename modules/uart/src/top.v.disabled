`timescale 1ns / 1ps

module top(
    input  wire clk,
    input  wire [7:0] key,
    input  wire uart_rx,
    output wire uart_tx,
    output reg  [7:0] led,
    input       uart_tx_rst_n,
    input       uart_rx_rst_n,
    input       send_one,
    output      uart_tx_work,
    output      uart_rx_work
);

    wire [7:0] rx_data;
    wire rx_done;
    

assign uart_rx_work = uart_rx_rst_n;
    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_rx_inst (
        .clk(clk),
        .rst_n( uart_rx_rst_n  ),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    //reg [22:0] send_cnt;   // 50ms (100MHz * 0.05 = 5_000_000)
    // reg send_flag;
    /* 
    always @(posedge clk or negedge uart_tx_en_n) begin
        if(!uart_tx_en_n) begin
            send_cnt <= 0;
            send_flag <= 0;
        end else if (send_cnt < 23'd5_000_000) begin
            send_cnt <= send_cnt + 1;
            send_flag <= 0;
        end else if (!tx_busy) begin
            send_cnt <= 0;
            send_flag <= 1;
        end else begin
            send_flag <= 0;
        end
    end
    */
    
    reg send_one_d1, send_one_d2;
    always @(posedge clk or negedge uart_tx_rst_n) begin
         if(!uart_tx_rst_n) begin
            send_one_d1 <= 1'b0;
            send_one_d2 <= 1'b0;
         end
         else begin 
            send_one_d1 <= send_one;
            send_one_d2 <= send_one_d1;
         end
    end
    wire send_flag; 
    assign send_flag = ~send_one_d1 & send_one_d2;
    
    assign uart_tx_work = uart_tx_rst_n;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n( uart_tx_rst_n),
        .tx_start(send_flag),
        .tx_data(key),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );

    always @(posedge clk or negedge uart_rx_rst_n) begin
        if (!uart_rx_rst_n)
            led <= 8'b0;
        else if (rx_done)
            led <= rx_data;
    end

endmodule
