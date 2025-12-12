`timescale 1ns / 1ps

/**
 * settings_data_handler - Settings Data Handler
 * 
 * Reads setting data from buffer RAM (32-bit words) and validates:
 * - Word 0: Command (1=max_row, 2=max_col, 3=data_min, 4=data_max, 5=countdown_time)
 * - Word 1: Data Value (32-bit integer)
 *
 * Validation rules:
 * - Row/Column count cannot exceed 32
 * - Data max value cannot exceed 65535
 * - Countdown time must be between 5 and 15
 */
module settings_data_handler (
    input  logic        clk,
    input  logic        rst_n,

    // Control signals
    input  logic        start,          // One-cycle start signal
    output logic        busy,           // Busy status
    output logic        done,           // Done signal (one cycle)
    output logic        error,          // Error signal (stays high until reset)

    // RAM read interface
    output logic [10:0] buf_rd_addr,    // RAM read address
    input  logic [31:0] buf_rd_data,    // RAM read data
    
    // Settings output interface (Persistent outputs)
    output logic        settings_wr_en,     // Settings write enable (pulse)
    output logic [31:0] settings_max_row,   // Max row count
    output logic [31:0] settings_max_col,   // Max column count
    output logic [31:0] settings_data_min,  // Data minimum value
    output logic [31:0] settings_data_max,  // Data maximum value
    output logic [31:0] settings_countdown  // Countdown time (5-15s)
);

    // State machine definition
    typedef enum logic [3:0] {
        IDLE,           // Idle state
        READ_CMD,       // Read command word
        WAIT_CMD_LATENCY, // Wait for RAM read latency
        WAIT_CMD,       // Capture command word
        READ_DATA,      // Read data word
        WAIT_DATA_LATENCY, // Wait for RAM read latency
        WAIT_DATA,      // Capture data word
        VALIDATE,       // Validate data
        WRITE_SETTINGS  // Write settings
    } state_t;

    state_t state, state_next;

    // Internal registers
    logic [31:0] cmd_reg;           // Command register
    logic [31:0] data_reg;          // Data register
    logic        error_reg;         // Error register
    logic        validation_error;  // Validation error flag
    logic [10:0] addr_ptr;          // Address pointer

    // Persistent Settings Registers (Now wires from RAM)
    logic [31:0] reg_max_row;
    logic [31:0] reg_max_col;
    logic [31:0] reg_data_min;
    logic [31:0] reg_data_max;
    logic [31:0] reg_countdown;
    
    // RAM Write Interface
    logic        ram_wr_en;
    logic [31:0] ram_set_max_row;
    logic [31:0] ram_set_max_col;
    logic [31:0] ram_data_min;
    logic [31:0] ram_data_max;
    logic [31:0] ram_set_countdown;
    
    settings_ram u_settings_ram (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(ram_wr_en),
        .set_max_row(ram_set_max_row),
        .set_max_col(ram_set_max_col),
        .data_min(ram_data_min),
        .data_max(ram_data_max),
        .set_countdown_time(ram_set_countdown),
        .rd_max_row(reg_max_row),
        .rd_max_col(reg_max_col),
        .rd_data_min(reg_data_min),
        .rd_data_max(reg_data_max),
        .rd_countdown_time(reg_countdown)
    );

    // State transition logic
    always_comb begin
        state_next = state;
        
        case (state)
            IDLE: begin
                if (start && !error_reg) begin
                    state_next = READ_CMD;
                end
            end
            
            READ_CMD: begin
                state_next = WAIT_CMD_LATENCY;
            end

            WAIT_CMD_LATENCY: begin
                state_next = WAIT_CMD;
            end
            
            WAIT_CMD: begin
                state_next = READ_DATA;
            end
            
            READ_DATA: begin
                state_next = WAIT_DATA_LATENCY;
            end

            WAIT_DATA_LATENCY: begin
                state_next = WAIT_DATA;
            end
            
            WAIT_DATA: begin
                state_next = VALIDATE;
            end
            
            VALIDATE: begin
                if (validation_error) begin
                    state_next = IDLE;  // Return to IDLE on error
                end else begin
                    state_next = WRITE_SETTINGS;
                end
            end
            
            WRITE_SETTINGS: begin
                state_next = IDLE;
            end
            
            default: state_next = IDLE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cmd_reg   <= 32'd0;
            data_reg  <= 32'd0;
            error_reg <= 1'b0;
            addr_ptr  <= 11'd0;
            
            // Initialize settings to defaults - Handled by RAM reset
        end else begin
            state <= state_next;
            
            if (state == IDLE && start) begin
                addr_ptr <= 11'd0;
                error_reg <= 1'b0; // Clear error on new start
            end

            // Read command
            if (state == READ_CMD) begin
                // Address is already set to addr_ptr (0)
            end
            
            if (state == WAIT_CMD) begin
                cmd_reg <= buf_rd_data;
                addr_ptr <= addr_ptr + 11'd1; // Increment for data
                $display("[%0t] Settings Handler Read CMD: %d at addr %d", $time, buf_rd_data, addr_ptr);
            end
            
            // Read data
            if (state == READ_DATA) begin
                // Address is set to addr_ptr (1)
            end
            
            if (state == WAIT_DATA) begin
                data_reg <= buf_rd_data;
                $display("[%0t] Settings Handler Read DATA: %d at addr %d", $time, buf_rd_data, addr_ptr);
            end
            
            // Set error flag during validation
            if (state == VALIDATE && validation_error) begin
                error_reg <= 1'b1;
                $display("[%0t] Settings Handler Validation Error! Cmd: %d, Data: %d", $time, cmd_reg, data_reg);
            end

            // Update settings registers - Handled by RAM write
        end
    end
    
    // RAM Write Logic
    always_comb begin
        ram_wr_en = (state == WRITE_SETTINGS);
        ram_set_max_row = reg_max_row;
        ram_set_max_col = reg_max_col;
        ram_data_min = reg_data_min;
        ram_data_max = reg_data_max;
        ram_set_countdown = reg_countdown;
        
        if (state == WRITE_SETTINGS) begin
            case (cmd_reg)
                32'd1: ram_set_max_row = data_reg;
                32'd2: ram_set_max_col = data_reg;
                32'd3: ram_data_min = data_reg;
                32'd4: ram_data_max = data_reg;
                32'd5: ram_set_countdown = data_reg;
            endcase
        end
    end

    // Data validation logic
    always_comb begin
        validation_error = 1'b0;
        
        if (state == VALIDATE) begin
            case (cmd_reg)
                32'd1: begin  // Max row count
                    if (data_reg > 32'd32 || data_reg == 32'd0) begin
                        validation_error = 1'b1;
                    end
                end
                32'd2: begin  // Max column count
                    if (data_reg > 32'd32 || data_reg == 32'd0) begin
                        validation_error = 1'b1;
                    end
                end
                32'd3: begin  // Data minimum value
                    // No special restrictions
                    validation_error = 1'b0;
                end
                32'd4: begin  // Data maximum value
                    if (data_reg > 32'd65535) begin
                        validation_error = 1'b1;
                    end
                end
                32'd5: begin  // Countdown time
                    if (data_reg < 32'd5 || data_reg > 32'd15) begin
                        validation_error = 1'b1;
                    end
                end
                default: begin  // Invalid command
                    validation_error = 1'b1;
                end
            endcase
        end
    end

    // RAM read address generation
    assign buf_rd_addr = addr_ptr;

    // Output signals
    assign busy = (state != IDLE);
    assign done = (state == WRITE_SETTINGS);
    assign error = error_reg;

    // Persistent Settings Outputs
    assign settings_max_row = reg_max_row;
    assign settings_max_col = reg_max_col;
    assign settings_data_min = reg_data_min;
    assign settings_data_max = reg_data_max;
    assign settings_countdown = reg_countdown;

    // Write Enable Pulse
    assign settings_wr_en = (state == WRITE_SETTINGS);

endmodule
