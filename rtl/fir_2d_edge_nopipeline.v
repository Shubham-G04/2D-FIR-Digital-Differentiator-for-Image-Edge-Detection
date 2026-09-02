// ============================================================
// Module: fir_2d_edge_nopipeline.v
// Project: 2D FIR Digital Differentiator for Image Edge Detection
// Description: Top-Level 2D Edge Detector — Non-Pipelined
//
// Instantiates horizontal (row) and vertical (col) 1D FIR filters
// and computes the combined spatial gradient magnitude:
//   |G(i,j)| = |Gx(i,j)| + |Gy(i,j)|
// ============================================================

module fir_2d_edge_nopipeline (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       valid_in,
    input  wire [7:0] pixel_in,

    output wire       valid_out,
    output reg  [7:0] edge_out
);

    // Horizontal gradient Gx
    wire       gx_valid;
    wire [7:0] gx_out;

    fir_1d_nopipeline u_fir_row (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .x_in      (pixel_in),
        .valid_out (gx_valid),
        .y_out     (gx_out)
    );

    // Vertical gradient Gy
    wire       gy_valid;
    wire [7:0] gy_out;

    fir_1d_nopipeline u_fir_col (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .x_in      (pixel_in),
        .valid_out (gy_valid),
        .y_out     (gy_out)
    );

    // Edge magnitude: |Gx| + |Gy|, saturate to 8-bit [0, 255]
    assign valid_out = gx_valid;

    wire [8:0] sum_mag = {1'b0, gx_out} + {1'b0, gy_out};

    always @(posedge clk) begin
        if (!rst_n)
            edge_out <= 8'd0;
        else if (valid_out)
            edge_out <= sum_mag[8] ? 8'd255 : sum_mag[7:0];
        else
            edge_out <= 8'd0;
    end

endmodule
