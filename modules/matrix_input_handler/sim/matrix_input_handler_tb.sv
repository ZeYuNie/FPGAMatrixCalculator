`timescale 1ns / 1ps

module matrix_input_handler_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    localparam CLK_PERIOD = 10;
    
    // DUT signals
    logic        start;
    logic        error;
    logic        busy;
    logic        done;
    
    // Settings interface
    logic [31:0] settings_max_row;
    logic [31:0] settings_max_col;
    logic [31:0] settings_data_min;
    logic [31:0] settings_data_max;
    
    // Buffer RAM interface (simulated num_storage_ram)
    logic [10:0] buf_rd_addr;
    logic [31:0] buf_rd_data;
    
    // Matrix storage manager write interface
    logic        write_request;
    logic        write_ready;
    logic [2:0]  matrix_id;
    logic [7:0]  actual_rows;
    logic [7:0]  actual_cols;
    logic [7:0]  matrix_name [0:7];
    logic [31:0] data_in;
    logic        data_valid;
    logic        write_done;
    logic        writer_ready;
    
    // Matrix storage manager clear interface
    logic        clear_request;
    logic        clear_done;
    logic [2:0]  clear_matrix_id;
    
    // Matrix storage manager read interface
    logic [13:0] storage_rd_addr;
    logic [31:0] storage_rd_data;
    
    // Simulated buffer RAM
    logic [31:0] buffer_ram [0:2047];
    
    // Simulated storage RAM (for checking empty slots)
    logic [31:0] storage_ram [0:16383];
    
    // Captured write data for verification
    logic [31:0] captured_data [$];
    logic [2:0]  captured_id;
    logic [7:0]  captured_rows;
    logic [7:0]  captured_cols;
    logic [7:0]  captured_name [0:7];
    
    // DUT instantiation
    matrix_input_handler dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .error(error),
        .busy(busy),
        .done(done),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data),
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
        .clear_request(clear_request),
        .clear_done(clear_done),
        .clear_matrix_id(clear_matrix_id),
        .storage_rd_addr(storage_rd_addr),
        .storage_rd_data(storage_rd_data)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Buffer RAM read simulation (1 cycle delay)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            buf_rd_data <= 32'd0;
        end else begin
            buf_rd_data <= buffer_ram[buf_rd_addr];
        end
    end
    
    // Storage RAM read simulation (1 cycle delay)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            storage_rd_data <= 32'd0;
        end else begin
            storage_rd_data <= storage_ram[storage_rd_addr];
        end
    end
    
    // Matrix storage manager write interface simulation
    typedef enum logic [1:0] {
        WRITE_IDLE,
        WRITE_WAIT_READY,
        WRITE_STREAMING,
        WRITE_COMPLETE
    } write_state_t;
    
    write_state_t write_state;
    logic [15:0] expected_elements;
    logic [15:0] received_elements;
    
    // Clear interface simulation
    typedef enum logic [1:0] {
        CLEAR_IDLE,
        CLEAR_PROCESSING,
        CLEAR_COMPLETE
    } clear_state_t;
    
    clear_state_t clear_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_state <= WRITE_IDLE;
            write_ready <= 1'b1;
            writer_ready <= 1'b0;
            write_done <= 1'b0;
            expected_elements <= 16'd0;
            received_elements <= 16'd0;
            captured_data = {};
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    write_ready <= 1'b1;
                    writer_ready <= 1'b0;
                    write_done <= 1'b0;
                    
                    if (write_request) begin
                        // Capture metadata
                        captured_id <= matrix_id;
                        captured_rows <= actual_rows;
                        captured_cols <= actual_cols;
                        captured_name <= matrix_name;
                        expected_elements <= actual_rows * actual_cols;
                        received_elements <= 16'd0;
                        captured_data = {};
                        
                        write_ready <= 1'b0;
                        write_state <= WRITE_WAIT_READY;
                        
                        $display("[%0t] Write request received: ID=%0d, rows=%0d, cols=%0d", 
                                 $time, matrix_id, actual_rows, actual_cols);
                    end
                end
                
                WRITE_WAIT_READY: begin
                    // Simulate metadata write cycles
                    writer_ready <= 1'b1;
                    write_state <= WRITE_STREAMING;
                end
                
                WRITE_STREAMING: begin
                    if (data_valid && writer_ready) begin
                        captured_data.push_back(data_in);
                        received_elements <= received_elements + 16'd1;
                        
                        $display("[%0t] Data received [%0d/%0d]: 0x%08h",
                                 $time, received_elements + 1, expected_elements, data_in);
                        
                        if (received_elements + 16'd1 >= expected_elements) begin
                            writer_ready <= 1'b0;
                            write_done <= 1'b1;
                            write_state <= WRITE_COMPLETE;
                        end
                    end
                end
                
                WRITE_COMPLETE: begin
                    write_done <= 1'b0;
                    write_ready <= 1'b1;
                    write_state <= WRITE_IDLE;
                    $display("[%0t] Write complete", $time);
                end
            endcase
        end
    end
    
    // Clear interface simulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_state <= CLEAR_IDLE;
            clear_done <= 1'b0;
        end else begin
            case (clear_state)
                CLEAR_IDLE: begin
                    clear_done <= 1'b0;
                    if (clear_request) begin
                        $display("[%0t] Clear request received for matrix ID=%0d", $time, clear_matrix_id);
                        clear_state <= CLEAR_PROCESSING;
                    end
                end
                
                CLEAR_PROCESSING: begin
                    // Simulate clearing metadata (takes 3 cycles)
                    clear_done <= 1'b1;
                    clear_state <= CLEAR_COMPLETE;
                end
                
                CLEAR_COMPLETE: begin
                    clear_done <= 1'b0;
                    clear_state <= CLEAR_IDLE;
                    $display("[%0t] Clear complete for matrix ID=%0d", $time, clear_matrix_id);
                    
                    // Actually clear the storage RAM metadata
                    case (clear_matrix_id)
                        0: storage_ram[0] <= 32'd0;
                        1: storage_ram[1152] <= 32'd0;
                        2: storage_ram[2304] <= 32'd0;
                        3: storage_ram[3456] <= 32'd0;
                        4: storage_ram[4608] <= 32'd0;
                        5: storage_ram[5760] <= 32'd0;
                        6: storage_ram[6912] <= 32'd0;
                        7: storage_ram[8064] <= 32'd0;
                    endcase
                end
            endcase
        end
    end
    
    // Test tasks
    task automatic load_buffer_named_matrix(
        input int id,
        input byte name[8],
        input int rows,
        input int cols,
        input int data[$]
    );
        int idx = 0;
        buffer_ram[idx++] = 32'hFFFFFFFF;  // -1
        buffer_ram[idx++] = id;
        buffer_ram[idx++] = {name[0], name[1], name[2], name[3]};
        buffer_ram[idx++] = {name[4], name[5], name[6], name[7]};
        buffer_ram[idx++] = rows;
        buffer_ram[idx++] = cols;
        
        foreach (data[i]) begin
            buffer_ram[idx++] = data[i];
        end
        
        $display("[INFO] Loaded named matrix: ID=%0d, rows=%0d, cols=%0d, data_count=%0d", 
                 id, rows, cols, data.size());
    endtask
    
    task automatic load_buffer_anonymous_matrix(
        input int rows,
        input int cols,
        input int data[$]
    );
        int idx = 0;
        buffer_ram[idx++] = rows;
        buffer_ram[idx++] = cols;
        
        foreach (data[i]) begin
            buffer_ram[idx++] = data[i];
        end
        
        $display("[INFO] Loaded anonymous matrix: rows=%0d, cols=%0d, data_count=%0d", 
                 rows, cols, data.size());
    endtask
    
    task automatic setup_storage_slot(input int id, input int rows, input int cols);
        int base_addr;
        case (id)
            0: base_addr = 0;
            1: base_addr = 1152;
            2: base_addr = 2304;
            3: base_addr = 3456;
            4: base_addr = 4608;
            5: base_addr = 5760;
            6: base_addr = 6912;
            7: base_addr = 8064;
        endcase
        
        storage_ram[base_addr] = {rows[7:0], cols[7:0], 16'd0};
        $display("[INFO] Storage slot %0d setup: rows=%0d, cols=%0d", id, rows, cols);
    endtask
    
    task automatic verify_write(
        input int expected_id,
        input int expected_rows,
        input int expected_cols,
        input byte expected_name[8],
        input int expected_data[$]
    );
        int pass = 1;
        
        // Check metadata
        if (captured_id !== expected_id) begin
            $error("Matrix ID mismatch: expected %0d, got %0d", expected_id, captured_id);
            pass = 0;
        end
        
        if (captured_rows !== expected_rows) begin
            $error("Rows mismatch: expected %0d, got %0d", expected_rows, captured_rows);
            pass = 0;
        end
        
        if (captured_cols !== expected_cols) begin
            $error("Cols mismatch: expected %0d, got %0d", expected_cols, captured_cols);
            pass = 0;
        end
        
        for (int i = 0; i < 8; i++) begin
            if (captured_name[i] !== expected_name[i]) begin
                $error("Name[%0d] mismatch: expected 0x%02h, got 0x%02h", 
                       i, expected_name[i], captured_name[i]);
                pass = 0;
            end
        end
        
        // Check data
        if (captured_data.size() !== expected_data.size()) begin
            $error("Data count mismatch: expected %0d, got %0d", 
                   expected_data.size(), captured_data.size());
            pass = 0;
        end else begin
            foreach (expected_data[i]) begin
                if (captured_data[i] !== expected_data[i]) begin
                    $error("Data[%0d] mismatch: expected 0x%08h, got 0x%08h", 
                           i, expected_data[i], captured_data[i]);
                    pass = 0;
                end
            end
        end
        
        if (pass) begin
            $display("[PASS] Write verification successful");
        end else begin
            $display("[FAIL] Write verification failed");
        end
    endtask
    
    // Main test sequence
    initial begin
        int test_data[$];
        byte test_name[8];
        byte empty_name[8];
        
        // Initialize
        rst_n = 0;
        start = 0;
        
        // Initialize settings (default values)
        settings_max_row = 32'd32;
        settings_max_col = 32'd32;
        settings_data_min = -32'd1000;
        settings_data_max = 32'd1000;
        
        // Clear storage RAM (all slots empty)
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Clear buffer RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        // ===================================================================
        // Test 1: Named matrix input
        // ===================================================================
        $display("\n========================================");
        $display("Test 1: Named matrix (ID=3, 2x3 matrix)");
        $display("========================================");
        
        test_name = '{8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08};
        test_data = '{32'd8, 32'd9, 32'd0, 32'd8, 32'd0, 32'd9};
        
        load_buffer_named_matrix(3, test_name, 2, 3, test_data);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 1 FAILED: Error flag asserted");
        end else begin
            $display("[INFO] Test 1: Processing completed");
            verify_write(3, 2, 3, test_name, test_data);
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 2: Anonymous matrix input (finds empty slot)
        // ===================================================================
        $display("\n========================================");
        $display("Test 2: Anonymous matrix (2x3 matrix)");
        $display("========================================");
        
        // Setup: slots 1, 2, 3 are occupied, slot 4 is empty
        setup_storage_slot(1, 3, 3);
        setup_storage_slot(2, 2, 2);
        setup_storage_slot(3, 4, 4);
        setup_storage_slot(4, 0, 0);  // Empty
        
        empty_name = '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
        test_data = '{32'd6, 32'd7, 32'd8, 32'd6, 32'd5, 32'd4};
        
        load_buffer_anonymous_matrix(2, 3, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 2 FAILED: Error flag asserted");
        end else begin
            $display("[INFO] Test 2: Processing completed, assigned to slot %0d", captured_id);
            if (captured_id !== 4) begin
                $error("Test 2 FAILED: Expected slot 4, got %0d", captured_id);
            end else begin
                verify_write(4, 2, 3, empty_name, test_data);
            end
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 3: Invalid matrix ID error
        // ===================================================================
        $display("\n========================================");
        $display("Test 3: Invalid matrix ID (ID=8)");
        $display("========================================");
        
        test_name = '{8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48};
        test_data = '{32'd1, 32'd2};
        
        load_buffer_named_matrix(8, test_name, 1, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 3: Error flag correctly asserted for invalid ID");
            end
            begin
                repeat (1000) @(posedge clk);
                if (!error) begin
                    $error("Test 3 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 4: No empty slots error
        // ===================================================================
        $display("\n========================================");
        $display("Test 4: No empty slots available");
        $display("========================================");
        
        // Setup: all slots 1-7 are occupied
        for (int i = 1; i <= 7; i++) begin
            setup_storage_slot(i, 2, 2);
        end
        
        test_data = '{32'd10, 32'd20, 32'd30, 32'd40};
        load_buffer_anonymous_matrix(2, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 4: Error flag correctly asserted for no empty slots");
            end
            begin
                repeat (2000) @(posedge clk);
                if (!error) begin
                    $error("Test 4 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 5: Data insufficient (padding with zeros)
        // ===================================================================
        $display("\n========================================");
        $display("Test 5: Data insufficient - auto padding with zeros");
        $display("========================================");
        
        // Clear buffer RAM to simulate cleared state
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        
        // Clear storage RAM
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load named matrix: 2x3 but only provide 2 data elements
        test_name = '{8'h50, 8'h41, 8'h44, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
        test_data = '{32'd100, 32'd200};  // Only 2 elements for 2x3 matrix
        
        load_buffer_named_matrix(5, test_name, 2, 3, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 5 FAILED: Error flag asserted");
        end else begin
            $display("[INFO] Test 5: Processing completed");
            // Expected: [100, 200, 0, 0, 0, 0] - remaining 4 elements should be 0
            test_data = '{32'd100, 32'd200, 32'd0, 32'd0, 32'd0, 32'd0};
            verify_write(5, 2, 3, test_name, test_data);
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 6: Data overflow (excess data ignored)
        // ===================================================================
        $display("\n========================================");
        $display("Test 6: Data overflow - excess ignored");
        $display("========================================");
        
        // Clear buffer RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        
        // Load anonymous matrix: 2x2 but provide 8 data elements
        test_data = '{32'd10, 32'd20, 32'd30, 32'd40, 32'd50, 32'd60, 32'd70, 32'd80};
        
        load_buffer_anonymous_matrix(2, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 6 FAILED: Error flag asserted");
        end else begin
            $display("[INFO] Test 6: Processing completed, assigned to slot %0d", captured_id);
            // Expected: only first 4 elements [10, 20, 30, 40], last 4 ignored
            test_data = '{32'd10, 32'd20, 32'd30, 32'd40};
            verify_write(captured_id, 2, 2, empty_name, test_data);
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 7: Mixed case - anonymous matrix with insufficient data
        // ===================================================================
        $display("\n========================================");
        $display("Test 7: Anonymous matrix with insufficient data");
        $display("========================================");
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load anonymous matrix: 3x2 (6 elements) but only provide 3
        test_data = '{32'd5, 32'd10, 32'd15};
        
        load_buffer_anonymous_matrix(3, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 7 FAILED: Error flag asserted");
        end else begin
            $display("[INFO] Test 7: Processing completed, assigned to slot %0d", captured_id);
            // Expected: [5, 10, 15, 0, 0, 0] - last 3 positions padded with 0
            test_data = '{32'd5, 32'd10, 32'd15, 32'd0, 32'd0, 32'd0};
            verify_write(captured_id, 3, 2, empty_name, test_data);
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 8: Dimension exceeds settings (rows超限)
        // ===================================================================
        $display("\n========================================");
        $display("Test 8: Dimension exceeds settings - rows超限");
        $display("========================================");
        
        // Set strict dimension limits
        settings_max_row = 32'd5;
        settings_max_col = 32'd5;
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load named matrix with rows=10 (exceeds limit of 5)
        test_name = '{8'h44, 8'h49, 8'h4D, 8'h45, 8'h52, 8'h52, 8'h00, 8'h00};
        test_data = '{32'd1, 32'd2, 32'd3};
        
        load_buffer_named_matrix(2, test_name, 10, 3, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 8: Error flag correctly asserted for dimension overflow (rows)");
                // Verify that clear was requested
                if (clear_request) begin
                    $display("[PASS] Test 8: Clear request issued correctly");
                end
            end
            begin
                repeat (2000) @(posedge clk);
                if (!error) begin
                    $error("Test 8 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 9: Dimension exceeds settings (cols超限)
        // ===================================================================
        $display("\n========================================");
        $display("Test 9: Dimension exceeds settings - cols超限");
        $display("========================================");
        
        // Keep strict limits
        settings_max_row = 32'd8;
        settings_max_col = 32'd8;
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load named matrix with cols=12 (exceeds limit of 8)
        test_name = '{8'h43, 8'h4F, 8'h4C, 8'h45, 8'h52, 8'h52, 8'h00, 8'h00};
        test_data = '{32'd5, 32'd6};
        
        load_buffer_named_matrix(3, test_name, 2, 12, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 9: Error flag correctly asserted for dimension overflow (cols)");
            end
            begin
                repeat (2000) @(posedge clk);
                if (!error) begin
                    $error("Test 9 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 10: Data value exceeds maximum
        // ===================================================================
        $display("\n========================================");
        $display("Test 10: Data value exceeds maximum");
        $display("========================================");
        
        // Set data range limits
        settings_max_row = 32'd10;
        settings_max_col = 32'd10;
        settings_data_min = -32'd100;
        settings_data_max = 32'd100;
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load matrix with some data exceeding max (data[1]=200 > 100)
        test_name = '{8'h4D, 8'h41, 8'h58, 8'h45, 8'h52, 8'h52, 8'h00, 8'h00};
        test_data = '{32'd50, 32'd200, 32'd30};  // 200 exceeds max of 100
        
        load_buffer_named_matrix(4, test_name, 1, 3, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 10: Error flag correctly asserted for data overflow");
                // Verify clear was requested
                if (clear_request || clear_done) begin
                    $display("[PASS] Test 10: Clear operation triggered for data overflow");
                end
            end
            begin
                repeat (2000) @(posedge clk);
                if (!error) begin
                    $error("Test 10 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 11: Data value below minimum
        // ===================================================================
        $display("\n========================================");
        $display("Test 11: Data value below minimum");
        $display("========================================");
        
        // Keep data range limits
        settings_data_min = -32'd50;
        settings_data_max = 32'd50;
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load matrix with some data below min (data[2]=-100 < -50)
        test_name = '{8'h4D, 8'h49, 8'h4E, 8'h45, 8'h52, 8'h52, 8'h00, 8'h00};
        test_data = '{32'd10, 32'd20, -32'd100, 32'd5};  // -100 below min of -50
        
        load_buffer_named_matrix(5, test_name, 2, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        // Wait for error or timeout
        fork
            begin
                wait(error);
                $display("[PASS] Test 11: Error flag correctly asserted for data underflow");
            end
            begin
                repeat (2000) @(posedge clk);
                if (!error) begin
                    $error("Test 11 FAILED: Error flag not asserted");
                end
            end
        join_any
        disable fork;
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // Test 12: Valid data within range (should succeed)
        // ===================================================================
        $display("\n========================================");
        $display("Test 12: Valid data within range");
        $display("========================================");
        
        // Set reasonable limits
        settings_max_row = 32'd10;
        settings_max_col = 32'd10;
        settings_data_min = -32'd100;
        settings_data_max = 32'd100;
        
        // Clear buffer and storage RAM
        for (int i = 0; i < 2048; i++) begin
            buffer_ram[i] = 32'd0;
        end
        for (int i = 0; i < 16384; i++) begin
            storage_ram[i] = 32'd0;
        end
        
        // Load valid matrix (all within range)
        test_name = '{8'h56, 8'h41, 8'h4C, 8'h49, 8'h44, 8'h00, 8'h00, 8'h00};
        test_data = '{32'd50, -32'd30, 32'd75, -32'd80};
        
        load_buffer_named_matrix(6, test_name, 2, 2, test_data);
        
        // Reset DUT
        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        
        wait(done || error);
        
        if (error) begin
            $error("Test 12 FAILED: Error flag asserted for valid data");
        end else begin
            $display("[PASS] Test 12: Valid data processed successfully");
            verify_write(6, 2, 2, test_name, test_data);
        end
        
        repeat (10) @(posedge clk);
        
        // ===================================================================
        // End of tests
        // ===================================================================
        $display("\n========================================");
        $display("All tests completed");
        $display("========================================");
        
        repeat (20) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100us;
        $error("Simulation timeout!");
        $finish;
    end

endmodule