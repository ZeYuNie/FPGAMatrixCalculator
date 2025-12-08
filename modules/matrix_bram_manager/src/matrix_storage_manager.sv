module matrix_storage_manager #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14,
    parameter DEPTH = 8192 + 1024
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    input  logic                  write_request,
    output logic                  write_ready,
    input  logic [2:0]            matrix_id,
    input  logic [7:0]            actual_rows,
    input  logic [7:0]            actual_cols,
    input  logic [7:0]            matrix_name [0:7],
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  data_valid,
    output logic                  write_done,
    output logic                  writer_ready,
    
    input  logic                  clear_request,
    output logic                  clear_done,
    input  logic [2:0]            clear_matrix_id,
    
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] data_out
);

    logic                  bram_wr_en;
    logic [ADDR_WIDTH-1:0] bram_addr;
    logic [DATA_WIDTH-1:0] bram_din;
    logic [DATA_WIDTH-1:0] bram_dout;
    
    logic [ADDR_WIDTH-1:0] writer_bram_addr;
    logic [DATA_WIDTH-1:0] writer_bram_din;
    logic                  writer_bram_wr_en;
    
    logic [ADDR_WIDTH-1:0] clearer_bram_addr;
    logic [DATA_WIDTH-1:0] clearer_bram_din;
    logic                  clearer_bram_wr_en;
    logic                  clear_ready;

    bram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) bram_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(bram_wr_en),
        .addr(bram_addr),
        .din(bram_din),
        .dout(bram_dout)
    );

    matrix_writer #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) writer_inst (
        .clk(clk),
        .rst_n(rst_n),
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
        .bram_wr_en(writer_bram_wr_en),
        .bram_addr(writer_bram_addr),
        .bram_din(writer_bram_din)
    );
    
    matrix_clearer #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) clearer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear_request(clear_request),
        .clear_ready(clear_ready),
        .matrix_id(clear_matrix_id),
        .clear_done(clear_done),
        .bram_wr_en(clearer_bram_wr_en),
        .bram_addr(clearer_bram_addr),
        .bram_din(clearer_bram_din)
    );

    // BRAM arbiter: clear has higher priority than write
    always_comb begin
        if (clearer_bram_wr_en) begin
            // Clear operation has highest priority
            bram_wr_en = 1'b1;
            bram_addr = clearer_bram_addr;
            bram_din = clearer_bram_din;
        end else if (writer_bram_wr_en) begin
            // Write operation
            bram_wr_en = 1'b1;
            bram_addr = writer_bram_addr;
            bram_din = writer_bram_din;
        end else begin
            // Read operation (default)
            bram_wr_en = 1'b0;
            bram_addr = read_addr;
            bram_din = '0;
        end
    end

    assign data_out = bram_dout;

endmodule