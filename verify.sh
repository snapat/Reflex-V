#!/bin/bash

# --- 1. Create the C++ Testbench (alu_tb.cpp) ---
echo "--- STEP 0: WRITING TESTBENCH ---"
cat << 'CPP' > sim/alu_tb.cpp
#include "Valu.h"               // The verilated ALU module
#include "verilated.h"          // Verilator standard library
#include "verilated_vcd_c.h"    // Waveform tracing
#include <iostream>

// Helper function to print colorful Pass/Fail messages
void check(int expected, int actual, const char* testName) {
    if (expected == actual) {
        std::cout << " \033[32m[PASS]\033[0m " << testName 
                  << " | Expected: " << expected << " Got: " << actual << std::endl;
    } else {
        std::cout << " \033[31m[FAIL]\033[0m " << testName 
                  << " | Expected: " << expected << " Got: " << actual << std::endl;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    // Instantiate the ALU
    Valu* top = new Valu;
    
    // Setup Waveform Dumping
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("alu.vcd");

    int timeStep = 0;

    // --- TEST 1: ADD (10 + 5) ---
    top->aluControl = 0; // 000 = ADD
    top->inputA = 10;    // Using your custom names
    top->inputB = 5;
    top->eval(); tfp->dump(timeStep++);
    check(15, top->aluResult, "ADD (10+5)");

    // --- TEST 2: SUB (10 - 5) ---
    top->aluControl = 1; // 001 = SUB
    top->inputA = 10; 
    top->inputB = 5;
    top->eval(); tfp->dump(timeStep++);
    check(5, top->aluResult, "SUB (10-5)");

    // --- TEST 3: AND (Masking) ---
    top->aluControl = 2; // 010 = AND
    top->inputA = 0xFF; 
    top->inputB = 0x0F;
    top->eval(); tfp->dump(timeStep++);
    check(0x0F, top->aluResult, "AND (FF & 0F)");

    // --- TEST 4: OR (Combining) ---
    top->aluControl = 3; // 011 = OR
    top->inputA = 0xF0; 
    top->inputB = 0x0F;
    top->eval(); tfp->dump(timeStep++);
    check(0xFF, top->aluResult, "OR (F0 | 0F)");

    // --- TEST 5: XOR (Inversion) ---
    top->aluControl = 4; // 100 = XOR
    top->inputA = 0xFF; 
    top->inputB = 0xFF;
    top->eval(); tfp->dump(timeStep++);
    check(0x00, top->aluResult, "XOR (FF ^ FF)");

    // --- TEST 6: SLT (Set Less Than) ---
    top->aluControl = 5; // 101 = SLT
    top->inputA = 10; 
    top->inputB = 20;
    top->eval(); tfp->dump(timeStep++);
    check(1, top->aluResult, "SLT (10 < 20)");

    // --- TEST 7: Zero Flag Check ---
    top->aluControl = 1; // SUB
    top->inputA = 50; 
    top->inputB = 50;
    top->eval(); tfp->dump(timeStep++);
    
    if (top->zero == 1) std::cout << " \033[32m[PASS]\033[0m Zero Flag (50-50)" << std::endl;
    else std::cout << " \033[31m[FAIL]\033[0m Zero Flag (Expected 1, Got 0)" << std::endl;

    tfp->close();
    delete top;
    return 0;
}
CPP

# --- 2. Compile & Run ---
echo "--- STEP 1: COMPILING ---"
rm -rf obj_dir *.vcd
# Note: Pointing to sim/alu_tb.cpp now
verilator --cc rtl/alu.sv --exe sim/alu_tb.cpp --trace -Irtl
make -C obj_dir -f Valu.mk > /dev/null

echo "--- STEP 2: RUNNING SIMULATION ---"
./obj_dir/Valu

echo ""
echo "Note: If you want to see waves, run: gtkwave alu.vcd"
