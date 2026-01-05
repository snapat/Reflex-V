#include "Vregfile.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    // Instantiate the Register File
    Vregfile* top = new Vregfile;
    VerilatedVcdC* tfp = new VerilatedVcdC;

    top->trace(tfp, 99);
    tfp->open("regfile_trace.vcd");

    // Simulation Loop (100 clock cycles)
    for (int i = 0; i < 20; i++) {
        // Toggle Clock
        top->clock = !top->clock;
        
        // Write to Register x1 on cycle 4
        if (i == 4) {
            top->registerWriteEnable = 1;
            top->writeAddress = 1;
            top->writeData = 0xDEADBEEF;
        } else {
            top->registerWriteEnable = 0;
        }

        // Read Register x1 on cycle 8
        if (i == 8) {
             top->readAddress0 = 1;
        }

        top->eval();
        tfp->dump(i);
    }

    tfp->close();
    delete top;
    return 0;
}