OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
  /* fixed: moved to 0x20000000 so bit 29 is 1 (matches bus hardware) */
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
}

SECTIONS
{
  .text : {
    *(.text.init)   /* startup code first */
    *(.text*)       /* all other code */
  } > ROM

  /* fixed: moved gp to match the new ram address */
  __global_pointer$ = 0x20000000 + 0x800;

  .data : {
    . = ALIGN(4);
    _data_start = .;        /* ram destination start */
    *(.data*)
    *(.sdata*)
    . = ALIGN(4);
    _data_end = .;          /* ram destination end */
  } > RAM AT> ROM           /* store in rom, run in ram */

  /* rom source address for copy loop */
  _data_load_start = LOADADDR(.data);

  .bss : {
    . = ALIGN(4);
    _bss_start = .;         /* start clearing here */
    *(.bss*)
    *(.sbss*)
    . = ALIGN(4);
    _bss_end = .;           /* stop clearing here */
  } > RAM

  .stack (NOLOAD) : {
    . = ALIGN(8);
    _stack_top = ORIGIN(RAM) + LENGTH(RAM); /* stack grows down from here */
  } > RAM
}