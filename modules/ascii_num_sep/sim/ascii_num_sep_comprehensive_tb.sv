`timescale 1ns / 1ps

module ascii_num_sep_comprehensive_tb;

    // Parameters
    parameter MAX_PAYLOAD = 2048;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 2048;
    parameter ADDR_WIDTH = 11;

    // Signals
    logic                    clk;
    logic                    rst_n;
    logic                    buf_clear;
    logic [7:0]              pkt_payload_data;
    logic                    pkt_payload_valid;
    logic                    pkt_payload_last;
    logic                    pkt_payload_ready;
    logic [ADDR_WIDTH-1:0]   rd_addr;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    processing;
    logic                    done;
    logic                    invalid;
    logic [10:0]             num_count;

    // DUT Instantiation
    ascii_num_sep_top #(
        .MAX_PAYLOAD(MAX_PAYLOAD),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .buf_clear(buf_clear),
        .pkt_payload_data(pkt_payload_data),
        .pkt_payload_valid(pkt_payload_valid),
        .pkt_payload_last(pkt_payload_last),
        .pkt_payload_ready(pkt_payload_ready),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .processing(processing),
        .done(done),
        .invalid(invalid),
        .num_count(num_count)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper Task: Send String via UART Interface
    task send_string(input string str);
        int i;
        begin
            wait(pkt_payload_ready);
            for (i = 0; i < str.len(); i++) begin
                @(posedge clk);
                pkt_payload_data <= str[i];
                pkt_payload_valid <= 1;
                pkt_payload_last <= (i == str.len() - 1);
                wait(pkt_payload_ready);
            end
            @(posedge clk);
            pkt_payload_valid <= 0;
            pkt_payload_last <= 0;
        end
    endtask

    // Helper Task: Verify Result
    task verify_result(input int index, input int expected_val);
        begin
            rd_addr = index;
            @(posedge clk);
            #1; // Wait for RAM read
            if (rd_data !== expected_val) begin
                $display("ERROR: Index %0d mismatch. Expected: %0d, Got: %0d", index, expected_val, $signed(rd_data));
            end else begin
                $display("PASS: Index %0d matches %0d", index, $signed(rd_data));
            end
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        buf_clear = 0;
        pkt_payload_data = 0;
        pkt_payload_valid = 0;
        pkt_payload_last = 0;
        rd_addr = 0;

        // Reset
        #100;
        rst_n = 1;
        #100;

        // Test Case 1: Single Positive Number "123"
        $display("\n--- Test Case 1: Single Positive Number '123' ---");
        send_string("123");
        
        // Wait for processing
        wait(done);
        #100;
        
        if (num_count !== 1) $display("ERROR: num_count mismatch. Expected: 1, Got: %0d", num_count);
        verify_result(0, 123);

        // Clear Buffer
        buf_clear = 1;
        #10;
        buf_clear = 0;
        #100;

        // Test Case 2: Multiple Numbers "10 20 -30"
        $display("\n--- Test Case 2: Multiple Numbers '10 20 -30' ---");
        // Reset DUT state (soft reset via rst_n or just new packet? 
        // The DUT accumulates in RAM. We need to reset write pointer if we want to overwrite?
        // ascii_num_sep_top doesn't have a 'reset_write_ptr' input other than rst_n.
        // But buf_clear clears the RAM content, not the write pointer in data_write_controller?
        // data_write_controller resets on rst_n.
        // So we should pulse rst_n to reset pointers for a clean test.
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;
        
        send_string("10 20 -30");
        wait(done);
        #100;
        
        if (num_count !== 3) $display("ERROR: num_count mismatch. Expected: 3, Got: %0d", num_count);
        verify_result(0, 10);
        verify_result(1, 20);
        verify_result(2, -30);

        // Test Case 3: Leading/Trailing Spaces "  45  -67  "
        $display("\n--- Test Case 3: Leading/Trailing Spaces '  45  -67  ' ---");
        rst_n = 0; #20; rst_n = 1; #20;
        
        send_string("  45  -67  ");
        wait(done);
        #100;
        
        if (num_count !== 2) $display("ERROR: num_count mismatch. Expected: 2, Got: %0d", num_count);
        verify_result(0, 45);
        verify_result(1, -67);

        // Test Case 4: Single Negative Number "-999"
        $display("\n--- Test Case 4: Single Negative Number '-999' ---");
        rst_n = 0; #20; rst_n = 1; #20;
        
        send_string("-999");
        wait(done);
        #100;
        
        if (num_count !== 1) $display("ERROR: num_count mismatch. Expected: 1, Got: %0d", num_count);
        verify_result(0, -999);

        // Test Case 5: Invalid Character "12a34"
        $display("\n--- Test Case 5: Invalid Character '12a34' ---");
        rst_n = 0; #20; rst_n = 1; #20;
        
        send_string("12a34");
        wait(invalid);
        $display("PASS: Invalid signal asserted");

        // Test Case 6: Zero "0"
        $display("\n--- Test Case 6: Zero '0' ---");
        rst_n = 0; #20; rst_n = 1; #20;
        
        send_string("0");
        wait(done);
        #100;
        
        if (num_count !== 1) $display("ERROR: num_count mismatch. Expected: 1, Got: %0d", num_count);
        verify_result(0, 0);

        // Test Case 7: Multiple Zeros "0 0 0"
        $display("\n--- Test Case 7: Multiple Zeros '0 0 0' ---");
        rst_n = 0; #20; rst_n = 1; #20;
        
        send_string("0 0 0");
        wait(done);
        #100;
        
        if (num_count !== 3) $display("ERROR: num_count mismatch. Expected: 3, Got: %0d", num_count);
        verify_result(0, 0);
        verify_result(1, 0);
        verify_result(2, 0);

        $display("\n--- All Tests Completed ---");
        $finish;
    end

    // Monitor internal signals
    always @(dut.u_parser.state) begin
        // $display("[%0t] Parser State: %0d", $time, dut.u_parser.state);
    end

    always @(dut.u_converter.state) begin
        // $display("[%0t] Converter State: %0d", $time, dut.u_converter.state);
    end

endmodule
