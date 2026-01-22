.section .text
.global _start

# --- 1. MEMORY MAP ---------------------------
# 0x00000000: Reset Vector (CPU starts here)
_start:
    j crt_init

# Force alignment to 0x10 (16 bytes)
.org 0x10

# 0x00000010: Trap Vector (Timer Interrupt jumps here)
trap_vector:
    # 1. Save Context (Allocating 128 bytes on stack)
    addi sp, sp, -128
    
    # Save Registers
    sw ra,  0(sp)
    sw t0,  4(sp)
    sw t1,  8(sp)
    sw t2, 12(sp)
    sw s0, 16(sp)
    sw s1, 20(sp)
    sw a0, 24(sp)
    sw a1, 28(sp)
    sw a2, 32(sp)
    sw a3, 36(sp)
    sw a4, 40(sp)
    sw a5, 44(sp)
    sw a6, 48(sp)
    sw a7, 52(sp)
    sw s2, 56(sp)
    sw s3, 60(sp)
    sw s4, 64(sp)
    sw s5, 68(sp)
    sw s6, 72(sp)
    sw s7, 76(sp)
    sw s8, 80(sp)
    sw s9, 84(sp)
    sw s10, 88(sp)
    sw s11, 92(sp)
    sw t3, 96(sp)
    sw t4, 100(sp)
    sw t5, 104(sp)
    sw t6, 108(sp)
    sw gp, 112(sp)
    sw tp, 116(sp)

    # 2. Call Scheduler
    # Pass current SP as argument (a0) to scheduler(uint32_t sp)
    mv a0, sp
    call scheduler
    
    # Scheduler returns the NEW SP in a0. Update Stack Pointer.
    mv sp, a0

    # 3. Restore Context
    lw ra,  0(sp)
    lw t0,  4(sp)
    lw t1,  8(sp)
    lw t2, 12(sp)
    lw s0, 16(sp)
    lw s1, 20(sp)
    lw a0, 24(sp)
    lw a1, 28(sp)
    lw a2, 32(sp)
    lw a3, 36(sp)
    lw a4, 40(sp)
    lw a5, 44(sp)
    lw a6, 48(sp)
    lw a7, 52(sp)
    lw s2, 56(sp)
    lw s3, 60(sp)
    lw s4, 64(sp)
    lw s5, 68(sp)
    lw s6, 72(sp)
    lw s7, 76(sp)
    lw s8, 80(sp)
    lw s9, 84(sp)
    lw s10, 88(sp)
    lw s11, 92(sp)
    lw t3, 96(sp)
    lw t4, 100(sp)
    lw t5, 104(sp)
    lw t6, 108(sp)
    lw gp, 112(sp)
    lw tp, 116(sp)

    # Free Stack Space
    addi sp, sp, 128
    
    # Return from Interrupt (Uses MEPC)
    mret

# --- 2. INITIALIZATION -----------------------
crt_init:
    # Setup Stack to Top of RAM (0x20000000 + 4KB)
    li sp, 0x20001000
    
    # REMOVED: csrs mstatus, t0
    # Reason: Your hardware does not have the mstatus register.
    
    # Jump to Main
    call main
    
    # Safety Loop
    j .