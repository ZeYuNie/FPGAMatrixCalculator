`timescale 1ns / 1ps

module countdown_timer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [15:0] duration,
    output logic        timeout,
    output logic        led_error,
    output logic [7:0]  seg,
    output logic [3:0]  an
);

    logic stop;
    logic busy;

    // Instantiate the existing counting_down module
    counting_down u_counting_down (
        .clk     (clk),
        .rst_n   (rst_n),
        .time_in (duration),
        .start   (start),
        .stop    (stop),
        .seg     (seg),
        .an      (an)
    );

    // Timeout signal (pulse or level when done)
    assign timeout = stop;

    // Error LED control
    // LED is ON while the countdown is running
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            led_error <= 1'b0;
        end else begin
            if (start) begin
                busy <= 1'b1;
                led_error <= 1'b1;
            end else if (stop) begin
                busy <= 1'b0;
                led_error <= 1'b0;
            end
        end
    end

endmodule
