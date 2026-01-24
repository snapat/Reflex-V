#include <stdint.h>
#include "print.h"

// --- KERNEL MEMORY MAP ---
#define TASK_PCS          ((volatile uint32_t *)0x20000000)
#define TASK_SPS          ((volatile uint32_t *)0x20000008)
#define CURRENT_TASK_PTR  ((volatile uint32_t *)0x20000010)

void task_A(void) {
    while (1) {
        print_str("A");
        // Delay loop so we don't spam too fast
        for (volatile int i = 0; i < 10000; i++); 
    }
}

void task_B(void) {
    while (1) {
        print_str("B");
        for (volatile int i = 0; i < 10000; i++);
    }
}

int main() {
    print_str("\n[BOOT] Context Switcher Demo\n");

    // 1. Initialize Kernel Data
    TASK_PCS[0] = (uint32_t)task_A;
    TASK_PCS[1] = (uint32_t)task_B;
    *CURRENT_TASK_PTR = 0;

    // 2. Initialize Task B Stack
    uint32_t* stackB = (uint32_t*)(0x20000800);
    uint32_t* sp_B = stackB - 32; 
    sp_B[0] = (uint32_t)task_B; // Set Return Address
    TASK_SPS[1] = (uint32_t)sp_B; 

    print_str("[INFO] Starting Task A...\n");
    task_A(); 
    return 0;
}