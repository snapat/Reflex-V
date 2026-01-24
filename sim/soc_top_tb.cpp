#include "Vsoc_top.h"
#include "Vsoc_top___024root.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <iomanip>
#include <fstream>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    
    Vsoc_top *dut = new Vsoc_top;
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    dut->clock = 0;
    dut->resetActiveLow = 0;

    std::cout << "\033[1;32m[Sim] HPEC RISC-V System Started (Single Cycle).\033[0m" << std::endl;
    std::cout << "[Sim] UART Output will appear below..." << std::endl;
    std::cout << "---------------------------------------------" << std::endl;

    // Run for 1,000,000 ticks
    long int MAX_TICKS = 100000*5*8; 

    // State trackers
    bool prev_io_valid = 0; 
    bool prev_timer_irq = 0;

    for (long int i = 0; i < MAX_TICKS; i++) {
        dut->clock ^= 1; 
        
        // Reset Logic
        if (i > 20) dut->resetActiveLow = 1;

        dut->eval();
        m_trace->dump((vluint64_t)i);

        // LOGIC ON RISING EDGE
        if (dut->clock == 1) {
             
             // --- 1. UART SPY (Print output characters) ---
             bool curr_io_valid = dut->rootp->soc_top__DOT__ioWriteValid;
             if (curr_io_valid && !prev_io_valid && 
                 dut->rootp->soc_top__DOT__ioWriteAddress == 0x40000000) {
                 char c = (char)dut->rootp->soc_top__DOT__ioWriteData;
                 std::cout << c << std::flush; 
             }
             prev_io_valid = curr_io_valid;

             // --- 2. INTERRUPT DETECTOR (The Metronome) ---
             // We detect the RISING EDGE of the timerInterrupt signal.
             bool curr_timer_irq = dut->rootp->soc_top__DOT__timerInterrupt;

             if (curr_timer_irq && !prev_timer_irq) {
                uint32_t current_pc = dut->rootp->soc_top__DOT__programCounter;
                
                // MATH: If you used clockDivider[2], divide by 16. 
                // If you are purely single cycle 1:1, divide by 2.
                // Assuming you kept the divider logic for simulation speed:
                long int current_cycle = i / 16; 

                std::cout << "\n\033[1;33m[EVENT] Hardware Interrupt at Cycle: " 
                          << std::dec << std::setw(6) << current_cycle 
                          << " | PC: 0x" << std::hex << std::setw(8) << std::setfill('0') << current_pc 
                          << "\033[0m" << std::endl; 
             }
             prev_timer_irq = curr_timer_irq;
        }
    }

    std::cout << "\n---------------------------------------------" << std::endl;
    std::cout << "\033[1;32m[Sim] Simulation Complete.\033[0m" << std::endl;

    m_trace->close();
    delete dut;
    return 0;
}