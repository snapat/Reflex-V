OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  /* ROM: 4KB for Instructions  */
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
  /* RAM: 4KB for Data and Stack [cite: 280] */
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
}

SECTIONS
{
  /* 1. Code Section */
  .text : {
    . = ALIGN(4);
    *(.text.init)   /* Vector table must be at address 0x00 [cite: 281, 285] */
    *(.text*)
    *(.rodata*)
    . = ALIGN(4);
    _text_end = .;
  } > ROM

  /* 2. Data Section (Load from ROM into RAM at startup) [cite: 280] */
  .data : {
    . = ALIGN(4);
    _data_start = .;
    *(.data*)
    *(.sdata*)     /* Include small data for GP optimization  */
    . = ALIGN(4);
    _data_end = .;
  } > RAM AT> ROM

  /* Symbol for C startup to know where the data image is in ROM */
  _data_load_start = LOADADDR(.data);

  /* 3. Global Pointer Optimization  */
  PROVIDE( __global_pointer$ = _data_start + 0x800 );

  /* 4. BSS Section (Zero-initialized variables) [cite: 315] */
  .bss : {
    . = ALIGN(4);
    _bss_start = .;
    *(.sbss*)      /* Small BSS */
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > RAM

  /* 5. Stack Management  */
  /* We define the top of the stack at the very end of RAM */
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}