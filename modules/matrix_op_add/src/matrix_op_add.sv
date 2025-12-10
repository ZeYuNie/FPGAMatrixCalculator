`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_add #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [2:0]               matrix_a_id,
    input  logic [2:0]               matrix_b_id,
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
        STATE_CHECK_IDS,
        STATE_READ_A_META_ADDR,
        STATE_READ_A_META_DELAY,
        STATE_READ_A_META_WAIT,
        STATE_READ_B_META_ADDR,
        STATE_READ_B_META_DELAY,
        STATE_READ_B_META_WAIT,
        STATE_VALIDATE,
        STATE_WAIT_WRITE_READY,
        STATE_ASSERT_WRITE_REQ,
        STATE_WAIT_WRITER_ENABLE,
        STATE_PREPARE_A_ADDR,
        STATE_WAIT_A_DATA_DELAY,
        STATE_WAIT_A_DATA,
        STATE_PREPARE_B_ADDR,
        STATE_WAIT_B_DATA_DELAY,
        STATE_WAIT_B_DATA,
        STATE_WRITE_DATA,
        STATE_CHECK_NEXT,
        STATE_WAIT_WRITE_DONE,
        STATE_DONE
    } state_t;

    state_t state, state_next;

    localparam logic [ADDR_WIDTH-1:0] META_OFFSET = ADDR_WIDTH'(MATRIX_METADATA_WORDS);

    logic [ADDR_WIDTH-1:0] read_addr_reg;
    logic [ADDR_WIDTH-1:0] matrix_a_base, matrix_b_base;
    logic [ADDR_WIDTH-1:0] matrix_a_data_addr, matrix_b_data_addr;
    logic [ADDR_WIDTH-1:0] element_index_addr;

    logic [2:0] matrix_a_id_lat, matrix_b_id_lat;

    matrix_shape_t         shape_a, shape_b;
    logic [15:0]           total_elements;
    logic [15:0]           element_index;
    logic [DATA_WIDTH-1:0] operand_a_word, operand_b_word;
    logic [DATA_WIDTH-1:0] sum_word;

    matrix_op_status_e status_reg;

    logic accept_start;
    logic validation_pass;
    logic set_status;
    matrix_op_status_e status_value;

    logic [15:0] elem_count_a;
    logic [15:0] elem_count_b;

    localparam logic [7:0] RESULT_NAME [0:7] = '{
        8'h41, // A
        8'h44, // D
        8'h44, // D
        8'h52, // R
        8'h45, // E
        8'h53, // S
        8'h00,
        8'h00
    };

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_a (
        .matrix_id(matrix_a_id_lat),
        .base_addr(matrix_a_base)
    );

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_b (
        .matrix_id(matrix_b_id_lat),
        .base_addr(matrix_b_base)
    );

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi++) begin : gen_name_const
            assign matrix_name[gi] = RESULT_NAME[gi];
        end
    endgenerate

    assign matrix_id      = 3'd0;
    assign actual_rows    = shape_a.rows;
    assign actual_cols    = shape_a.cols;
    assign read_addr      = read_addr_reg;
    assign write_request  = (state == STATE_ASSERT_WRITE_REQ);
    assign data_valid     = (state == STATE_WRITE_DATA);
    assign busy           = (state != STATE_IDLE);
    assign status         = status_reg;

    assign elem_count_a   = shape_element_count(shape_a);
    assign elem_count_b   = shape_element_count(shape_b);
    assign element_index_addr = element_index[ADDR_WIDTH-1:0];

    assign matrix_a_data_addr = matrix_a_base + META_OFFSET + element_index_addr;
    assign matrix_b_data_addr = matrix_b_base + META_OFFSET + element_index_addr;

    assign sum_word = operand_a_word + operand_b_word;
    assign data_in  = sum_word;

    assign accept_start = (state == STATE_IDLE) && start;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= STATE_IDLE;
            read_addr_reg    <= '0;
            matrix_a_id_lat  <= 3'd0;
            matrix_b_id_lat  <= 3'd0;
            shape_a          <= MATRIX_SHAPE_ZERO;
            shape_b          <= MATRIX_SHAPE_ZERO;
            operand_a_word   <= '0;
            operand_b_word   <= '0;
            total_elements   <= 16'd0;
            element_index    <= 16'd0;
            status_reg       <= MATRIX_OP_STATUS_IDLE;
        end else begin
            state <= state_next;

            if (accept_start) begin
                matrix_a_id_lat <= matrix_a_id;
                matrix_b_id_lat <= matrix_b_id;
                shape_a         <= MATRIX_SHAPE_ZERO;
                shape_b         <= MATRIX_SHAPE_ZERO;
                operand_a_word  <= '0;
                operand_b_word  <= '0;
                total_elements  <= 16'd0;
                element_index   <= 16'd0;
            end

            if (validation_pass) begin
                total_elements <= elem_count_a;
                element_index  <= 16'd0;
            end

            case (state)
                STATE_READ_A_META_ADDR: read_addr_reg <= matrix_a_base;
                STATE_READ_B_META_ADDR: read_addr_reg <= matrix_b_base;
                STATE_PREPARE_A_ADDR:   read_addr_reg <= matrix_a_data_addr;
                STATE_PREPARE_B_ADDR:   read_addr_reg <= matrix_b_data_addr;
                default: begin end
            endcase

            if (state == STATE_READ_A_META_WAIT) begin
                shape_a <= decode_shape_word(data_out);
            end

            if (state == STATE_READ_B_META_WAIT) begin
                shape_b <= decode_shape_word(data_out);
            end

            if (state == STATE_WAIT_A_DATA) begin
                operand_a_word <= data_out;
            end

            if (state == STATE_WAIT_B_DATA) begin
                operand_b_word <= data_out;
            end

            if (state == STATE_WRITE_DATA && writer_ready) begin
                element_index <= element_index + 16'd1;
            end

            if (accept_start) begin
                status_reg <= MATRIX_OP_STATUS_BUSY;
            end else if (set_status) begin
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
                    state_next = STATE_CHECK_IDS;
                end
            end

            STATE_CHECK_IDS: begin
                if (!is_valid_operand_id(matrix_a_id_lat) || !is_valid_operand_id(matrix_b_id_lat)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_ID;
                    state_next   = STATE_DONE;
                end else begin
                    state_next = STATE_READ_A_META_ADDR;
                end
            end

            STATE_READ_A_META_ADDR: state_next = STATE_READ_A_META_DELAY;
            STATE_READ_A_META_DELAY:state_next = STATE_READ_A_META_WAIT;
            STATE_READ_A_META_WAIT: state_next = STATE_READ_B_META_ADDR;
            STATE_READ_B_META_ADDR: state_next = STATE_READ_B_META_DELAY;
            STATE_READ_B_META_DELAY:state_next = STATE_READ_B_META_WAIT;
            STATE_READ_B_META_WAIT: state_next = STATE_VALIDATE;

            STATE_VALIDATE: begin
                if (elem_count_a == 16'd0 || elem_count_b == 16'd0 ||
                    shape_a.rows == 8'd0   || shape_a.cols == 8'd0 ||
                    shape_b.rows == 8'd0   || shape_b.cols == 8'd0) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_EMPTY;
                    state_next   = STATE_DONE;
                end else if (!is_data_capacity_ok(elem_count_a) || !is_data_capacity_ok(elem_count_b)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_FORMAT;
                    state_next   = STATE_DONE;
                end else if ((shape_a.rows != shape_b.rows) || (shape_a.cols != shape_b.cols)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_DIM;
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
                    state_next = STATE_PREPARE_A_ADDR;
                end
            end

            STATE_PREPARE_A_ADDR: state_next = STATE_WAIT_A_DATA_DELAY;
            STATE_WAIT_A_DATA_DELAY: state_next = STATE_WAIT_A_DATA;
            STATE_WAIT_A_DATA:    state_next = STATE_PREPARE_B_ADDR;
            STATE_PREPARE_B_ADDR: state_next = STATE_WAIT_B_DATA_DELAY;
            STATE_WAIT_B_DATA_DELAY: state_next = STATE_WAIT_B_DATA;
            STATE_WAIT_B_DATA:    state_next = STATE_WRITE_DATA;

            STATE_WRITE_DATA: begin
                if (writer_ready) begin
                    state_next = STATE_CHECK_NEXT;
                end
            end

            STATE_CHECK_NEXT: begin
                if (element_index >= total_elements) begin
                    state_next = STATE_WAIT_WRITE_DONE;
                end else begin
                    state_next = STATE_PREPARE_A_ADDR;
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
                state_next   = STATE_IDLE;
                set_status   = 1'b1;
                status_value = MATRIX_OP_STATUS_ERR_INTERNAL;
            end
        endcase
    end

endmodule