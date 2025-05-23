# vim: ft=riscv commentstring=#%s

.include "inc/ch32v003.inc"

.section .text

.global i2c_setup
.global i2c_wait_line # (timeout) => result
.global i2c_start # (addr, timeout) => result
.global i2c_stop
.global i2c_send_data # (*bytes, len, timeout) => result
.global i2c_write_byte # (byte, timeout) => result

i2c_setup: # () {
  li    t0, RCC_ADDR

  lw    t1, RCC_APB1PRSTR(t0)
  li    t2, RCC_APB1P_I2C
  or    t1, t1, t2                     # Reset
  sw    t1, RCC_APB1PRSTR(t0)
  xori  t2, t2, -1                     # Clear reset flag
  and   t1, t1, t2
  sw    t1, RCC_APB1PRSTR(t0)

  lw    t1, RCC_APB1PCENR(t0)
  li    t2, RCC_APB1P_I2C
  or    t1, t1, t2
  sw    t1, RCC_APB1PCENR(t0)

  li    t0, I2C1_ADDR

  lw    t1, I2C_CTLR2(t0)
  # Set I2C clock frequency
  li    t2, I2C_CTLR2_FREQ
  not   t2, t2                         # Reset frequency
  and   t1, t1, t2
  ori   t1, t1, 8 # Mhz?; TODO: I have no idea
  sw    t1, I2C_CTLR2(t0)

  #  Set clock settings
  # system clock: 48000000
  lw    t1, I2C_CKCFGR(t0)
  li    t2, I2C_CKCFGR_CCR
  # I2C clock <=    100000
  andi  t2, t2, 40 # core_clock/(i2c_clock*2)
  #ori   t2, t2, I2C_CKCFGR_FS # Fast mode

  sw    t2, I2C_CKCFGR(t0)

  # Enable I2C
  lw    t1, I2C_CTLR1(t0)
  ori   t1, t1, I2C_CTLR1_PE
  sw    t1, I2C_CTLR1(t0)

  #lw    t1, I2C_STAR1(t0)
  # errors?
  #sw    t1, I2C_STAR1(t0)

#L_setup_i2c_end:
  ret
# }

i2c_wait_line: # (timeout) => result {
                                       # Wait for the bus to be free
                                       # Bus is free when
                                       #   I2C_STAR2 & I2C_STAR2_BUSY == 0
  mv    t2, a0

  li    t0, I2C1_ADDR
.L_i2c_wait_line_loop:
  lw    a0, I2C_STAR2(t0)
  andi  a0, a0, I2C_STAR2_BUSY         # store in a0 so we can use it to return
  beq   a0, zero, .L_i2c_wait_line_end

  addi  t2, t2, -1
  bgt   t2, zero, .L_i2c_wait_line_loop

.L_i2c_wait_line_end:
  ret
# }

i2c_wait_status: # (status, timeout) => result {
                                       # Wait until the I2C bus status matches a given
                                       # status. The status uses two 16bit register, comparing:
                                       #   ((I2C_STAR2 << 16) | I2C_STAR1) & status == status
  mv    t1, a0

  li    t0, I2C1_ADDR
.L_i2c_wait_status_loop:
  lh    a0, I2C_STAR2(t0)
  sll   a0, a0, 16
  lh    t2, I2C_STAR1(t0)
  or    a0, a0, t2

  and   a0, a0, t1
  beq   a0, t1, .L_i2c_wait_status_success

  addi  a1, a1, -1
  bgt   a1, zero, .L_i2c_wait_status_loop

  li    a0, 1 # fail
  ret

.L_i2c_wait_status_success:
  li    a0, 0 # success
  ret
# }

i2c_send_start: # (timeout) => result {
  li    t0, I2C1_ADDR
  lh    t1, I2C_CTLR1(t0)
  ori   t1, t1, I2C_CTLR1_START
  sh    t1, I2C_CTLR1(t0)

  mv    a1, a0 # timeout
  li    a0, I2C_STAR2_MSL              # Wait for Master mode
  ori   a0, a0, I2C_STAR2_BUSY
  sll   a0, a0, 16
  ori   a0, a0, I2C_STAR1_SB

  j     i2c_wait_status
