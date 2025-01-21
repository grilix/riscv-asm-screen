# vim:syntax=asm
# WIP. Version: 0.2025-01-23

.option push
.nolist

.equ AFIO_ADDR,            0x40010000
.equ RCC_ADDR,             0x40021000
.equ I2C1_ADDR,            0x40005400

.equ TIM2_BASE,            0x40000000

# AFIO
.equ AFIO_PCFR1,           0x04
.equ AFIO_EXTICR,          0x08

# I2C
.equ I2C_CTLR1,             0x00 # 16 bit
.equ I2C_CTLR2,             0x04 # 16 bit
.equ I2C_OADDR1,            0x08 # 16 bit
.equ I2C_OADDR2,            0x0c # 16 bit
.equ I2C_DATAR,             0x10 # 16 bit
.equ I2C_STAR1,             0x14 # 16 bit
.equ I2C_STAR2,             0x18 # 16 bit
.equ I2C_CKCFGR,            0x1c # 16 bit
.equ I2C_CTLR2_FREQ,        0b00111111 # 6 bit mask
.equ I2C_CKCFGR_FS,         (1<<15)
.equ I2C_CKCFGR_DUTY,       (1<<14)
.equ I2C_CKCFGR_CCR,        0x0fff # 12 bit mask
.equ I2C_CTLR1_SWRT,        (1<<15)
.equ I2C_CTLR1_PEC,         (1<<12)
.equ I2C_CTLR1_POS,         (1<<11)
.equ I2C_CTLR1_ACK,         (1<<10)
.equ I2C_CTLR1_STOP,        (1<<9)
.equ I2C_CTLR1_START,       (1<<8)
.equ I2C_CTLR1_NOSTRETCH,   (1<<7)
.equ I2C_CTLR1_ENGC,        (1<<6)
.equ I2C_CTLR1_ENPEC,       (1<<5)
.equ I2C_CTLR1_PE,          (1<<0)
.equ I2C_STAR1_PECERR,      (1<<12)
.equ I2C_STAR1_OVR,         (1<<11)
.equ I2C_STAR1_AF,          (1<<10)
.equ I2C_STAR1_ARLO,        (1<<9)
.equ I2C_STAR1_BERR,        (1<<8)
.equ I2C_STAR1_TXE,         (1<<7)
.equ I2C_STAR1_RXNE,        (1<<6)
.equ I2C_STAR1_STOPF,       (1<<4)
.equ I2C_STAR1_ADD10,       (1<<3)
.equ I2C_STAR1_BTF,         (1<<2)
.equ I2C_STAR1_ADDR,        (1<<1)
.equ I2C_STAR1_SB,          (1<<0)
.equ I2C_STAR2_PEC,         0xff # 8 bit mask
.equ I2C_STAR2_DUALF,       (1<<7)
.equ I2C_STAR2_GENCALL,     (1<<4)
.equ I2C_STAR2_TRA,         (1<<2)
.equ I2C_STAR2_BUSY,        (1<<1)
.equ I2C_STAR2_MSL,         (1<<0)


# Timer 2
.equ TIM2_CTLR1,           0x00 # TIM2 control register 1
.equ TIM2_CTLR2,           0x04 # TIM2 control register 2
.equ TIM2_SMCFGR,          0x08 # TIM2 Slave mode control register
.equ TIM2_DMAINTENR,       0x0c # TIM2 DMA/Int enable register
.equ TIM2_INTFR,           0x10 # TIM2 int status register
.equ TIM2_SWEVGR,          0x14 # TIM2 event generation register
.equ TIM2_CHCTLR1,         0x18 # TIM2 comp/capture control register 1
.equ TIM2_CHCTLR2,         0x1c # TIM2 comp/capture control register 2
.equ TIM2_CCER,            0x20 # TIM2 comp/capture enable register
.equ TIM2_CNT,             0x24 # TIM2 counter
.equ TIM2_PSC,             0x28 # TIM2 count clock prescaler
.equ TIM2_ATRLR,           0x2c # TIM2 auto-reload register
.equ TIM2_CH1CVR,          0x34 # TIM2 comp/capture register 1
.equ TIM2_CH2CVR,          0x38 # TIM2 comp/capture register 2
.equ TIM2_CH3CVR,          0x3c # TIM2 comp/capture register 3
.equ TIM2_CH4CVR,          0x40 # TIM2 comp/capture register 4
.equ TIM2_DMACFGR,         0x48 # TIM2 DMA control register
.equ TIM2_DMAADR,          0x4c # TIM2 DMA address register in continuous mode

.equ TIM2_DMAINTENR_CC1IE, (1<<1)
.equ TIM2_CCER_CC1E,       (1<<0)
.equ TIM2_SWEVGR_UG,       (1<<0)

.equ GPIO_BASE,            0x40010000

.equ GPIO_CFGLR,               0x00
.equ GPIO_INDR,                0x08
.equ GPIO_OUTDR,               0x0c

# GPIO CNF
# Input mode
.equ GPIO_CNF_ANALOG_IN,       0b0000
.equ GPIO_CNF_FLOATING_IN,     0b0100
.equ GPIO_CNF_P_UP_P_DOWN_IN,  0b1000
# Output mode
.equ GPIO_CNF_PUSH_PULL_OUT,   0b0000
.equ GPIO_CNF_OPEN_DRAIN_OUT,  0b0100
.equ GPIO_CNF_MULTI_PP_OUT,    0b1000
.equ GPIO_CNF_MULTI_OD_OUT,    0b1100
# GPIO MODE
.equ GPIO_MODE_INPUT,          0b00
.equ GPIO_MODE_OUT_10MHZ,      0b01
.equ GPIO_MODE_OUT_2MHZ,       0b10
.equ GPIO_MODE_OUT_50MHZ,      0b11

.equ GPIOA_ADDR,               GPIO_BASE + 0x0800
.equ GPIOC_ADDR,               GPIO_BASE + 0x1000
.equ GPIOD_ADDR,               GPIO_BASE + 0x1400

.equ RCC_CTLR,                 0x00
.equ RCC_CFGR0,                0x04
.equ RCC_INTR,                 0x08
.equ RCC_APB2PRSTR,            0x0c
.equ RCC_APB1PRSTR,            0x10
.equ RCC_AHBPCENR,             0x14
.equ RCC_APB2PCENR,            0x18
.equ RCC_APB1PCENR,            0x1c
.equ RCC_RSTSCKR,              0x24

.equ RCC_APB1P_TIM2,           (1<<0)
.equ RCC_APB1P_WWDG,           (1<<11)
.equ RCC_APB1P_I2C,            (1<<21)
.equ RCC_APB1P_PWR,            (1<<28)

.equ RCC_APB2PCENR_MASK,       0xffffa5ca # reserved bits, keep them

.equ RCC_APB2P_AFIO,       (1<<0)
.equ RCC_APB2P_IOPA,       (1<<2)
.equ RCC_APB2P_IOPC,       (1<<4)
.equ RCC_APB2P_IOPD,       (1<<5)
.equ RCC_APB2P_ADC1,       (1<<9)
.equ RCC_APB2P_TIM1,       (1<<11)
.equ RCC_APB2P_SPI1,       (1<<12)
.equ RCC_APB2P_USART1,     (1<<12)

.option pop
