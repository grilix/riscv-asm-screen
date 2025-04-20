# vim: ft=riscv commentstring=#%s

.include "inc/ch32v003.inc"

.global TIM2_IRQHandler
.global start

.equ I2C_SDA,                  1
.equ I2C_SCL,                  2

.equ GPIOD_SWIO_MASK,          0xf0 # PD1 is SWIO, keep it

.equ PFIC_BASE,  0xE000E000
.equ PFIC_IENR1, 0x100

.equ LED_IRQ, (1<<3)
.equ LED_CNT, (1<<4)

.equ COUNTER_MAX, 200
.equ COUNTER_MATCH, 130

.section .data

clk_tick: .word 0x00
screen_dev:
  .word 0x3c # address
  .word 128  # segment length

i2c_dev:
  .word 0x3c # address

screen_init:
  .word 14 # length # TODO: change these to bytes instead of words
  .word 0x00 # Command start TODO: this shouldn't be here?
  .word 0xae  # DISPLAY OFF

  # .word 0xa8  # SET MULTIPLEX
  # .word   0x1f

  # .word 0x20  # MEMORY MODE
  # .word 0x00  # HORIZONTAL (0x00=horizontal,0x01=vertical,0x02=reset)

  # .word 0x40 # START LINE

  # .word 0xd3  # SET DISPLAY OFFSET
  # .word   0x00

  # .word 0xa0  # SET SEGMENT REMAP (0xa0|0xa1)

  # .word 0xc0  # SET COM SCAN DIRECTION (0xc0|0xc8)

  .word 0xda  # SET COM PINS (0x12=128x64,0x02=128x32)
  .word   0x02

  .word 0x81 # CONTRAST
  .word   0x20

  .word 0xa4  # DISPLAY ALL ON RESUME

  .word 0xa6  # NORMAL DISPLAY

  .word 0xd5  # SET DISPLAY CLOCK DIV
  .word   0x80

  # .word 0xd9  # SET PRECHARGE
  # .word   0xc2

  # .word 0xdb  # SET VCOM DESELECT
  # .word   0x20

  .word 0x8d  # CHARGE PUMP
  .word   0x14

  .word 0x2e # DEACTIVATE SCROLL

  #.word 0x10  # SET HIGH COLUMN
  #.word   0x80
  #.word   0xcb
  #.word 0x00  # SET LOW COLUMN
  #.word   0x10
  #.word   0x40

  .word 0xaf # DISPLAY ON

.section .text

TIM2_IRQHandler: # () => {
  addi  sp, sp, -(4*6)
  sw    ra, 4*0(sp)
  sw    a0, 4*1(sp)
  sw    a1, 4*2(sp)
  sw    a2, 4*3(sp)
  sw    a3, 4*4(sp)

  li    a0, TIM2_BASE
  lh    a3, TIM2_INTFR(a0)
  li    a1, (1<<1)                     # CC1IF
  and   a2, a3, a1                     # Is a counter match?
  bne   a2, a1, .L_TIM2_over

  not   a1, a1                         # Clear counter flag
  and   a3, a3, a1
  sh    a3, TIM2_INTFR(a0)

  la    a0, clk_tick
  li    a1, 1
  sw    a1, 0(a0)                      # Set timer flag

.L_TIM2_over:
  lw    a3, 4*4(sp)
  lw    a2, 4*3(sp)
  lw    a1, 4*2(sp)
  lw    a0, 4*1(sp)
  lw    ra, 4*0(sp)
  addi  sp, sp, (4*6)

  mret
# }

setup_peripherals: # () => {
  li    t1, RCC_ADDR

  lw    t2, RCC_APB1PRSTR(t1)
  li    a5,  RCC_APB1P_TIM2
  or    t2, t2, a5                     # Reset peripherals
  sw    t2, RCC_APB1PRSTR(t1)
  xori  a5, a5, -1                     # Clear reset flags
  and   t2, t2, a5
  sw    t2, RCC_APB1PRSTR(t1)

  lw    t2, RCC_APB1PCENR(t1)          # Enable TIM2
  li    a5, RCC_APB1P_TIM2
  or    t2, t2, a5
  sw    t2, RCC_APB1PCENR(t1)

  lw    t2, RCC_APB2PCENR(t1)
  li    a5, RCC_APB2PCENR_MASK         # Mask reserved
  and   t2, t2, a5
  ori   t2, t2, RCC_APB2P_IOPD
  ori   t2, t2, RCC_APB2P_IOPC # I2C
  #ori   t2, t2, RCC_APB2P_AFIO # TODO: Needed?
  sw    t2, RCC_APB2PCENR(t1)

  ret
