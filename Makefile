NESASM=nesasm
EMU=fceux64
TILER=nestiler
FDSPACKER=fdspacker
SOURCE=main.asm
SOURCE_MORE=vars.asm fds_regs.asm macroses.asm disk.asm
EXECUTABLE=duplifds.prg
OUTPUT_IMAGE=duplifds.fds

BG_IMAGE=bg.png
ASCII_IMAGE=ascii.png

PALETTE0=palette0.bin
ASCII_PATTERN=ascii_pattern_table.bin

all: $(OUTPUT_IMAGE)

build: $(OUTPUT_IMAGE)

$(EXECUTABLE): $(SOURCE) $(SOURCE_MORE) $(ASCII_PATTERN)
	rm -f $(EXECUTABLE)
	$(NESASM) $(SOURCE) -o $(EXECUTABLE) --symbols=$(OUTPUT_IMAGE) -iWssr

clean:
	rm -f $(EXECUTABLE) $(OUTPUT_IMAGE) *.lst *.nl *.bin 

run: $(OUTPUT_IMAGE)
	$(EMU) $(OUTPUT_IMAGE)

write:
	famicom-dumper write-fds --verify --file $(OUTPUT_IMAGE)

$(ASCII_PATTERN) $(PALETTE0): $(ASCII_IMAGE)
	$(TILER) -i0 $(ASCII_IMAGE) --enable-palettes 0 \
  --bg-color \#000000 \
  --out-pattern-table-0 $(ASCII_PATTERN) \
  --out-palette-0 $(PALETTE0) \
  --no-group-tiles-0

$(OUTPUT_IMAGE): $(EXECUTABLE) diskinfo.json
	$(FDSPACKER) pack diskinfo.json $(OUTPUT_IMAGE)
  
.PHONY: clean
