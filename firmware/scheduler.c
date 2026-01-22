#include <stdint.h>
#include "print.h"

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
    
    // REMOVED DEBUG PRINTS to prevent Interrupt Storms!
    // The scheduler must be fast.

    // 3. Restore Context
    *CURRENT_TASK_PTR = next_task;
    CSR_MEPC = TASK_PCS[next_task];
    
    return TASK_SPS[next_task];
}