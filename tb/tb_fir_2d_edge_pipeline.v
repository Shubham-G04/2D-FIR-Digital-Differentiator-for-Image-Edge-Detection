// ============================================================
// Module: tb_fir_2d_edge_pipeline.v
// Project: 2D FIR Digital Differentiator for Image Edge Detection
// Description: Comprehensive Testbench for 3-Stage Pipelined 2D FIR
// ============================================================

`timescale 1ns/1ps

module tb_fir_2d_edge_pipeline;

    reg        clk, rst_n, valid_in;
    reg  [7:0] pixel_in;
    wire       valid_out;
    wire [7:0] edge_out;

    // Clock generation: 100 MHz (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate DUT (Device Under Test)
    fir_2d_edge_pipeline u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .pixel_in  (pixel_in),
        .valid_out (valid_out),
        .edge_out  (edge_out)
    );

    // Task to apply pixel input on falling edge
    task apply_pixel;
        input [7:0] pix;
        begin
            @(negedge clk);
            valid_in = 1'b1;
            pixel_in = pix;
        end
    endtask

    // Task to flush pipeline after stimulus
    task flush;
        integer i;
        begin
            @(negedge clk);
            valid_in = 1'b0;
            pixel_in = 8'd0;
            repeat(8) @(posedge clk);
        end
    endtask

    integer idx;

    initial begin
        $dumpfile("tb_fir_2d_edge_pipeline.vcd");
        $dumpvars(0, tb_fir_2d_edge_pipeline);

        rst_n = 0; valid_in = 0; pixel_in = 0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1;
        $display("\n[%0t] RESET RELEASED", $time);

        // TEST 1: Flat region — uniform pixel values (expect 0 in steady-state)
        $display("\n[%0t] TEST 1: Flat region (pixel=100)", $time);
        for (idx = 0; idx < 10; idx = idx+1)
            apply_pixel(8'd100);
        flush;

        // TEST 2: Step edge — sharp transition (0 -> 200)
        $display("\n[%0t] TEST 2: Step edge (0 -> 200)", $time);
        for (idx = 0; idx < 5; idx = idx+1)
            apply_pixel(8'd0);
        for (idx = 0; idx < 8; idx = idx+1)
            apply_pixel(8'd200);
        flush;

        // TEST 3: Linear Ramp — gradual slope (0, 10, 20, ..., 90)
        $display("\n[%0t] TEST 3: Ramp (0, 10, 20, ..., 90)", $time);
        for (idx = 0; idx < 10; idx = idx+1)
            apply_pixel(idx * 10);
        flush;

        // TEST 4: Single Impulse response (pixel=8 at n=0)
        $display("\n[%0t] TEST 4: Impulse response (value=8)", $time);
        for (idx = 0; idx < 5; idx = idx+1)
            apply_pixel(8'd0);
        apply_pixel(8'd8);
        for (idx = 0; idx < 8; idx = idx+1)
            apply_pixel(8'd0);
        flush;

        $display("\n[%0t] SIMULATION COMPLETE SUCCESSFULLY", $time);
        #20; $finish;
    end

    // Monitor output
    always @(posedge clk) begin
        if (valid_out)
            $display("[%0t] pixel_in=%0d | edge_out=%0d", $time, pixel_in, edge_out);
    end

endmodule
