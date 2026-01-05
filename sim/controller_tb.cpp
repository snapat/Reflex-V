#include "Vcontroller.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>

int main(int argc, char **argv) {
    // 1. Setup the Simulation
    Verilated::commandArgs(argc, argv);
    Vcontroller* dut = new Vcontroller;   // Create your Controller "Device Under Test"
    
    // 2. Setup the Waveform file (for GTKWave)
    Verilated::traceEverOn(true);
    VerilatedVcdC* trace = new VerilatedVcdC;
    dut->trace(trace, 5);
    trace->open("controller_wave.vcd");

    vluint64_t time = 0; // Simulation clock

    std::cout << "--- STARTING SIMPLE TESTS ---" << std::endl;

    // --- TEST 1: ADD Instruction (R-Type) ---
    dut->opcode    = 0b0110011; // Opcode for Math
    dut->funct3 = 0b000;     // Funct3 for ADD/SUB
    dut->funct7 = 0b0000000; // Funct7 for ADD
    
    dut->eval();                // Run logic
    trace->dump(time++);        // Save to waveform
    
    std::cout << "Test ADD:  ALU Control should be 0. Actual: " 
              << (int)dut->aluControlSignal << std::endl;


    // --- TEST 2: SUB Instruction (R-Type) ---
    dut->opcode    = 0b0110011; 
    dut->funct3 = 0b000;     
    dut->funct7 = 0b0100000; // Bit 5 is HIGH -> Meaning SUB
    
    dut->eval();
    trace->dump(time++);
    
    std::cout << "Test SUB:  ALU Control should be 1. Actual: " 
              << (int)dut->aluControlSignal << std::endl;


    // --- TEST 3: LOAD Instruction ---
    dut->opcode    = 0b0000011; // Opcode for Load
    dut->funct3 = 0b010;     // LW
    dut->funct7 = 0b0000000; 

    dut->eval();
    trace->dump(time++);

    std::cout << "Test LW:   Result Source should be 1 (Memory). Actual: " 
              << (int)dut->resultSource << std::endl;


    // --- TEST 4: BRANCH Instruction ---
    dut->opcode    = 0b1100011; // Opcode for Branch
    
    dut->eval();
    trace->dump(time++);

    std::cout << "Test BEQ:  Is Branch should be 1. Actual: " 
              << (int)dut->isBranch << std::endl;

    // Finish
    trace->close();
    delete dut;
    return 0;
}