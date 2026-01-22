#include "Vsoc_top.h"
// This header allows access to internal signals like the Program Counter
#include "Vsoc_top___024root.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <iomanip>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    // Instantiate the SoC
    Vsoc_top *dut = new Vsoc_top;

    // Set up Waveform Dumping
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // Initialize Signals
    dut->clock = 0;
    dut->resetActiveLow = 0; // Hold Reset initially

    std::cout << "\033[1;32m[Sim] HPEC RISC-V System Started.\033[0m" << std::endl;
    std::cout << "[Sim] UART Output will appear below..." << std::endl;
    std::cout << "---------------------------------------------" << std::endl;

    // Simulation Loop
    // Running for 200,000 ticks = 100,000 Clock Cycles
    // (Enough for ~20 context switches)
    long int MAX_TICKS = 200000;
    
    for (long int i = 0; i < MAX_TICKS; i++) {
        // Toggle Clock
        dut->clock ^= 1; 

        // Release Reset after 20 ticks
        if (i > 20) dut->resetActiveLow = 1;

        // Evaluate Logic
        dut->eval();
        
        // Dump Trace
        m_trace->dump((vluint64_t)i);

        // --- DASHBOARD LOGIC ---
        // We log status every 10,000 ticks (5,000 cycles)
        // We use std::endl instead of \r so we don't erase the 'A'/'B' output
        if (dut->clock == 1 && (i % 10000 == 0)) {
            // Access internal PC via rootp->soc_top__DOT__programCounter
            uint32_t current_pc = dut->rootp->soc_top__DOT__programCounter;
            
            std::cout << "[Sim] Cycle: " << std::dec << std::setw(6) << (i/2) 
                      << " | PC: 0x" << std::hex << std::setw(8) << std::setfill('0') << current_pc 
                      << " | LEDs: ";
            
            // Print LEDs
            for (int b = 7; b >= 0; b--) {
                std::cout << ((dut->debugLeds >> b) & 1 ? "*" : "."); 
            }
            std::cout << std::dec << std::endl; // New line preserves UART history
        }
    }

    std::cout << "---------------------------------------------" << std::endl;
    std::cout << "\033[1;32m[Sim] Simulation Complete.\033[0m Waveform saved to 'waveform.vcd'." << std::endl;

    // Cleanup
    m_trace->close();
    delete dut;
    return 0;
}