# }

setup_ports: # () => {
  # Common port configuration: 10Mhz/PP
  li    a4, GPIO_MODE_OUT_10MHZ | GPIO_CNF_PUSH_PULL_OUT

  li    t1, GPIOD_ADDR                 # PD
  lw    t2, GPIO_CFGLR(t1)

  li    a5, GPIOD_SWIO_MASK            # Mask SWIO
  and   t2, t2, a5

  sll   a5, a4, (4*4)                  # Set pin as output
  or    t2, t2, a5

  sll   a5, a4, (4*3)                  # Set pin as output
  or    t2, t2, a5

  sw    t2, GPIO_CFGLR(t1)

  li    t1, GPIOC_ADDR
  lw    t2, GPIO_CFGLR(t1)
  # Common config for I2C pins
  li    a4, GPIO_MODE_OUT_10MHZ | GPIO_CNF_MULTI_OD_OUT

  sll   a5, a4, (4*I2C_SDA)                  # Set pin as output
  or    t2, t2, a5

  sll   a5, a4, (4*I2C_SCL)                  # Set pin as output
  or    t2, t2, a5

  sw    t2, GPIO_CFGLR(t1)

  ret
# }

enable_irq: # (irqn) => {
  # IRQ locations: (Section 6.5.2)
  # R2: 0x108 <-------------------RESERVED------------------>
  # R2: 0x104 <--------RESERVED-------->|38|37|36|35|34|33|32
  # R1: 0x102 31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16
  # R1: 0x100 --|14|--|12|<-------------RESERVED------------>

  srli  a2, a0, 5                      # Register: 0=IENR1|1=IENR2
  slli  a2, a2, 2                      # Address offset (register * 4)

  andi  t2, a0, 0x1f                   # Calculate bit index
  li    t1, 1
  sll   a0, t1, t2
  li    a3, PFIC_BASE
  addi  a3, a3, PFIC_IENR1
  add   a3, a3, a2

  sw    a0, 0(a3)

  ret
# }

setup_timers: # () => {
  addi  sp, sp, -(4*1)
  sw    ra, 4*0(sp)

  li   a1, TIM2_BASE                   # TIM2 Setup
  li   a4, 5000                        # Set prescaling
  sh   a4, TIM2_PSC(a1) # 16 bits

  # TODO: this needed?
  #lh   a4, TIM2_CHCTLR1(a1)            # 16 bits record
  #ori   a4, a4, (1<<3) # OC1PE
  ##ori   a4, a4, (1<<7) # ARPE
  #sh   a4, TIM2_CHCTLR1(a1)            # Comparator setup

  # Set channel 1 value
  li   a4, COUNTER_MATCH
  sh   a4, TIM2_CH1CVR(a1)             # 16 bits record

  lh   a4, TIM2_DMAINTENR(a1)          # 16 bits record
  ori  a4, a4, TIM2_DMAINTENR_CC1IE    # (1<<1) # CC1IE
  sh   a4, TIM2_DMAINTENR(a1)          # Enable interrupts

  lh   a4, TIM2_CCER(a1)               # 16 bits record
                                       # Enable compare channel 1
  ori  a4, a4, TIM2_CCER_CC1E          # (1<<0) # CC1E
  sh   a4, TIM2_CCER(a1)

  lh   a4, TIM2_SWEVGR(a1)
  ori  a4, a4, TIM2_SWEVGR_UG          #(1<<0) # UG
  sw   a4, TIM2_SWEVGR(a1)

  li   a4, COUNTER_MAX                 # Counter setup
  sh   a4, TIM2_ATRLR(a1)              # 16 bits record

  lh   a4, TIM2_CTLR1(a1)              # 16 bits record
  li   a2, (1<<4)                      # Count UP
  not   a2, a2                         # Disable bit
  and   a4, a4, a2
                                       # Enable counter
  ori   a4, a4, (1<<0) # CEN
  sh    a4, TIM2_CTLR1(a1)

  li    a0, 38                         # Enable TIM2 interrupts
  jal   enable_irq

  lw    ra, 4*0(sp)
  addi  sp, sp, (4*1)

  ret
