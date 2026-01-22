#ifndef PRINT_H
#define PRINT_H

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
    while (*s) {
        uart_putc(*s++);
    }
}

#endif