module bram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 8192 + 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[addr] <= din;
        end
    end

    // Read
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dout <= '0;
        end else begin
            dout <= mem[addr];
        end
    end

endmodule
