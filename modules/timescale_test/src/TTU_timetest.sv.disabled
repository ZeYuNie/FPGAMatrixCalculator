`timescale 1ns / 1ps

module tile_transform_unit_time_sim (
    input logic clk,
    output logic placeholder
);
    logic rst_n = 1'b0;

    (* DONT_TOUCH = "TRUE" *) logic dut_start;
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_tile_in [0:5][0:5];
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_tile_out [0:5][0:5];
    (* DONT_TOUCH = "TRUE" *) logic dut_transform_done;

    tile_transform_unit u_tile_transform (
        .clk(clk),
        .rst_n(rst_n),
        .start(dut_start),
        .tile_in(dut_tile_in),
        .tile_out(dut_tile_out),
        .transform_done(dut_transform_done)
    );

    (* DONT_TOUCH = "TRUE" *) logic [7:0] reset_counter;
    always_ff @(posedge clk) begin
        if (reset_counter != 8'hFF) begin
            reset_counter <= reset_counter + 1;
            rst_n <= 1'b0;
        end else begin
            rst_n <= 1'b1;
        end
    end

    (* DONT_TOUCH = "TRUE" *) logic [3:0] start_counter;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_counter <= 4'd0;
            dut_start <= 1'b0;
        end else begin
            start_counter <= start_counter + 1;
            dut_start <= (start_counter == 4'd0);
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    dut_tile_in[i][j] <= 16'd0;
                end
            end
        end else begin
            dut_tile_in[0][0] <= dut_tile_in[0][0] + 1;
        end
    end

endmodule