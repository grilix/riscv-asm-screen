PROJECT := i2c

PREFIX := riscv64-unknown-elf

all: build_dir build/main.o build/$(PROJECT).bin
build_dir: build/

.PHONY: all build_dir

AS := $(PREFIX)-as
LD := $(PREFIX)-ld

OBJECTS := build/main.o build/gpio.o build/startup.o build/i2c.o build/screen.o build/sprites.o
ASFLAGS := -g -march=rv32ec_zicsr -mabi=ilp32e
LDFLAGS := -E --discard-none \
	   -T link.ld -nostdlib -m elf32lriscv --print-memory-usage --gc-sections

clean:
	rm -f $(OBJECTS) $(PROJECT).elf $(PROJECT).bin

build/%.o: src/%.s
	$(AS) $(ASFLAGS) -o $@ $<

#build/%.bin: build/%.o
#	$(PREFIX)-objcopy -O binary $< $@

build/%.bin: build/%.elf
	$(PREFIX)-objcopy -O binary $< $@

build/$(PROJECT).elf: $(OBJECTS)
	$(LD) $(LDFLAGS) -m elf32lriscv -o $@ $^
	#$(PREFIX)-ld -m elf32lriscv -o $@ $<

disa: build/$(PROJECT).elf
	$(PREFIX)-objdump -d --disassemble-zeroes $<

build/:
	mkdir -p build

flash: all
	minichlink -w build/$(PROJECT).bin flash -b

sigrok:
	sigrok-cli --driver fx2lafw \
		--time 4ms \
		--channels D1=SCL,D0=SDA \
		--config samplerate=500k \
		--triggers SCL=f \
		--protocol-decoders i2c
server:
	minichlink -baG

sprites:
	go run cmd/sprites/main.go > src/sprites.s

gdb: build/$(PROJECT).elf
	gdb-multiarch -tui -q \
		-ex "file build/$(PROJECT).elf" \
		-ex "target remote localhost:3333" \
		-ex "layout src" \
		-ex "layout regs"
		
#qemu: build/$(PROJECT).bin
#	qemu-system-riscv32 -display none -serial stdio \
#		-machine virt -cpu rv32 \
#		-device loader,file="build/$(PROJECT).bin",cpu-num=1
#		# -bios build/$(PROJECT).bin -s
