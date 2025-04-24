# vim: ft=riscv commentstring=#%s

.include "inc/ch32v003.inc"

.section .text

.global toggle_pins
.global turn_pins_on
.global turn_pins_off

toggle_pins: # (address, pins) => address {
  lw    t0, GPIO_OUTDR(a0)
  xor   t0, t0, a1
  sw    t0, GPIO_OUTDR(a0)

  ret
# }

turn_pins_on: # (addr, pins) => address {
  lw    t0, GPIO_OUTDR(a0)
  or    t0, t0, a1
  sw    t0, GPIO_OUTDR(a0)

  ret
# }

turn_pins_off: # (addr, pins) => address {
  lw    t0, GPIO_OUTDR(a0)
  xori  a1, a1, -1
  and   t0, t0, a1
  sw    t0, GPIO_OUTDR(a0)

  ret
# }
