#include <stdint.h>


#include <stdint.h>

// UART Registers
#define UART_TX     (*(volatile uint32_t *)0x40000000)

// Helper: Write char to UART (Bypassing Busy Check for Simulation)
static inline void uart_putc(char c) {
    UART_TX = c;
    
    // Tiny software delay to let the Verilog $write block catch it
    // This prevents "overwriting" the bus before the simulator notices.
    for (volatile int i = 0; i < 5; i++); 
}

// Helper: Print a 32-bit integer as Hex (e.g., "1A2B3C4D")
static inline void print_hex(uint32_t val) {
    char hex_chars[] = "0123456789ABCDEF";
    uart_putc('0'); uart_putc('x');
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
    uart_putc(' '); // Space separator
}

// Helper: Print a simple string
static inline void print_str(const char* s) {

        uart_putc(*s++);

}


#define CSR_MEPC (*(volatile uint32_t *)0x40000010)

// Memory Map
#define TASK_PCS          ((volatile uint32_t *)0x20000000)
#define TASK_SPS          ((volatile uint32_t *)0x20000008)
#define CURRENT_TASK_PTR  ((volatile uint32_t *)0x20000010)

uint32_t scheduler(uint32_t current_sp) {
    int current_task = *CURRENT_TASK_PTR;

    // 1. Save Context
    TASK_SPS[current_task] = current_sp;
    TASK_PCS[current_task] = CSR_MEPC; 

    // 2. Toggle Task (0 -> 1 -> 0)
    int next_task = (current_task == 0) ? 1 : 0;
    
    // The scheduler must be fast.

    // 3. Restore Context
    *CURRENT_TASK_PTR = next_task;
    CSR_MEPC = TASK_PCS[next_task];
    
    return TASK_SPS[next_task];
}