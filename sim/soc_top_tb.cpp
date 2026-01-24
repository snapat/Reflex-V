#include "Vsoc_top.h"
#include "Vsoc_top___024root.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <iomanip>

/**
 * @brief RISC-V SoC Verification Environment
 * Monitors MMIO bus transactions, hardware exceptions, and instruction flow.
 */
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    
    Vsoc_top *dut = new Vsoc_top;
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    
    // Waveform configuration
    dut->trace(m_trace, 5);
    m_trace->open("simulation_trace.vcd");

    // Initial hardware state
    dut->clock = 0;
    dut->resetActiveLow = 0;

    std::cout << "\033[1;32m[SYS] Initializing RV32I SoC Simulation...\033[0m" << std::endl;
    std::cout << "[SYS] Monitoring UART MMIO (0x40000000)" << std::endl;
    std::cout << "---------------------------------------------" << std::endl;

    // Simulation timing: Scaled for 12.5 MHz CPU frequency
    const long int MAX_SIM_TICKS = 1000000; 

    // Edge detection registers
    bool lastWriteValid = false; 
    bool lastTimerIrq   = false;

    for (long int tick = 0; tick < MAX_SIM_TICKS; tick++) {
        dut->clock ^= 1; // System clock toggle
        
        // Asynchronous reset release
        if (tick > 20) dut->resetActiveLow = 1;

        dut->eval();
        m_trace->dump((vluint64_t)tick);

        // Synchronous logic monitoring (Rising Edge)
        if (dut->clock == 1) {
             
             // --- 1. MMIO BUS MONITOR (UART Output) ---
             // Detects valid write cycles to the UART Transmit Buffer
             bool currentWriteValid = dut->rootp->soc_top__DOT__ioWriteValid;
             if (currentWriteValid && !lastWriteValid && 
                 dut->rootp->soc_top__DOT__ioWriteAddress == 0x40000000) {
                 char dataOut = (char)dut->rootp->soc_top__DOT__ioWriteData;
                 std::cout << dataOut << std::flush; 
             }
             lastWriteValid = currentWriteValid;

             // --- 2. HARDWARE INTERRUPT TRACKER ---
             // Monitors the rising edge of the Timer-Interrupt Service Request
             bool currentTimerIrq = dut->rootp->soc_top__DOT__timerInterrupt;
             if (currentTimerIrq && !lastTimerIrq) {
                uint32_t trapPC = dut->rootp->soc_top__DOT__programCounter;
                
                // Effective Cycle Calculation: Tick / (2 * ClockDivider)
                long int cpuCycle = tick / 16; 

                std::cout << "\n\033[1;33m[IRQ] Timer Trap at Cycle: " 
                          << std::dec << std::setw(6) << cpuCycle 
                          << " | Vector PC: 0x" << std::hex << std::setw(8) << std::setfill('0') << trapPC 
                          << "\033[0m" << std::endl; 
             }
             lastTimerIrq = currentTimerIrq;
        }
    }

    std::cout << "\n---------------------------------------------" << std::endl;
    std::cout << "\033[1;32m[SYS] Simulation Terminated Successfully.\033[0m" << std::endl;

    m_trace->close();
    delete dut;
    return 0;
}