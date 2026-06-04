`timescale 1ns / 1ps

// ============================================================================
// Module: cordic_phase_shifter_tb
// Description: Testbench for the pipelined CORDIC phase shifter.
// It loads test vectors from files, feeds them continuously into the pipeline,
// and automatically verifies the outputs after the pipeline latency.
// ============================================================================
module cordic_phase_shifter_tb();

// ----------------------------------------------------------------------------
// Testbench Parameters
// ----------------------------------------------------------------------------
parameter n = 20;                   // Number of CORDIC stages
parameter XY_WIDTH = 10;            // Internal data width
parameter PHASE_WIDTH = 16;         // Phase data width
parameter XY_INPUT_WIDTH = 8;       // Input data width
parameter NUM_TESTS = 20;           // Total number of test vectors to run
parameter LATENCY = 21;             // Clock cycles to wait for the first valid output (n stages + 1 input register)

// ----------------------------------------------------------------------------
// Testbench Signals (Drivers and Monitors)
// ----------------------------------------------------------------------------
reg signed [XY_INPUT_WIDTH-1:0] x;
reg signed [XY_INPUT_WIDTH-1:0] y;
reg clk;
reg rst;
reg signed [PHASE_WIDTH-1:0] p;
    
wire signed [XY_WIDTH-1:0] x_out;
wire signed [XY_WIDTH-1:0] y_out;

// ----------------------------------------------------------------------------
// Memory Arrays for Test Vectors
// These arrays act as ROMs holding the inputs and the expected outputs.
// ----------------------------------------------------------------------------
reg signed [7:0]  x_mem     [0:NUM_TESTS-1];
reg signed [7:0]  y_mem     [0:NUM_TESTS-1];
reg signed [15:0] p_mem     [0:NUM_TESTS-1];
reg signed [9:0]  x_exp_mem [0:NUM_TESTS-1];
reg signed [9:0]  y_exp_mem [0:NUM_TESTS-1];

integer i;      // Loop variable for stimulus injection
integer j;      // Loop variable for output checking
integer errors; // Counter for mismatched results
 
// ----------------------------------------------------------------------------
// Unit Under Test (UUT) Instantiation
// Connecting the testbench signals to the CORDIC hardware module.
// ----------------------------------------------------------------------------
cordic_phase_shifter #(
    .n(n),
    .XY_WIDTH(XY_WIDTH),
    .XY_INPUT_WIDTH(XY_INPUT_WIDTH),
    .PHASE_WIDTH(PHASE_WIDTH)
)UUT(
    .x(x),
    .y(y),
    .p(p),
    .clk(clk),
    .rst(rst),
    .x_out(x_out),
    .y_out(y_out)
);

// ----------------------------------------------------------------------------
// Clock Generation
// Creates a clock with a 10ns period (5ns high, 5ns low).
// ----------------------------------------------------------------------------
always #5 clk = !clk;

// ----------------------------------------------------------------------------
// Block 1: Setup, File Reading, and Reset Sequence
// ----------------------------------------------------------------------------
initial begin
    // Load test data from external hex files into the memory arrays
    $readmemh("x_in.mem", x_mem);
    $readmemh("y_in.mem", y_mem);
    $readmemh("p_in.mem", p_mem);
    $readmemh("x_out.mem", x_exp_mem);
    $readmemh("y_out.mem", y_exp_mem);

    // Initialize clock, reset, and input signals
    clk = 0;
    rst = 1;
    x = 8'sd0;
    y = 8'sd0;
    p = 16'sd0;
    errors = 0;

    // Hold reset HIGH for 3 clock cycles to ensure all pipeline stages clear
    repeat (3) @(posedge clk);
        // Release reset on the negative edge to avoid race conditions with the clock
        @(negedge clk); 
        rst = 0;
    end

// ----------------------------------------------------------------------------
// Block 2: Stimulus Injection (Input Driver)
// Feeds a new set of data into the pipeline on every rising clock edge.
// ----------------------------------------------------------------------------
initial begin
    // Wait for the reset to be completely removed
    @(negedge rst);

    // Loop through all test vectors and inject them one by one
    for (i = 0; i < NUM_TESTS; i = i + 1) begin
        @(posedge clk); // Synchronize to the clock
        x <= x_mem[i];  // Non-blocking assignments model hardware flip-flop behavior
        y <= y_mem[i];
        p <= p_mem[i];
    end

    // After sending all vectors, clear the input buses
    @(posedge clk);
        x <= 0;
        y <= 0;
        p <= 0;
end

// ----------------------------------------------------------------------------
// Block 3: Output Monitor and Checker
// Waits for the pipeline to fill, then compares outputs to expected results.
// ----------------------------------------------------------------------------
initial begin
    // Wait for reset to be removed
    @(negedge rst);
    
    // Wait for the initial latency (time it takes for the first data to travel through the pipe)
    repeat (LATENCY) @(posedge clk);
    
    // Check the outputs against the expected memory cycle by cycle
    for (j = 0; j < NUM_TESTS; j = j + 1) begin
            @(posedge clk);
            #1; // Delay 1ns after clock edge to ensure data has propagated and stabilized
            
        // Hard comparison (!==) checks for exact match, including X or Z states
        if ((x_out !== x_exp_mem[j]) || (y_out !== y_exp_mem[j])) begin
            $display("ERROR test %0d: expected x=%0d, y=%0d | got x=%0d, y=%0d", j, x_exp_mem[j], y_exp_mem[j], x_out, y_out);
            errors = errors + 1; // Increment error counter if mismatch found
            end
        end
        
        // Final Simulation Report
        if (errors == 0) begin
            $display("FINAL RESULT: PASS, All %0d pipelined tests passed.", NUM_TESTS);
        end else begin
            $display("FINAL RESULT: FAIL, %0d errors.", errors);
        end

        // End the simulation
        $finish;
    end    

endmodule
