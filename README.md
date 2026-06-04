# CORDIC Phase Rotator Pipeline

## System Purpose & Overview
[cite_start]This repository contains the RTL design and functional verification environment for a CORDIC (Coordinate Rotation Digital Computer) Phase Shifter[cite: 162, 421]. [cite_start]The CORDIC algorithm is widely used in Digital Signal Processing (DSP) and communication systems to perform complex trigonometric phase rotations using only highly efficient hardware operations: additions, subtractions, and bit-shifts[cite: 164, 422]. 

[cite_start]The module receives a Cartesian vector `(x, y)` and a target angle `p`, and iteratively rotates the vector to the new phase while preserving its original amplitude[cite: 165, 434].

---

## Micro-Architecture Details
[cite_start]The design is implemented in Verilog using a fully synchronous, unrolled Pipeline architecture to achieve high data throughput (one valid output per clock cycle)[cite: 162, 275].

### Key Hardware Implementations:
* [cite_start]**Parameterized Pipeline:** The design utilizes Verilog `generate` blocks to physically unroll `n` CORDIC iteration stages (default is 20 stages)[cite: 219, 271, 278]. [cite_start]Data propagates from stage `i` to `i+1` on every rising clock edge[cite: 275].
* **Arctangent LUT:** A hard-coded Look-Up Table (LUT) stores pre-calculated phase step values (representing $arctan(2^{-i})$). [cite_start]At each pipeline stage, the hardware evaluates the remaining phase error and determines whether to rotate positively or negatively, fetching the corresponding angle correction from the LUT[cite: 166, 277].
* **Custom Truncation Logic:** To ensure exact parity with software models, a dedicated arithmetic right-shift function (`div_pow2_trunc`) was implemented. [cite_start]This function explicitly handles negative numbers by truncating towards zero rather than applying standard floor rounding[cite: 277].
* [cite_start]**Gain Compensation:** A mathematical byproduct of the CORDIC rotation is an amplitude gain of approximately ~1.6467[cite: 276, 475]. [cite_start]The final hardware stage normalizes the vector by multiplying it by the inverse factor (~0.6072, represented optimally as the integer `39787` for bit-shifting operations)[cite: 276].
* [cite_start]**Bit-Width Expansion:** Internal data paths (`x_pipe`, `y_pipe`) are expanded by 2 bits (`XY_WIDTH = 10`) compared to the input width (`8 bits`) to safely accommodate the inherent amplitude growth during intermediate rotation stages without overflow[cite: 272, 474].

---

## Verification Environment
[cite_start]A rigorous testbench (`cordic_phase_shifter_tb.v`) was developed to validate the RTL against a Golden Model written in Python[cite: 162, 426].

* [cite_start]**File-Based I/O:** The verification suite uses the `$readmemh` system task to dynamically load pre-generated test vectors (inputs and expected outputs) from external hex files into the testbench memory arrays[cite: 382, 461].
* [cite_start]**Throughput & Pipeline Stress-Testing:** The testbench drives continuous, back-to-back input stimulus into the module on every clock cycle, verifying the pipeline's ability to operate under maximum load without data corruption[cite: 385].
* [cite_start]**Latency Tracking & Automated Checking:** The verification environment explicitly accounts for the hardware latency of 21 clock cycles[cite: 287, 386]. [cite_start]Once the pipeline is full, it performs a strict, cycle-by-cycle exact match comparison (`!==`) between the DUT outputs and the expected Golden Model vectors, ensuring 100% precision[cite: 363, 387].

---

## Simulation Setup
Ensure all source Verilog files and the generated `.mem` test vector files are located in the same directory. The code is fully synthesizable and compatible with standard industry simulators.

Example execution using Cadence XRUN/Xcelium:
`xrun -sv cordic_phase_shifter_tb.v cordic_phase_shifter.v`
