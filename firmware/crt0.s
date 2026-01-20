.section .text.init
.global _start
.global trap_entry

_start:
    j crt_init 

    # we need trap_entry to land exactly at 0x10 (16 bytes).
    # "j crt_init" is 4 bytes. we need 12 bytes of padding (3 words).

    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000

trap_entry: 
    addi sp, sp, -128
    
    sw ra, 0(sp)   # x1
                   # 2nd register is sp
    sw gp, 4(sp)   # x3
    sw tp, 8(sp)   # x4
    sw t0, 12(sp)  # x5
    sw t1, 16(sp)  # x6
    sw t2, 20(sp)  # x7
    sw s0,  24(sp) # x8 (fp)
    sw s1, 28(sp)  # x9
    sw a0, 32(sp)  # x10
    sw a1, 36(sp)  # x11
    sw a2, 40(sp)  # x12
    sw a3, 44(sp)  # x13
    sw a4, 48(sp)  # x14
    sw a5, 52(sp)  # x15
    sw a6, 56(sp)  # x16
    sw a7, 60(sp)  # x17
    sw s2, 64(sp)  # x18
    sw s3, 68(sp)  # x19
    sw s4, 72(sp)  # x20
    sw s5, 76(sp)  # x21
    sw s6, 80(sp)  # x22
    sw s7, 84(sp)  # x23
    sw s8, 88(sp)  # x24
    sw s9, 92(sp)  # x25
    sw s10, 96(sp)  # x26
    sw s11, 100(sp) # x27
    sw t3, 104(sp) # x28
    sw t4, 108(sp) # x29
    sw t5, 112(sp) # x30
    sw t6, 116(sp) # x31

    #save current sp to a0, scheduler then returns new sp in a0

    mv a0, sp
    call scheduler
    mv sp, a0

    #load registers from new stack

    lw ra,  0(sp)
    lw gp,  4(sp)
    lw tp,  8(sp)
    lw t0,  12(sp)
    lw t1,  16(sp)
    lw t2,  20(sp)
    lw s0,  24(sp)
    lw s1,  28(sp)
    lw a0,  32(sp)
    lw a1,  36(sp)
    lw a2,  40(sp)
    lw a3,  44(sp)
    lw a4,  48(sp)
    lw a5,  52(sp)
    lw a6,  56(sp)
    lw a7,  60(sp)
    lw s2,  64(sp)
    lw s3,  68(sp)
    lw s4,  72(sp)
    lw s5,  76(sp)
    lw s6,  80(sp)
    lw s7,  84(sp)
    lw s8,  88(sp)
    lw s9,  92(sp)
    lw s10, 96(sp)
    lw s11, 100(sp)
    lw t3,  104(sp)
    lw t4,  108(sp)
    lw t5,  112(sp)
    lw t6,  116(sp)

    #get rid of stack frame
    addi sp, sp, 128 #sp increases when reducing size

    #return to the task
    mret

crt_init:
    #setup global pointer (risc-v requirement)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    #setup stack pointer
    la sp, _stack_top

    #handshake with c
    call main

inf_loop:
    j inf_loop



