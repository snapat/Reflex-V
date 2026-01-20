#include "Vsoc_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>

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

    std::cout << "[Sim] Starting Simulation..." << std::endl;

    // Simulation Loop (Run for 2000 ticks)
    // At 50 cycles per context switch, this captures ~20 switches (Round Robin).
    for (int i = 0; i < 2000; i++) {
        // Toggle Clock (Rising/Falling Edge)
        dut->clock ^= 1; 

        // Release Reset after 10 ticks (5 clock cycles)
        if (i > 10) dut->resetActiveLow = 1;

        // Evaluate the Logic and Dump to Waveform
        dut->eval();
        m_trace->dump(i);
    }

    std::cout << "[Sim] Simulation Complete. Waveform saved to 'waveform.vcd'." << std::endl;

    // Cleanup
    m_trace->close();
    delete dut;
    exit(0);
}