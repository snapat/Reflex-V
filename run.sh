#!/bin/bash

# Check if user provided a module name (e.g., ./run.sh alu)
if [ -z "$1" ]; then
    echo "Error: Please provide a module name."
    echo "Usage: ./run.sh alu  OR  ./run.sh regfile"
    exit 1
fi

MODULE=$1

# Cleanup
rm -rf obj_dir
rm -f *.vcd

echo "--- BUILDING MODULE: $MODULE ---"

# 1. Compile (Generic)
# It looks for rtl/[NAME].sv and sim/[NAME]_tb.cpp automatically
verilator --cc rtl/$MODULE.sv --exe sim/${MODULE}_tb.cpp --trace -Irtl --top-module $MODULE

# 2. Build (Generic)
# Verilator always adds a "V" to the makefile name (e.g., Valu.mk)
make -C obj_dir -f V$MODULE.mk > /dev/null

# 3. Run (Generic)
if [ -f ./obj_dir/V$MODULE ]; then
    echo "--- RUNNING SIMULATION ---"
    ./obj_dir/V$MODULE
else
    echo "Build Failed!"
    exit 1
fi
