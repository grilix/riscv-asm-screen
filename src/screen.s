# vim: ft=riscv commentstring=#%s
.section .text

.equ    SCREEN_COMMAND, 0x00
.equ    SCREEN_DATA,    0x40

.global new_screen_send_page # (address, *bytes) => result
.global screen_fill_page # (address, page, column, length, pattern) => result
.global screen_sprite_page # (address, page, column, *sprite) => result

screen_set_cursor: # (address, page, column) => result {
  addi  sp, sp, -4*9
  sw    ra, 4*0(sp)
  sw    a1, 4*1(sp) # page
  sw    a2, 4*2(sp) # column

  li    a1, 8000 # timeout
  jal   i2c_start
  bne   a0, zero, .L_screen_set_address_end

                                      # Data to send:
                                      #    [ SCREEN_COMMAND,
                                      #      # 0x22, # TODO: needed?
                                      #      0xb0 + page
                                      #      # 0x04, # TODO: needed?
                                      #      lower,
                                      #      higher,
                                      #    ]
  li    a1, SCREEN_COMMAND
  sw    a1, 4*3(sp)
  li    a1, 0xb0
  lw    a0, 4*1(sp) # page
  add   a1, a1, a0
  sw    a1, 4*4(sp)
  lw    a0, 4*2(sp) # column
  andi  a1, a0, 0x0f
  sw    a1, 4*5(sp) # column & 0x0f

  li    a1, 0x10 # TODO: higher (column)
  lw    a0, 4*2(sp) # column
  srli  a0, a0, 4
  andi  a1, a0, 0x0f
  ori   a1, a1, 0x10
  sw    a1, 4*6(sp) # ((column >> 4) & 0x0f) | 0x10

  mv    a0, sp
  addi  a0, a0, 4*3 # stack offset
  li    a1, 4
  li    a2, 8000
  jal   i2c_send_data # (*data, len, timeout) => result

.L_screen_set_address_end:

  lw    ra, 4*0(sp)
  addi  sp, sp,  4*9

  j     i2c_stop
  # }

screen_sprite_page: # (address, page, column, *sprite) => result {
  addi  sp, sp, -4*6
  sw    ra, 4*0(sp)
  sw    s0, 4*1(sp)

  sw    a0, 4*2(sp) # address
  sw    a1, 4*3(sp) # page
  sw    a2, 4*4(sp) # column
  sw    a3, 4*5(sp) # *sprite

  jal   screen_set_cursor # (address, page, column) => result
  bne   a0, zero, .L_screen_sprite_page_end

  lw    a0, 4*2(sp) # address
  li    a1, 8000 # timeout
  jal   i2c_start
  bne   a0, zero, .L_screen_sprite_page_end

  li    a0, 0x40 # data start
  li    a1, 8000 # timeout
  jal   i2c_write_byte # (byte, timeout) => result
  bne   a0, zero, .L_screen_sprite_page_end

  lw    a0, 4*5(sp) # *sprite
  lw    a1, 4*0(a0) # first word is the length
  addi  a0, a0, 4*1 # skip length
  li    a2, 8000 # timeout
  jal   i2c_send_data # (*bytes, len, timeout) => result

.L_screen_sprite_page_end:

  lw    s0, 4*1(sp)
  lw    ra, 4*0(sp)
  addi  sp, sp, 4*6

  j     i2c_stop
  # }

screen_fill_page: # (address, page, column, length, pattern) => result {
  addi  sp, sp, -4*6
  sw    ra, 4*0(sp)
  sw    s0, 4*1(sp)

  sw    a3, 4*2(sp) # length
  sw    a4, 4*3(sp) # pattern
  sw    a0, 4*4(sp) # address

  jal   screen_set_cursor # (address, page, column) => result
  bne   a0, zero, .L_screen_fill_page_end

  lw    a0, 4*4(sp) # address
  li    a1, 8000 # timeout
  jal   i2c_start
  bne   a0, zero, .L_screen_fill_page_end

  li    a0, 0x40 # data start
  li    a1, 8000 # timeout
  jal   i2c_write_byte # (byte, timeout) => result
  bne   a0, zero, .L_screen_fill_page_end

  lw    s0, 4*2(sp) # length
.L_screen_fill_page_loop:
  lw    a0, 4*3(sp) # pattern
  li    a1, 8000 # timeout
  jal   i2c_write_byte # (byte, timeout) => result
  bne   a0, zero, .L_screen_fill_page_end
  addi  s0, s0, -1
  bne   s0, zero, .L_screen_fill_page_loop

.L_screen_fill_page_end:

  lw    s0, 4*1(sp)
  lw    ra, 4*0(sp)
  addi  sp, sp, 4*6

  j     i2c_stop
  # }
