`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_T #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [2:0]               matrix_src_id,
    output logic                     busy,
    output matrix_op_status_e        status,

    output logic [ADDR_WIDTH-1:0]    read_addr,
    input  logic [DATA_WIDTH-1:0]    data_out,

    output logic                     write_request,
    input  logic                     write_ready,
    output logic [2:0]               matrix_id,
    output logic [7:0]               actual_rows,
    output logic [7:0]               actual_cols,
    output logic [7:0]               matrix_name [0:7],
    output logic [DATA_WIDTH-1:0]    data_in,
    output logic                     data_valid,
    input  logic                     writer_ready,
    input  logic                     write_done
);

    typedef enum logic [4:0] {
        STATE_IDLE,
        STATE_CHECK_ID,
        STATE_READ_META_ADDR,
        STATE_READ_META_WAIT,
        STATE_VALIDATE,
        STATE_WAIT_WRITE_READY,
        STATE_ASSERT_WRITE_REQ,
        STATE_WAIT_WRITER_ENABLE,
        STATE_PREPARE_SRC_ADDR,
        STATE_READ_SRC_WAIT,
        STATE_WAIT_WRITER_FOR_DATA,
        STATE_UPDATE_INDICES,
        STATE_WAIT_WRITE_DONE,
        STATE_DONE
    } state_t;

    state_t state, state_next;

    localparam logic [7:0] RESULT_NAME [0:7] = '{
        8'h54, // T
        8'h52, // R
        8'h41, // A
        8'h4e, // N
        8'h53, // S
        8'h50, // P
        8'h4f, // O
        8'h53  // S
    };

    logic [ADDR_WIDTH-1:0] base_addr;
    logic [ADDR_WIDTH-1:0] read_addr_reg;
    logic [ADDR_WIDTH-1:0] src_data_addr;

    logic [2:0] matrix_src_id_lat;

    matrix_shape_t shape_src;
    logic [15:0]   elem_count_src;
    logic [15:0]   total_elements;
    logic [15:0]   processed_elements;

    logic [15:0]   dest_row_idx;
    logic [15:0]   dest_col_idx;

    logic [15:0]   dest_row_count;
    logic [15:0]   dest_col_count;

    logic [DATA_WIDTH-1:0] src_word;

    matrix_op_status_e status_reg;

    logic accept_start;
    logic validation_pass;
    logic set_status;
    matrix_op_status_e status_value;

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_src (
        .matrix_id(matrix_src_id_lat),
        .base_addr(base_addr)
    );

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi++) begin : gen_name_const
            assign matrix_name[gi] = RESULT_NAME[gi];
        end
    endgenerate

    assign matrix_id    = 3'd0;
    assign read_addr    = read_addr_reg;
    assign data_in      = src_word;
    assign write_request= (state == STATE_ASSERT_WRITE_REQ);
    assign data_valid   = (state == STATE_WAIT_WRITER_FOR_DATA);
    assign busy         = (state != STATE_IDLE);
    assign status       = status_reg;

    assign elem_count_src  = shape_element_count(shape_src);
    assign total_elements  = elem_count_src;
    assign dest_row_count  = {8'd0, shape_src.cols};
    assign dest_col_count  = {8'd0, shape_src.rows};

    assign actual_rows = shape_src.cols;
    assign actual_cols = shape_src.rows;

    assign accept_start = (state == STATE_IDLE) && start;

    function automatic logic [ADDR_WIDTH-1:0] calc_src_addr(
        input matrix_shape_t shape,
        input logic [15:0] row_idx,
        input logic [15:0] col_idx
    );
        return indexed_data_addr(base_addr, shape, row_idx, col_idx);
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= STATE_IDLE;
            matrix_src_id_lat <= 3'd0;
            shape_src         <= MATRIX_SHAPE_ZERO;
            read_addr_reg     <= '0;
            processed_elements<= 16'd0;
            dest_row_idx      <= 16'd0;
            dest_col_idx      <= 16'd0;
            src_word          <= '0;
            status_reg        <= MATRIX_OP_STATUS_IDLE;
        end else begin
            state <= state_next;

            if (accept_start) begin
                matrix_src_id_lat <= matrix_src_id;
                shape_src         <= MATRIX_SHAPE_ZERO;
                processed_elements<= 16'd0;
                dest_row_idx      <= 16'd0;
                dest_col_idx      <= 16'd0;
                status_reg        <= MATRIX_OP_STATUS_BUSY;
            end

            if (validation_pass) begin
                processed_elements <= 16'd0;
                dest_row_idx       <= 16'd0;
                dest_col_idx       <= 16'd0;
            end

            case (state)
                STATE_READ_META_ADDR: begin
                    read_addr_reg <= base_addr;
                end
                STATE_PREPARE_SRC_ADDR: begin
                    read_addr_reg <= calc_src_addr(
                        shape_src,
                        dest_col_idx,
                        dest_row_idx
                    );
                end
                default: begin end
            endcase

            if (state == STATE_READ_META_WAIT) begin
                shape_src <= decode_shape_word(data_out);
            end

            if (state == STATE_READ_SRC_WAIT) begin
                src_word <= data_out;
            end

            if (state == STATE_WAIT_WRITER_FOR_DATA && writer_ready) begin
                processed_elements <= processed_elements + 16'd1;
            end

            if (state == STATE_UPDATE_INDICES) begin
                if (dest_col_idx + 16'd1 < dest_col_count) begin
                    dest_col_idx <= dest_col_idx + 16'd1;
                end else begin
                    dest_col_idx <= 16'd0;
                    dest_row_idx <= dest_row_idx + 16'd1;
                end
            end

            if (set_status) begin
                status_reg <= status_value;
            end
        end
    end

    always_comb begin
        state_next      = state;
        set_status      = 1'b0;
        status_value    = status_reg;
        validation_pass = 1'b0;

        unique case (state)
            STATE_IDLE: begin
                if (start) begin
                    state_next = STATE_CHECK_ID;
                end
            end

            STATE_CHECK_ID: begin
                if (!is_valid_operand_id(matrix_src_id_lat)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_ID;
                    state_next   = STATE_DONE;
                end else begin
                    state_next = STATE_READ_META_ADDR;
                end
            end

            STATE_READ_META_ADDR: state_next = STATE_READ_META_WAIT;
            STATE_READ_META_WAIT: state_next = STATE_VALIDATE;

            STATE_VALIDATE: begin
                if (elem_count_src == 16'd0 ||
                    shape_src.rows == 8'd0 || shape_src.cols == 8'd0) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_EMPTY;
                    state_next   = STATE_DONE;
                end else if (!is_data_capacity_ok(elem_count_src)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_FORMAT;
                    state_next   = STATE_DONE;
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_EMPTY;
                    state_next   = STATE_DONE;
                end else begin
                    validation_pass = 1'b1;
                    state_next      = STATE_WAIT_WRITE_READY;
                end
            end

            STATE_WAIT_WRITE_READY: begin
                if (write_ready) begin
                    state_next = STATE_ASSERT_WRITE_REQ;
                end
            end

            STATE_ASSERT_WRITE_REQ: begin
                state_next = STATE_WAIT_WRITER_ENABLE;
            end

            STATE_WAIT_WRITER_ENABLE: begin
                if (writer_ready) begin
                    state_next = STATE_PREPARE_SRC_ADDR;
                end
            end

            STATE_PREPARE_SRC_ADDR: state_next = STATE_READ_SRC_WAIT;
            STATE_READ_SRC_WAIT:    state_next = STATE_WAIT_WRITER_FOR_DATA;

            STATE_WAIT_WRITER_FOR_DATA: begin
                if (writer_ready) begin
                    state_next = STATE_UPDATE_INDICES;
                end
            end

            STATE_UPDATE_INDICES: begin
                if (processed_elements >= total_elements) begin
                    state_next = STATE_WAIT_WRITE_DONE;
                end else begin
                    if (dest_row_idx >= dest_row_count) begin
                        set_status   = 1'b1;
                        status_value = MATRIX_OP_STATUS_ERR_INTERNAL;
                        state_next   = STATE_DONE;
                    end else begin
                        state_next = STATE_PREPARE_SRC_ADDR;
                    end
                end
            end

            STATE_WAIT_WRITE_DONE: begin
                if (write_done) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_SUCCESS;
                    state_next   = STATE_DONE;
                end
            end

            STATE_DONE: begin
                state_next = STATE_IDLE;
            end

            default: begin
                set_status   = 1'b1;
                status_value = MATRIX_OP_STATUS_ERR_INTERNAL;
                state_next   = STATE_IDLE;
            end
        endcase
    end

endmodule