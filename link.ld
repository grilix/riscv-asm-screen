ENTRY( _start )

MEMORY
{
	FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 16K
	RAM (xrw)  : ORIGIN = 0x20000000, LENGTH = 2K
}

SECTIONS
{
    .init :
    {
      _sinit = .;
      . = ALIGN(4);
      KEEP(*(SORT_NONE(.init)))
      . = ALIGN(4);
      _einit = .;
    } >FLASH AT>FLASH

    .text :
    {
      . = ALIGN(4);
      *(.text)
      *(.text.*)
      . = ALIGN(4); /* idk, something breaks here */
      *(.rodata)
      *(.rodata*)
      . = ALIGN(4);
    } >FLASH AT>FLASH

    .dalign :
    {
      . = ALIGN(4);
      PROVIDE( _data_vma = .);
    } >RAM AT>FLASH

    .dlalign :
    {
      . = ALIGN(4);
      PROVIDE( _data_lma = .);
    } >FLASH AT>FLASH

    .data :
    {
      . = ALIGN(4);
      /* PROVIDE( _sbss = .); */
      *(.data)
      . = ALIGN(4);
      PROVIDE( _edata = .);
    } >RAM AT>FLASH

    PROVIDE( _eusrstack = ORIGIN(RAM) + LENGTH(RAM));

    /*
    .bss :
    {
      . = ALIGN(4);
      PROVIDE(_sbss = .);
      *(.sbss*)
      . = ALIGN(4);
      PROVIDE(_ebss = .);
    } >RAM AT>FLASH
    */

    /DISCARD/ : {
      *(.note .note.*)
      *(.eh_frame .eh_frame.*)
      *(.comment .comment.*)
      *(.ARM.extab* .gnu.linkonce.armextab.*)
      *(.ARM.exidx*)
    }

}
