// ============================================================
// Module: fir_1d_nopipeline.v
// Project: 2D FIR Digital Differentiator for Image Edge Detection
// Description: 5-Tap Direct-Form FIR Digital Differentiator
// Coefficients: (1/8) * [-1, -2, 0, +2, +1]
//
// NO PIPELINE — Pure combinational datapath.
// All operations (shift, multiply, add, scale) take place within
// a single clock cycle.
// ============================================================

module fir_1d_nopipeline (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [7:0]  x_in,

    output reg         valid_out,
    output reg  [7:0]  y_out
);

    // ----------------------------------------------------------
    // Filter Coefficients: h = [-1, -2, 0, +2, +1]
    // ----------------------------------------------------------
    localparam signed [3:0] H0 = -1;
    localparam signed [3:0] H1 = -2;
    localparam signed [3:0] H2 =  0;
    localparam signed [3:0] H3 =  2;
    localparam signed [3:0] H4 =  1;

    // ----------------------------------------------------------
    // Shift Register (Tapped Delay Line) — Clocked
    // sr[0] = x[n], sr[1] = x[n-1], ..., sr[4] = x[n-4]
    // ----------------------------------------------------------
    reg [7:0] sr [0:4];

    always @(posedge clk) begin
        if (!rst_n) begin
            sr[0] <= 8'd0; sr[1] <= 8'd0;
            sr[2] <= 8'd0; sr[3] <= 8'd0;
            sr[4] <= 8'd0;
        end else if (valid_in) begin
            sr[0] <= x_in;
            sr[1] <= sr[0];
            sr[2] <= sr[1];
            sr[3] <= sr[2];
            sr[4] <= sr[3];
        end
    end

    // ----------------------------------------------------------
    // Combinational Datapath — All steps evaluated in 1 cycle
    // Multiply → Add → Arithmetic Shift Scale
    // ----------------------------------------------------------
    wire signed [11:0] p0, p1, p2, p3, p4;
    wire signed [11:0] sum;

    assign p0 = H0 * $signed({1'b0, sr[0]});
    assign p1 = H1 * $signed({1'b0, sr[1]});
    assign p2 = H2 * $signed({1'b0, sr[2]});
    assign p3 = H3 * $signed({1'b0, sr[3]});
    assign p4 = H4 * $signed({1'b0, sr[4]});

    assign sum = p0 + p1 + p2 + p3 + p4;

    // ----------------------------------------------------------
    // Output Stage — Registered
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            y_out     <= 8'd0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                if (sum[11])
                    y_out <= (~sum + 1'b1) >>> 3;
                else
                    y_out <= sum >>> 3;
            end else begin
                y_out <= 8'd0;
            end
        end
    end

endmodule
