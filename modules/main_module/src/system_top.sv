`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module system_top #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Physical Inputs
    input  logic [7:0]            switches,
    input  logic                  confirm_btn,
    
    // UART Interface
    input  logic [7:0]            uart_rx_data,
    input  logic                  uart_rx_valid,
    output logic [7:0]            uart_tx_data,
    output logic                  uart_tx_valid,
    input  logic                  uart_tx_ready,
    
    // Status Outputs
    output logic                  led_ready,
    output logic                  led_busy,
    output logic                  led_error,
    output logic [7:0]            seg,
    output logic [3:0]            an
);

    //-------------------------------------------------------------------------
    // Mode Decoding
    //-------------------------------------------------------------------------
    
    logic [2:0] current_op;
    // 1: Input, 2: Gen, 3: Show, 4: Calc, 5: Settings
    
    switches2op u_switches2op (
        .sw_mat_input(switches[7]),
        .sw_gen(switches[6]),
        .sw_show(switches[5]),
        .sw_calculate(switches[4]),
        .sw_settings(switches[3]),
        .op(current_op)
    );
    
    op_mode_t calc_op_mode;
    calc_type_t calc_type;
    
    op_mode_controller u_op_mode_ctrl (
        .switches(switches),
        .op_mode(calc_op_mode),
        .calc_type(calc_type)
    );
    
    // Mode Flags
    logic mode_is_input, mode_is_gen, mode_is_show, mode_is_calc, mode_is_settings;
    assign mode_is_input    = (current_op == 3'd1);
    assign mode_is_gen      = (current_op == 3'd2);
    assign mode_is_show     = (current_op == 3'd3);
    assign mode_is_calc     = (current_op == 3'd4);
    assign mode_is_settings = (current_op == 3'd5);
    
    // Start Signal Generation (Pulse on button press)
    // Assuming confirm_btn is already debounced or we need to debounce it?
    // The top level usually handles debouncing. Let's assume confirm_btn is a clean pulse or level.
    // If it's a level, we need edge detection.
    logic confirm_btn_d, confirm_btn_pulse;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) confirm_btn_d <= 0;
        else confirm_btn_d <= confirm_btn;
    end
    assign confirm_btn_pulse = confirm_btn && !confirm_btn_d;
    
    logic start_pulse;
    assign start_pulse = confirm_btn_pulse;

    //-------------------------------------------------------------------------
    // Shared Signals
    //-------------------------------------------------------------------------
    
    // Settings
    logic [31:0] settings_max_row;
    logic [31:0] settings_max_col;
    logic [31:0] settings_data_min;
    logic [31:0] settings_data_max;
    logic [31:0] settings_countdown;
    
    // Storage Manager Interface
    logic                  write_request;
    logic                  write_ready;
    logic [2:0]            write_matrix_id;
    logic [7:0]            write_rows;
    logic [7:0]            write_cols;
    logic [7:0]            write_name [0:7];
    logic [DATA_WIDTH-1:0] write_data;
    logic                  write_data_valid;
    logic                  write_done;
    logic                  writer_ready;
    
    logic [ADDR_WIDTH-1:0] bram_rd_addr;
    logic [DATA_WIDTH-1:0] bram_rd_data;
    
    //-------------------------------------------------------------------------
    // Subsystem Instantiations
    //-------------------------------------------------------------------------
    
    // 1. Input Subsystem
    logic input_busy, input_done, input_error;
    logic input_wr_req;
    logic [2:0] input_mat_id;
    logic [7:0] input_rows, input_cols;
    logic [7:0] input_name[0:7];
    logic [DATA_WIDTH-1:0] input_data_out;
    logic input_data_valid;
    logic [ADDR_WIDTH-1:0] input_rd_addr;
    
    input_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_input_subsystem (
        .clk(clk),
        .rst_n(rst_n),
        .mode_is_input(mode_is_input),
        .mode_is_gen(mode_is_gen),
        .mode_is_settings(mode_is_settings),
        .start(start_pulse),
        .busy(input_busy),
        .done(input_done),
        .error(input_error),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .settings_countdown(settings_countdown),
        .write_request(input_wr_req),
        .write_ready(write_ready),
        .matrix_id(input_mat_id),
        .actual_rows(input_rows),
        .actual_cols(input_cols),
        .matrix_name(input_name),
        .data_in(input_data_out),
        .data_valid(input_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .storage_rd_addr(input_rd_addr),
        .storage_rd_data(bram_rd_data)
    );
    
    // 2. Compute Subsystem
    logic compute_busy, compute_done, compute_error;
    logic [7:0] compute_seg;
    logic [3:0] compute_an;
    logic [7:0] compute_tx_data;
    logic compute_tx_valid;
    logic [ADDR_WIDTH-1:0] compute_rd_addr;
    logic compute_wr_req;
    logic [2:0] compute_mat_id;
    logic [7:0] compute_rows, compute_cols;
    logic [7:0] compute_name[0:7];
    logic [DATA_WIDTH-1:0] compute_data_out;
    logic compute_data_valid;
    
    compute_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_compute_subsystem (
        .clk(clk),
        .rst_n(rst_n),
        .start(mode_is_calc), // Start logic might need refinement (e.g. pulse on entry?)
                              // Actually matrix_op_selector waits for start pulse to begin selection.
                              // But it also has internal states.
                              // Let's pass start_pulse if we want to restart selection.
                              // Or maybe just 'mode_is_calc' is not enough, we need a trigger.
                              // The selector FSM waits for 'start'.
                              // If we switch to Calc mode, we probably want to start immediately?
                              // Or wait for a button press?
                              // Let's use start_pulse for now.
        .confirm_btn(confirm_btn_pulse), // Used for advancing steps
        .scalar_in(32'd0), // TODO: Map from switches if needed, or use UART input
        .random_scalar(1'b0), // TODO: Map from switch
        .op_mode_in(calc_op_mode),
        .calc_type_in(calc_type),
        .settings_countdown(settings_countdown),
        .busy(compute_busy),
        .done(compute_done),
        .error(compute_error),
        .seg(compute_seg),
        .an(compute_an),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(compute_tx_data),
        .uart_tx_valid(compute_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .bram_rd_addr(compute_rd_addr),
        .bram_rd_data(bram_rd_data),
        .write_request(compute_wr_req),
        .write_ready(write_ready),
        .write_matrix_id(compute_mat_id),
        .write_rows(compute_rows),
        .write_cols(compute_cols),
        .write_name(compute_name),
        .write_data(compute_data_out),
        .write_data_valid(compute_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready)
    );
    
    // 3. Display Subsystem (Matrix Reader All)
    logic display_busy, display_done;
    logic [ADDR_WIDTH-1:0] display_rd_addr;
    logic [7:0] display_tx_data;
    logic display_tx_valid;
    
    matrix_reader_all #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_display_subsystem (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_pulse && mode_is_show),
        .busy(display_busy),
        .done(display_done),
        .bram_addr(display_rd_addr),
        .bram_data(bram_rd_data),
        .ascii_data(display_tx_data),
        .ascii_valid(display_tx_valid),
        .ascii_ready(uart_tx_ready)
    );
    
    // 4. Matrix Storage Manager
    matrix_storage_manager #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_storage_manager (
        .clk(clk),
        .rst_n(rst_n),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(write_matrix_id),
        .actual_rows(write_rows),
        .actual_cols(write_cols),
        .matrix_name(write_name),
        .data_in(write_data),
        .data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .clear_request(1'b0), // TODO: Implement clear logic if needed
        .clear_done(),
        .clear_matrix_id(3'b0),
        .read_addr(bram_rd_addr),
        .data_out(bram_rd_data)
    );

    //-------------------------------------------------------------------------
    // Arbitration Logic
    //-------------------------------------------------------------------------
    
    // BRAM Write Arbitration
    always_comb begin
        if (mode_is_calc) begin
            write_request = compute_wr_req;
            write_matrix_id = compute_mat_id;
            write_rows = compute_rows;
            write_cols = compute_cols;
            write_name = compute_name;
            write_data = compute_data_out;
            write_data_valid = compute_data_valid;
        end else begin
            // Input/Gen/Settings modes handled by input_subsystem
            write_request = input_wr_req;
            write_matrix_id = input_mat_id;
            write_rows = input_rows;
            write_cols = input_cols;
            write_name = input_name;
            write_data = input_data_out;
            write_data_valid = input_data_valid;
        end
    end
    
    // BRAM Read Arbitration
    always_comb begin
        if (mode_is_show) begin
            bram_rd_addr = display_rd_addr;
        end else if (mode_is_calc) begin
            bram_rd_addr = compute_rd_addr;
        end else begin
            // Input/Gen modes use read for finding empty slots
            bram_rd_addr = input_rd_addr;
        end
    end
    
    // UART TX Arbitration
    always_comb begin
        if (mode_is_show) begin
            uart_tx_data = display_tx_data;
            uart_tx_valid = display_tx_valid;
        end else if (mode_is_calc) begin
            uart_tx_data = compute_tx_data;
            uart_tx_valid = compute_tx_valid;
        end else begin
            uart_tx_data = 0;
            uart_tx_valid = 0;
        end
    end
    
    // LED Status
    assign led_ready = !led_busy;
    assign led_busy = input_busy || compute_busy || display_busy;
    assign led_error = input_error || compute_error;
    
    // Seg7 Output
    // Only Compute subsystem currently drives Seg7 (for countdown/status)
    // We could add display for other modes if needed
    assign seg = (mode_is_calc) ? compute_seg : 8'hFF; // Off if not calc
    assign an = (mode_is_calc) ? compute_an : 4'b1111; // Off if not calc

endmodule
