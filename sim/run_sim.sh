#!/bin/bash
# ============================================================
# Script: run_sim.sh
# Project: 2D FIR Digital Differentiator for Image Edge Detection
# Description: Automated compilation and simulation script using Icarus Verilog
# ============================================================

echo "Compiling RTL and Testbench using Icarus Verilog..."
iverilog -o sim.vvp ../rtl/fir_1d_pipeline.v ../rtl/fir_2d_edge_pipeline.v ../tb/tb_fir_2d_edge_pipeline.v

if [ $? -eq 0 ]; then
    echo "Compilation successful. Executing simulation..."
    vvp sim.vvp
    echo "Simulation finished. Waveform file 'tb_fir_2d_edge_pipeline.vcd' generated."
    echo "To view waveform in GTKWave, run: gtkwave tb_fir_2d_edge_pipeline.vcd"
else
    echo "Compilation failed."
    exit 1
fi
