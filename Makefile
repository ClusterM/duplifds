NESASM?=nesasm
EMU?=fceux64
TILER?=nestiler
FDSPACKER?=fdspacker
FAMICOM_DUMPER?=famicom-dumper

OUTPUT_IMAGE?=duplifds.fds

SOURCE=main.asm
SOURCE_MORE=vars.asm fds_regs.asm macroses.asm disk.asm
EXECUTABLE=duplifds.prg

BG_IMAGE=gui.png
ASCII_IMAGE=ascii.png

PALETTE0=palette0.bin
PALETTE1=palette1.bin
PALETTE2=palette2.bin
PALETTE3=palette3.bin
BG_PATTERN=bg_pattern_table.bin
BG_NAMETABLE=bg_nametable.bin
BG_ATTR_TABLE=bg_attr_table.bin

all: $(OUTPUT_IMAGE)

build: $(OUTPUT_IMAGE)

$(EXECUTABLE): $(SOURCE) $(SOURCE_MORE) $(BG_PATTERN) $(PALETTE0) $(PALETTE1) $(PALETTE2) $(PALETTE3) $(BG_NAMETABLE) $(BG_ATTR_TABLE)
	rm -f $(EXECUTABLE)
	$(NESASM) $(SOURCE) -o $(EXECUTABLE) --symbols=$(OUTPUT_IMAGE) -iWssr

$(OUTPUT_IMAGE): $(EXECUTABLE) diskinfo.json
	$(FDSPACKER) pack diskinfo.json $(OUTPUT_IMAGE)

$(BG_PATTERN) $(PALETTE0) $(PALETTE1) $(PALETTE2) $(PALETTE3) $(BG_NAMETABLE) $(BG_ATTR_TABLE): $(ASCII_IMAGE) $(BG_IMAGE)
	$(TILER) -i0 $(ASCII_IMAGE) -i1 $(BG_IMAGE) \
  --bg-color \#000000 --share-pattern-table \
  --palette-0 \#c4c4c4,\#183c5c,\#0070ec \
  --palette-1 \#c4c4c4,\#183c5c,\#f0bc3c \
  --palette-2 \#c4c4c4,\#183c5c,\#ff0000 \
  --palette-3 \#24188c,\#7c0800,\#ffffff \
  --out-pattern-table $(BG_PATTERN) \
  --out-palette-0 $(PALETTE0) \
  --out-palette-1 $(PALETTE1) \
  --out-palette-2 $(PALETTE2) \
  --out-palette-3 $(PALETTE3) \
  --out-name-table-1 $(BG_NAMETABLE) \
  --out-attribute-table-1 $(BG_ATTR_TABLE)

clean:
	rm -f $(EXECUTABLE) $(OUTPUT_IMAGE) *.lst *.nl *.bin 

run: $(OUTPUT_IMAGE)
	$(EMU) $(OUTPUT_IMAGE)

write: $(OUTPUT_IMAGE)
	$(FAMICOM_DUMPER) write-fds --verify --file $(OUTPUT_IMAGE)

.PHONY: clean