# }

send_i2c_data: # (addr, *data) => {
  addi  sp, sp, -4*2
  sw    ra, 4*0(sp)

  sw    a1, 4*1(sp) # *data

  li    a1, 8000 # timeout
  jal   i2c_start
  bne   a0, zero, .L_send_i2c_data_end

  lw    a0, 4*1(sp) # *data
  lw    a1, 0(a0) # len
  addi  a0, a0, 4 # advance pointer
  li    a2, 8000 # timeout
  jal     i2c_send_data

.L_send_i2c_data_end:
  jal   i2c_stop

  lw    ra, 4*0(sp)
  addi  sp, sp, 4*2

  ret
# }

clk_wait_ticks: # (count) => 0 {
  la    a1, clk_tick

.L_clk_wait_ticks_loop:
  lw    a2, 0(a1)                # check for tick flag
  beq   a2, zero, .L_clk_wait_ticks_loop

  sw    zero, 0(a1)              # reset tick flag

  addi  a0, a0, -1               # decrement counter
  bgt   a0, zero, .L_clk_wait_ticks_loop

  ret
# }

start: # () => {
  jal   setup_peripherals
  jal   setup_ports
  jal   setup_timers

  li    a0, 4
  jal   clk_wait_ticks

  jal   i2c_setup

  li    a0, 2
  jal   clk_wait_ticks

  la    a1, i2c_dev
  lw    s0, 0(a1) # addr

  mv    a0, s0 # addr
  la    a1, screen_init # *bytes
  jal   send_i2c_data
  bne   a0, zero, L_loop_start

  mv    a0, s0 # addr
  li    a1, 0 # page
  li    a2, 0 # column
  li    a3, 128 # length
  li    a4, 0x00 # pattern
  jal   screen_fill_page # (address, page, column, length, pattern) => result
  bne   a0, zero, L_loop_start

  mv    a0, s0 # addr
  li    a1, 1 # page
  li    a2, 0 # column
  li    a3, 128 # length
  li    a4, 0x00 # pattern
  jal   screen_fill_page # (address, page, column, length, pattern) => result
  bne   a0, zero, L_loop_start

  mv    a0, s0 # addr
  li    a1, 2 # page
  li    a2, 0 # column
  li    a3, 128 # length
  li    a4, 0x00 # pattern
  jal   screen_fill_page # (address, page, column, length, pattern) => result
  bne   a0, zero, L_loop_start

  mv    a0, s0 # addr
  li    a1, 3 # page
  li    a2, 0 # column
  li    a3, 128 # length
  li    a4, 0x00 # pattern
  jal   screen_fill_page # (address, page, pattern, length)
  bne   a0, zero, L_loop_start

  li    a0, GPIOD_ADDR                 # Toggle LED
  li    a1, LED_CNT
  jal   turn_pins_on

  li    s1, 0x00

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*0 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*0
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*1 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*1
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*2 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*2
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*3 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*3
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*4 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*4
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

  mv    a0, s0 # address
  li    a1, 2 # page
  li    a2, 7*5 # column
  la    a3, D_spritesheet # &sprite
  addi  a3, a3, 4*8*5
  jal   screen_sprite_page # (address, page, column, &sprite) => result
  # TODO: errors

L_loop_start:

  li    a0, 4
  jal   clk_wait_ticks

  li    a0, GPIOD_ADDR                 # Toggle LED
  li    a1, LED_IRQ
  jal   toggle_pins

  li    a0, 1
  jal   clk_wait_ticks

  li    a0, GPIOD_ADDR                 # Toggle LED
  li    a1, LED_IRQ
  jal   toggle_pins

  j L_loop_start
