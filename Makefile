NESASM?=nesasm
EMU?=fceux64
TILER?=nestiler
FDSPACKER?=fdspacker
FAMICOM_DUMPER?=famicom-dumper

OUTPUT_IMAGE?=duplifds.fds
EXECUTABLE=duplifds.prg
MAIN_BINARY_CUT=main_cut.bin
RAM_BINARY_CUT=ramcode_cut.bin
SOURCE=main.asm
SOURCE_MORE=vars.asm fds_regs.asm macroses.asm disk.asm strings.asm animation.asm errors.asm ramcode.asm askdisk.asm sounds.asm ascii.asm

BG_IMAGE=gui.png
BG2_IMAGE=blank.png
ASCII_IMAGE=ascii.png

PALETTE0=palette0.bin
PALETTE1=palette1.bin
PALETTE2=palette2.bin
PALETTE3=palette3.bin
BG_PATTERN=bg_pattern_table.bin
BG_NAMETABLE=bg_nametable.bin
BG_ATTR_TABLE=bg_attr_table.bin
BG2_NAMETABLE=bg2_nametable.bin
BG2_ATTR_TABLE=bg2_attr_table.bin

SPRITES=sprites.png
S_PATTERN=spr_pattern_table.bin

INTERIM?=0
COMMIT_FILE=commit.txt
COMMIT_ARGS=
ifneq ($(INTERIM),0)
SOURCE_MORE += $(COMMIT_FILE)
COMMIT_ARGS=--sequ COMMIT=$(COMMIT_FILE)
endif

all: $(OUTPUT_IMAGE)

build: $(OUTPUT_IMAGE)

$(EXECUTABLE): $(SOURCE) $(SOURCE_MORE) $(BG_PATTERN) \
$(PALETTE0) $(PALETTE1) $(PALETTE2) $(PALETTE3) \
$(BG_NAMETABLE) $(BG_NAMETABLE) $(BG_ATTR_TABLE) \
$(BG2_NAMETABLE) $(BG2_NAMETABLE) $(BG2_ATTR_TABLE) \
$(S_PATTERN)
	$(NESASM) $(SOURCE) -o $(EXECUTABLE) $(COMMIT_ARGS) --symbols=$(OUTPUT_IMAGE) -iWssr

$(MAIN_BINARY_CUT): $(EXECUTABLE)
	dd if=$(EXECUTABLE) of=$(MAIN_BINARY_CUT) bs=256 skip=16

$(RAM_BINARY_CUT): $(EXECUTABLE)
	dd if=$(EXECUTABLE) of=$(RAM_BINARY_CUT) bs=256 skip=3 count=5

$(OUTPUT_IMAGE): $(MAIN_BINARY_CUT) $(RAM_BINARY_CUT) diskinfo.json
	$(FDSPACKER) pack --header diskinfo.json $(OUTPUT_IMAGE)

 $(BG_PATTERN) $(BG_NAMETABLE) $(BG_ATTR_TABLE) \
 $(BG2_NAMETABLE) $(BG2_ATTR_TABLE) \
 $(PALETTE0) $(PALETTE1) $(PALETTE2) $(PALETTE3): $(ASCII_IMAGE) $(BG_IMAGE) $(BG2_IMAGE)
	$(TILER) -i0 $(ASCII_IMAGE) -i1 $(BG_IMAGE) -i2 $(BG2_IMAGE) \
	--bg-color \#000000 --share-pattern-table \
	--palette-0 \#c4c4c4,\#008088,\#005000 \
	--palette-1 \#c4c4c4,\#008088,\#f0bc3c \
	--palette-2 \#c4c4c4,\#008088,\#fc7460 \
	--palette-3 \#c4c4c4,\#d82800,\#ffffff \
	--out-pattern-table $(BG_PATTERN) \
	--out-palette-0 $(PALETTE0) \
	--out-palette-1 $(PALETTE1) \
	--out-palette-2 $(PALETTE2) \
	--out-palette-3 $(PALETTE3) \
	--out-name-table-1 $(BG_NAMETABLE) \
	--out-attribute-table-1 $(BG_ATTR_TABLE) \
	--out-name-table-2 $(BG2_NAMETABLE) \
	--out-attribute-table-2 $(BG2_ATTR_TABLE)

$(S_PATTERN): $(SPRITES)
	$(TILER) -i0 $(SPRITES) \
	--bg-color \#000000 \
	--mode sprites8x8 \
	--enable-palettes 0,1 \
	--palette-0 \#787878,\#0000a8,\#402c00 \
	--palette-1 \#f0bc3c,\#000000,\#000000 \
	--out-pattern-table $(S_PATTERN)

$(COMMIT_FILE):
	git rev-parse --short HEAD | tr -d '\n' > $(COMMIT_FILE)

clean:
	rm -f $(EXECUTABLE) $(OUTPUT_IMAGE) $(RAM_BINARY) *.lst *.nl *.bin $(COMMIT_FILE)

run: $(OUTPUT_IMAGE)
	$(EMU) $(OUTPUT_IMAGE)

write: $(OUTPUT_IMAGE)
	$(FAMICOM_DUMPER) write-fds --verify --file $(OUTPUT_IMAGE)

.PHONY: clean
