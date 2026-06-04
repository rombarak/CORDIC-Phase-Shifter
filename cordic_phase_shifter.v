`timescale 1ns / 1ps

// ============================================================================
// Module: cordic_phase_shifter
// Description: Implements a pipelined CORDIC algorithm in Rotation Mode.
// It rotates an input vector (x, y) by a given angle (p).
// ============================================================================
module cordic_phase_shifter #(
 parameter n = 20,                  // Number of CORDIC iterations (pipeline stages)
 parameter XY_WIDTH = 10,           // Internal bit-width for X and Y paths (includes extra bits to prevent overflow)
 parameter PHASE_WIDTH = 16,        // Bit-width for the phase (angle) data
 parameter XY_INPUT_WIDTH = 8       // Bit-width for the incoming X and Y coordinates
)(
 input signed [XY_INPUT_WIDTH-1:0] x, // Input X coordinate
 input signed [XY_INPUT_WIDTH-1:0] y, // Input Y coordinate
 input clk,                           // System clock
 input rst,                           // Active HIGH synchronous reset
 input signed [PHASE_WIDTH-1:0] p,    // Target phase (angle) to rotate the vector
 output signed [XY_WIDTH-1:0] x_out,  // Final rotated X coordinate
 output signed [XY_WIDTH-1:0] y_out   // Final rotated Y coordinate
);
 
// ----------------------------------------------------------------------------
// Gain Compensation Constant
// CORDIC rotation increases the vector magnitude by a factor of ~1.6467.
// To normalize it, we multiply by 1/1.6467 ~= 0.6072.
// 39787 is roughly 0.6072 * (2^16), allowing us to use integer math.
// ----------------------------------------------------------------------------
localparam signed [16:0] gain = 17'sd39787;
 
// ----------------------------------------------------------------------------
// Pipeline Registers (Memory Arrays)
// These arrays create the physical Flip-Flops for the pipeline stages.
// Index [0] is the input stage, [n] is the final output stage.
// ----------------------------------------------------------------------------
reg signed [XY_WIDTH-1:0] x_pipe [0:n];
reg signed [XY_WIDTH-1:0] y_pipe [0:n];
reg signed [PHASE_WIDTH-1:0] p_pipe [0:n];
 
// Wires to hold the multiplied values before shifting back
wire signed [XY_WIDTH+17-1:0] x_gain;
wire signed [XY_WIDTH+17-1:0] y_gain;
 
// ----------------------------------------------------------------------------
// Arctangent Lookup Table (LUT)
// Stores pre-calculated angles for each CORDIC iteration.
// Values represent atan(2^-i) scaled to match the phase representation.
// ----------------------------------------------------------------------------
wire signed [PHASE_WIDTH-1:0] atan_table [0:n-1];
 
assign atan_table[0] = 16'd8192;
assign atan_table[1] = 16'd4836;
assign atan_table[2] = 16'd2555;
assign atan_table[3] = 16'd1297;
assign atan_table[4] = 16'd651;
assign atan_table[5] = 16'd325;
assign atan_table[6] = 16'd162;
assign atan_table[7] = 16'd81;
assign atan_table[8] = 16'd40;
assign atan_table[9] = 16'd20;
assign atan_table[10] = 16'd10;
assign atan_table[11] = 16'd5;
assign atan_table[12] = 16'd2;
assign atan_table[13] = 16'd1;
assign atan_table[14] = 16'd0;
assign atan_table[15] = 16'd0;
assign atan_table[16] = 16'd0;
assign atan_table[17] = 16'd0;
assign atan_table[18] = 16'd0;
assign atan_table[19] = 16'd0;
 
// ----------------------------------------------------------------------------
// Function: div_pow2_trunc
// Performs arithmetic right shift (division by 2^shift).
// It includes specific logic to handle negative numbers correctly to match
// software rounding (truncating towards zero) instead of floor rounding.
// ----------------------------------------------------------------------------
function signed [XY_WIDTH-1:0] div_pow2_trunc;
    input signed [XY_WIDTH-1:0] val;
    input integer shift;
    begin
        if (val < 0)
            div_pow2_trunc = -((-val) >>> shift);
        else
            div_pow2_trunc = val >>> shift;
    end
endfunction
 
// ----------------------------------------------------------------------------
// Stage 0: Input Registering
// Latches the incoming data into the first stage of the pipeline on clock edge.
// ----------------------------------------------------------------------------
always @(posedge clk) begin
 if(rst) begin
 x_pipe[0] <= 10'd0;
 y_pipe[0] <= 10'd0;
 p_pipe[0] <= 16'd0;
 end else begin 
 x_pipe[0] <= x;
 y_pipe[0] <= y;
 p_pipe[0] <= p;
 end
end
 
// ----------------------------------------------------------------------------
// Hardware Generation: CORDIC Pipeline Stages
// This loop physically duplicates the logic 'n' times in hardware.
// Data flows from stage [i] to stage [i+1] on every clock cycle.
// ----------------------------------------------------------------------------
genvar i;
 generate
 for (i = 0; i < n; i = i + 1) begin : cordic_pipe_stages
    always @(posedge clk) begin
        if(rst) begin
            x_pipe[i+1] <= 10'd0;
            y_pipe[i+1] <= 10'd0;
            p_pipe[i+1] <= 16'd0;
        end else begin 
            // If remaining angle is positive, rotate in negative direction
            if (p_pipe[i] > 0) begin
                x_pipe[i+1] <= x_pipe[i] - div_pow2_trunc(y_pipe[i], i);
                y_pipe[i+1] <= y_pipe[i] + div_pow2_trunc(x_pipe[i], i);
                p_pipe[i+1] <= p_pipe[i] - atan_table[i]; // Subtract step angle
            end 
            // If remaining angle is negative or zero, rotate in positive direction
            else begin
                x_pipe[i+1] <= x_pipe[i] + div_pow2_trunc(y_pipe[i], i);
                y_pipe[i+1] <= y_pipe[i] - div_pow2_trunc(x_pipe[i], i);
                p_pipe[i+1] <= p_pipe[i] + atan_table[i]; // Add step angle
            end
        end
    end
 end
 endgenerate
 
// ----------------------------------------------------------------------------
// Final Normalization (Gain Compensation)
// Multiplies the output of the last pipeline stage [n] by the gain constant.
// ----------------------------------------------------------------------------
assign x_gain = x_pipe[n] * gain;
assign y_gain = y_pipe[n] * gain;
 
// ----------------------------------------------------------------------------
// Function: gain_shift_trunc
// Re-scales the multiplied data by shifting right by 16 bits (dividing by 2^16).
// Handles negative number truncation properly.
// ----------------------------------------------------------------------------
function signed [XY_WIDTH-1:0] gain_shift_trunc;
    input signed [XY_WIDTH+17-1:0] val;
    begin
        if (val < 0)
            gain_shift_trunc = -((-val) >>> 16);
        else
            gain_shift_trunc = val >>> 16;
    end
endfunction
 
// ----------------------------------------------------------------------------
// Output Assignment
// Assigns the fully rotated, normalized, and truncated values to the output ports.
// ----------------------------------------------------------------------------
assign x_out = gain_shift_trunc(x_gain);
assign y_out = gain_shift_trunc(y_gain);
 
 
endmodule
