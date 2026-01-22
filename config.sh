#!/bin/bash
export RISCV_BIN_PATH="/Users/PJ/Downloads/xpack-riscv-none-elf-gcc-15.2.0-1/bin"
export CC="$RISCV_BIN_PATH/riscv-none-elf-gcc"
export OBJCOPY="$RISCV_BIN_PATH/riscv-none-elf-objcopy"
export CFLAGS="-march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -O1"