# }

i2c_send_addr: # (addr, timeout) => result {
  li    t0, I2C1_ADDR

  sll   a0, a0, 1
  andi  a0, a0, 0xfe                   # clear last bit (write flag)
  sb    a0, I2C_DATAR(t0)              # Send address

  li    a0, I2C_STAR2_MSL | I2C_STAR2_BUSY | I2C_STAR2_TRA
  sll   a0, a0, 16
  ori   a0, a0, I2C_STAR1_TXE | I2C_STAR1_ADDR

  j     i2c_wait_status
# }

i2c_start: # (addr, timeout) => result {
  addi  sp, sp, -(4*6)
  sw    ra, 4*0(sp)
  sb    a0, 4*1(sp) # addr
  sw    a1, 4*2(sp) # timeout

  lw    a0, 4*2(sp) # timeout
  jal   i2c_wait_line
  bne   a0, zero, .L_i2c_start_end

  lw    a0, 4*2(sp) # timeout
  jal   i2c_send_start
  bne   a0, zero, .L_i2c_start_end

  lw    a1, 4*2(sp) # timeout
  lb    a0, 4*1(sp) # addr
  lw    ra, 4*0(sp)
  addi  sp, sp, (4*6)

  j     i2c_send_addr

.L_i2c_start_end:
  ret
# }

i2c_write_byte: # (byte, timeout) => result {
  li    a2, I2C1_ADDR
  sb    a0, I2C_DATAR(a2)

  li    a0, I2C_STAR1_TXE
  j     i2c_wait_status
# }

# *data is a list of bytes:
#  # data+0x04 [b5, b6, ...,  ],
#  # data+0x00 [b1, b2, b3, b4],
i2c_send_data: # (*data, len, timeout) => result {
  beqz   a1, .L_i2c_send_exit          # exit if len=0
                                       # This avoids some problems and saves cycles,
                                       # although this check should be made by the
                                       # caller, imho.
                                       # Now we can safely assume *data is pointing
                                       # to something.

  addi  sp, sp, -(4*6)
  sw    ra, 4*0(sp)

  sw    a0, 4*1(sp) # *data
  sw    a1, 4*2(sp) # len
  sw    a2, 4*3(sp) # timeout

  sw    s0, 4*4(sp)
  sw    s1, 4*5(sp)

.L_i2c_send_next_word:
  lw    a0, 4*1(sp)                    # get pointer from the stack
  lw    s0, 0(a0)                      # load next word from *data
  addi  a0, a0, 4                      # Advance *data pointer
  sw    a0, 4*1(sp)

  li    s1, 4                          # start byte counter

.L_i2c_send_next_byte:
                                       # extract first byte from the word
  andi  a0, s0, 0xff
                                       # shift 8 bits right for next round
  srli  s0, s0, 8

  li    a1, I2C1_ADDR
  sb    a0, I2C_DATAR(a1)              # store byte on the data register

  li    a0, I2C_STAR1_TXE
  lw    a1, 4*3(sp) # timeout
  jal   i2c_wait_status                # wait for the byte to be sent
  bnez  a0, .L_i2c_send_end            # exit if sending failed

  lw    a0, 4*2(sp) # len
  addi  a0, a0, -1                     # decrement bytes left
  beqz  a0, .L_i2c_send_end            # exit if there are no more bytes
  sw    a0, 4*2(sp) # len

  addi  s1, s1, -1
  beqz  s1, .L_i2c_send_next_word      # next word if byte counter is over

  j .L_i2c_send_next_byte              # next byte otherwise

.L_i2c_send_end:
  lw    s1, 4*5(sp)
  lw    s0, 4*4(sp)
  lw    ra, 4*0(sp)
  addi  sp, sp, (4*6)

.L_i2c_send_exit:

  ret
# }

i2c_stop: # () => {
  li    t0, I2C1_ADDR
  lw    t1, I2C_CTLR1(t0)
  ori   t1, t1, I2C_CTLR1_STOP
  sw    t1, I2C_CTLR1(t0)

  ret
# }
