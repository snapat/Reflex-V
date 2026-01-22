# Default Target Name
TARGET = firmware

# --- 1. SOURCE FILES ---
# Added scheduler.c so the linker can find the 'scheduler' function
SRCS = crt0.s main.c scheduler.c

# --- 2. COMPILATION RULES ---
all: $(TARGET).bin

$(TARGET).elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(SRCS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f *.o *.elf *.bin *.hex