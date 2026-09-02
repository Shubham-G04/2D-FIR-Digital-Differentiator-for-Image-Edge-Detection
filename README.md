# 2D FIR Digital Differentiator for Real-Time Image Edge Detection

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![HDL: Verilog](https://img.shields.io/badge/HDL-Verilog_2001-green.svg)](rtl/)
[![ASIC: GPDK 180nm](https://img.shields.io/badge/ASIC_Synthesis-Cadence_Genus_180nm-orange.svg)](docs/)
[![FPGA: Kintex--7](https://img.shields.io/badge/FPGA-Xilinx_Kintex--7-red.svg)](docs/)

> **Academic Project** | 6th Semester VLSI Digital Signal Processing (VLSI DSP)  
> **Authors:** [Sanjay](https://github.com/Sanjay1356) & [Shubham Gupta](https://github.com/Shubham-G04)  
> **Source Repository:** [Sanjay1356/VLSIDSP](https://github.com/Sanjay1356/VLSIDSP)

---

## 📌 Executive Summary

This repository presents the hardware design, timing optimization, and dual-flow hardware synthesis of a **5-Tap Separable 2D FIR Digital Differentiator** tailored for real-time image edge detection. Edge detection is a fundamental operation in computer vision and image processing pipelines (e.g., ADAS video processing, medical imaging, spatial filtering) that identifies abrupt changes in pixel intensity.

To overcome the heavy timing constraints of traditional combinational datapaths in high-frequency video streaming applications, we applied **Cut-Set Pipelining Transformation (2 Cut Sets)** to partition the Data Flow Graph (DFG) into a **3-stage pipelined architecture**. 

Both **Combinational (Non-Pipelined)** and **3-Stage Pipelined** RTL variants were implemented in Verilog-2001 and subjected to a rigorous **Power, Performance, and Area (PPA) Trade-off Analysis** across both ASIC (**Cadence Genus @ GPDK 180nm**) and FPGA (**Xilinx Kintex-7 @ Vivado 2024.2**) flows.

---

## 🏗️ Hardware Architecture & Mathematical Foundation

### 1. Spatial Gradient & Filter Coefficients
The digital differentiator is implemented as a 5-tap high-pass FIR filter with odd-symmetric coefficients designed for zero DC gain and linear phase response:

$$h[n] = \frac{1}{8} \begin{bmatrix} -1 & -2 & 0 & +2 & +1 \end{bmatrix}$$

Transfer function in the Z-domain:
$$H(z) = \frac{1}{8} \left( -1 - 2z^{-1} + 0z^{-2} + 2z^{-3} + z^{-4} \right)$$

### 2. Separable 2D Gradient Approximator
Full 2D spatial convolution with an $N \times M$ kernel requires $N \times M$ multiplications per pixel. To minimize silicon area and multiplier count, a **separable 2D filtering approach** is used. Horizontal gradient $G_x(i,j)$ and vertical gradient $G_y(i,j)$ are calculated concurrently via identical 1D FIR differentiator modules:

$$|G(i,j)| = |G_x(i,j)| + |G_y(i,j)|$$

The output magnitude is saturated to an 8-bit unsigned pixel range $[0, 255]$.

---

## ⚡ Cut-Set Pipelining Transformation (2 Cut Sets)

### 1. Theoretical Background (Keshab K. Parhi's Cut-Set Theorem)
In VLSI Digital Signal Processing system design, **Pipelining** reduces the critical path $T_{\text{crit}}$ of a Data Flow Graph (DFG) by inserting flip-flops/registers along feed-forward cut sets:

* **Cut Set Definition:** A set of edges in a DFG whose removal divides the graph into two disjoint subgraphs: a source (transmitting) subgraph $G_1$ and a sink (receiving) subgraph $G_2$.
* **Feed-Forward Cut Set Rule:** If $k$ delay elements ($k \cdot D$) are inserted into every edge pointing from $G_1 \to G_2$, the mathematical transfer function of the DFG remains completely invariant, while introducing an overall system input-to-output latency of $k$ clock cycles.

### 2. Application of 2 Cut Sets to the FIR Datapath

In the original un-pipelined architecture, the shift register update, signed coefficient multiplication, 5-input adder tree, arithmetic $\frac{1}{8}$ scaling, and absolute magnitude computation all occurred in a single continuous combinational propagation path:

$$T_{\text{crit,comb}} = T_{\text{shift}} + T_{\text{mult}} + T_{\text{adder}} + T_{\text{scale}}$$

By applying **2 feed-forward cut sets**, we partition the DFG into **3 balanced pipeline stages**:

```text
               +-----------------------------------------------------------------------------------+
               |                               STAGE 1: SHIFT REGISTER                             |
               |  Pixel In ---> [sr[0]] ---> [sr[1]] ---> [sr[2]] ---> [sr[3]] ---> [sr[4]]        |
               +-----------------------------------------------------------------------------------+
                                      |            |            |            |            |
======================================|============|============|============|============|=================
⚡ CUT SET 1 (Delay Line Boundary)    v            v            v            v            v
======================================|============|============|============|============|=================
               +----------------------|------------|------------|------------|------------|----+
               |                      v            v            v            v            v    |
               |               STAGE 2: MULTIPLIERS (Coefficient Scaling)                      |
               |                     (x -1)       (x -2)       (x 0)        (x +2)       (x +1) |
               |                       |            |            |            |            |   |
               |                       v            v            v            v            v   |
               |                     [p0]         [p1]         [p2]         [p3]         [p4]  |
               +-----------------------------------------------------------------------------------+
                                       |            |            |            |            |
=======================================|============|============|============|============|================
⚡ CUT SET 2 (Product Boundary)       v            v            v            v            v
=======================================|============|============|============|============|================
               +-----------------------|------------|------------|------------|------------|---+
               |                       v            v            v            v            v   |
               |               STAGE 3: ADDER TREE, SCALING & SATURATION                           |
               |                                                                                   |
               |                      sum = p0 + p1 + p2 + p3 + p4                                 |
               |                      y_out = (|sum| >>> 3)                                        |
               |                      edge_out = min(255, |Gx| + |Gy|)                            |
               +-----------------------------------------------------------------------------------+
```

#### Pipeline Stage Detailed Breakdown:
* **Stage 1 (Tapped Delay Line):** Samples input pixel `x_in` into 5-tap shift register array (`sr[0:4]`).
* **Stage 2 (Coefficient Multipliers):** Multiplies tap outputs by coefficients into signed 12-bit registers (`p0` through `p4`).
* **Stage 3 (Accumulation & Saturation):** Computes signed sum, performs arithmetic right shift (`>>> 3`), calculates absolute magnitude, and saturates combined 2D output to 8 bits.

#### Key Architectural Gains:
* **Critical Path Reduction:** Reduced from $T_{\text{crit,comb}}$ to $T_{\text{crit,pipe}} = \max(T_{\text{stage1}}, T_{\text{stage2}}, T_{\text{stage3}})$.
* **Latency:** 3 clock cycles.
* **Throughput:** Real-time continuous processing of **1 pixel / clock cycle**.

---

## 📊 ASIC Synthesis & PPA Trade-Off Analysis (GPDK 180nm)

Both RTL variants were synthesized targeting the **GPDK 180nm standard-cell library** using **Cadence Genus** at a target clock frequency of **100 MHz (10 ns clock period)**.

| Metric | Pipelined (3-Stage) | Non-Pipelined (Combinational) | Trade-Off / Impact |
| :--- | :--- | :--- | :--- |
| **Cell Area** | **13,601.65 µm²** | **6,243.65 µm²** | **2.18x Area Overhead** (Inserted pipeline registers) |
| **Total Power** | **1.297 mW** | **0.607 mW** | **2.14x Power Overhead** (Dynamic clocking of registers) |
| **Critical Path Delay** | **4,489 ps** | **4,672 ps** | **4.0% Faster Propagation Delay** |
| **Setup Slack** | **+5,220 ps (MET)** | **+4,362 ps (MET)** | **+858 ps Higher Slack Margin** |
| **Throughput** | **1 pixel / cycle** | Variable / Lower | **Essential for Continuous Video Streaming** |

> 💡 **PPA Insight:** While 2 Cut-Sets Pipelining doubles the silicon area and power consumption due to flip-flop insertion, it provides structural timing closure headroom, eliminates glitching on output adders, and enables continuous throughput necessary for real-time HD video streams.

---

## 📟 FPGA Implementation (Xilinx Kintex-7)

The pipelined 2D edge differentiator was implemented on a **Xilinx Kintex-7 FPGA (`xc7k70tfbv676-1`)** using **Xilinx Vivado 2024.2**:

* **Routing Status:** 0 failed routes post `route_design`.
* **Timing Closure:** All setup and hold timing constraints met at 100 MHz.
* **On-Chip Power Estimation:** Total dynamic power estimated at **6.997 W** (primarily driven by high-speed I/O termination buffers).

---

## 📁 Repository Structure

```text
2D-FIR-Digital-Differentiator-for-Image-Edge-Detection/
├── rtl/
│   ├── fir_1d_nopipeline.v       # 5-Tap Direct Form 1D FIR (Combinational)
│   ├── fir_1d_pipeline.v         # 5-Tap 3-Stage Pipelined 1D FIR (2 Cut-Sets Applied)
│   ├── fir_2d_edge_nopipeline.v  # Top-Level 2D Edge Detector (Non-Pipelined)
│   └── fir_2d_edge_pipeline.v    # Top-Level 2D Edge Detector (Pipelined)
├── tb/
│   └── tb_fir_2d_edge_pipeline.v # Verification Testbench (Flat, Step, Ramp, Impulse)
├── sim/
│   └── run_sim.sh                # Automated compilation & execution script
├── .gitignore                    # EDA tool & simulation output filters
└── README.md                     # Project documentation & Cut-Set Pipelining analysis
```

---

## 3. Verification & Simulation Guide

### Prerequisites
* [Icarus Verilog (`iverilog`)](http://iverilog.icarus.com/)
* [GTKWave Waveform Viewer](http://gtkwave.sourceforge.net/)

### Running Simulation Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Shubham-G04/2D-FIR-Digital-Differentiator-for-Image-Edge-Detection.git
   cd 2D-FIR-Digital-Differentiator-for-Image-Edge-Detection
   ```

2. **Compile and execute simulation:**
   ```bash
   # Using the automated simulation script
   cd sim
   chmod +x run_sim.sh
   ./run_sim.sh
   ```
   *Alternatively, run directly with iverilog:*
   ```bash
   iverilog -o sim.vvp rtl/fir_1d_pipeline.v rtl/fir_2d_edge_pipeline.v tb/tb_fir_2d_edge_pipeline.v
   vvp sim.vvp
   ```

3. **View Waveform Output:**
   ```bash
   gtkwave tb_fir_2d_edge_pipeline.vcd
   ```

### Testbench Scenarios Verified
1. **Flat Region Test:** Uniform pixel values ($x = 100$) $\to$ Outputs $0$ after pipeline fill (Zero DC gain verified).
2. **Step Edge Test:** Sudden intensity jump ($0 \to 200$) $\to$ High magnitude peak detected.
3. **Ramp Edge Test:** Gradual slope ($0, 10, 20, \dots, 90$) $\to$ Constant spatial derivative output.
4. **Impulse Test:** Single pixel spike ($x = 8$) $\to$ Impulse response verified.

---

## 🤝 Authors & Credits

* **Sanjay** ([@Sanjay1356](https://github.com/Sanjay1356))
* **Shubham Gupta** ([@Shubham-G04](https://github.com/Shubham-G04))

*Developed as part of the 6th Semester VLSI Digital Signal Processing (VLSI DSP) course project.*
