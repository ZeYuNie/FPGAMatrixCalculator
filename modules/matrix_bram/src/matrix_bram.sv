module matrix_bram #(
    parameter ROWS = 5,
    parameter COLS = 5,
    parameter ADDR_WIDTH = $clog2(ROWS*COLS),
    parameter DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    logic [DATA_WIDTH-1:0] mem [0:ROWS*COLS-1];

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[addr] <= din;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dout <= '0;
        end else begin
            dout <= mem[addr];
        end
    end

endmodule
