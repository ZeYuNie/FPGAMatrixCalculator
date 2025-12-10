`timescale 1ps / 1ps

module settings_ram (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         wr_en,
    input  logic [31:0]  set_max_row,
    input  logic [31:0]  set_max_col,
    input  logic [31:0]  data_min,
    input  logic [31:0]  data_max,
    input  logic [31:0]  set_countdown_time,

    output logic [31:0]  rd_max_row,
    output logic [31:0]  rd_max_col,
    output logic [31:0]  rd_data_min,
    output logic [31:0]  rd_data_max,
    output logic [31:0]  rd_countdown_time
);

    logic [31:0] reg_max_row;
    logic [31:0] reg_max_col;
    logic [31:0] reg_data_min;
    logic [31:0] reg_data_max;
    logic [31:0] reg_countdown_time;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_max_row  <= 32'd5;
            reg_max_col  <= 32'd5;
            reg_data_min <= 32'd1;
            reg_data_max <= 32'd9;
            reg_countdown_time <= 32'd10;
        end else if (wr_en) begin
            reg_max_row  <= set_max_row;
            reg_max_col  <= set_max_col;
            reg_data_min <= data_min;
            reg_data_max <= data_max;
            reg_countdown_time <= set_countdown_time;
        end
    end

    // 读取逻辑：直接输出寄存器值
    assign rd_max_row  = reg_max_row;
    assign rd_max_col  = reg_max_col;
    assign rd_data_min = reg_data_min;
    assign rd_data_max = reg_data_max;
    assign rd_countdown_time = reg_countdown_time;

endmodule