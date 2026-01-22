#!/bin/bash

# Ensure this script and config are executable
chmod +x "$0" 
if [ -f "./config.sh" ]; then
    chmod +x ./config.sh
    source ./config.sh
else
    echo "Error: config.sh not found."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: ./run.sh <module_name>"
    echo "Example: ./run.sh soc_top"
    exit 1
fi

MODULE=$1

# ---------------------------------------------------------
# 1. COMPILE FIRMWARE
# ---------------------------------------------------------
# Only compile firmware if we are running the top-level SoC
if [ "$MODULE" == "soc_top" ]; then
    echo "--- BUILDING FIRMWARE ---"
    cd firmware
    make clean > /dev/null
    
    # Pass the toolchain variables to Make
    make CC="$CC" OBJCOPY="$OBJCOPY" CFLAGS="$CFLAGS" || { echo "Firmware build failed"; exit 1; }
    
    # --- NEW: SYMBOL TABLE DUMP ---
    # Attempt to use the cross-compiler 'nm' (e.g. riscv64-unknown-elf-nm)
    # We derive it by replacing 'gcc' with 'nm' in the CC variable.
    NM_TOOL="${CC%gcc}nm"
    
    echo "--- FIRMWARE SYMBOLS (DEBUG) ---"
    if command -v $NM_TOOL &> /dev/null; then
        $NM_TOOL --numeric-sort firmware.elf | grep -v " U "
    else
        # Fallback to system nm (might fail on some systems, but worth a try)
        nm --numeric-sort firmware.elf | grep -v " U "
    fi
    echo "--------------------------------"

    cd ..

    echo "--- GENERATING HEX ---"
    if [ -f "firmware/firmware.bin" ]; then
        # MacOS specific hexdump to format 32-bit hex words
        hexdump -v -e '1/4 "%08x" "\n"' firmware/firmware.bin > firmware/firmware.hex
        
        if [ ! -s firmware/firmware.hex ]; then
            echo "Error: Generated firmware.hex is empty!"
            exit 1
        fi
    else
        echo "Error: firmware.bin was not generated."
        exit 1
    fi
fi

# ---------------------------------------------------------
# 2. RUN VERILATOR
# ---------------------------------------------------------
echo "--- SIMULATING $MODULE ---"

# Detect the Testbench File
# If module is soc_top, this looks for sim/soc_top_tb.cpp
TB_FILE="sim/${MODULE}_tb.cpp"

if [ ! -f "$TB_FILE" ]; then
    echo "Error: C++ Testbench not found at: $TB_FILE"
    exit 1
fi

# Clean previous build artifacts
rm -rf obj_dir
rm -f *.vcd

# Run Verilator
# --cc: Generate C++ output
# --exe: Link our custom C++ testbench
# --trace: Enable waveform generation
verilator --cc rtl/$MODULE.sv --exe $TB_FILE --trace -Irtl -Isim --top-module $MODULE

if [ $? -ne 0 ]; then
    echo "Verilator compilation failed!"
    exit 1
fi

# Build the C++ Simulation Binary
make -C obj_dir -f V$MODULE.mk > /dev/null

# Execute the Simulation
if [ -f ./obj_dir/V$MODULE ]; then
    echo "--- STARTING SIMULATION ---"
    ./obj_dir/V$MODULE
else
    echo "Build Failed at the Make stage!"
    exit 1
fi