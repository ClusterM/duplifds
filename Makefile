NESASM?=nesasm
EMU?=fceux64
TILER?=nestiler
FDSPACKER?=fdspacker
FAMICOM_DUMPER?=famicom-dumper

OUTPUT_IMAGE?=duplifds.fds
EXECUTABLE=duplifds.prg
SOURCE=main.asm
SOURCE_MORE=vars.asm fds_regs.asm macroses.asm disk.asm strings.asm animation.asm errors.asm

RAM_BINARY=ramcode.bin
RAM_BINARY_CUT=ramcode_cut.bin
RAM_SOURCE=ramcode.asm
RAM_SOURCE_MORE=vars.asm fds_regs.asm macroses.asm  askdisk.asm sounds.asm ascii.asm

SPRITES_BINARY=sprites.bin
SPRITES_BINARY_CUT=sprites_cut.bin
SPRITES_SOURCE=sprites.asm

BG_IMAGE=gui.png
ASCII_IMAGE=ascii.png

PALETTE0=palette0.bin
PALETTE1=palette1.bin
PALETTE2=palette2.bin
PALETTE3=palette3.bin
BG_PATTERN=bg_pattern_table.bin
BG_NAMETABLE=bg_nametable.bin
BG_ATTR_TABLE=bg_attr_table.bin

S_PRITES=sprites.png
S_PATTERN=spr_pattern_table.bin
S_PALETTE0=spalette0.bin

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
$(BG_NAMETABLE) $(BG_ATTR_TABLE) $(S_PATTERN) $(S_PALETTE0)
	$(NESASM) $(SOURCE) -o $(EXECUTABLE) $(COMMIT_ARGS) --symbols=$(OUTPUT_IMAGE) -iWssr

$(RAM_BINARY): $(RAM_SOURCE) $(RAM_SOURCE_MORE)
	$(NESASM) $(RAM_SOURCE) -o $(RAM_BINARY) -iWssr

$(RAM_BINARY_CUT): $(RAM_BINARY)
	dd if=$(RAM_BINARY) of=$(RAM_BINARY_CUT) bs=256 count=5

$(SPRITES_BINARY): $(SPRITES_SOURCE)
	$(NESASM) $(SPRITES_SOURCE) -o $(SPRITES_BINARY) -iWssr

$(SPRITES_BINARY_CUT): $(SPRITES_BINARY)
	dd if=$(SPRITES_BINARY) of=$(SPRITES_BINARY_CUT) bs=256 count=1

$(OUTPUT_IMAGE): $(EXECUTABLE) $(RAM_BINARY_CUT) $(SPRITES_BINARY_CUT) diskinfo.json
	$(FDSPACKER) pack --header diskinfo.json $(OUTPUT_IMAGE)

 $(BG_PATTERN) $(PALETTE0) $(PALETTE1) $(PALETTE2) $(PALETTE3) $(BG_NAMETABLE) $(BG_ATTR_TABLE): $(ASCII_IMAGE) $(BG_IMAGE)
	$(TILER) -i0 $(ASCII_IMAGE) -i1 $(BG_IMAGE) \
	--bg-color \#000000 --share-pattern-table \
	--pattern-offset 16 \
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
	--out-attribute-table-1 $(BG_ATTR_TABLE)

$(S_PATTERN) $(S_PALETTE0): $(S_PRITES)
	$(TILER) -i0 $(S_PRITES) \
	--bg-color \#000000 \
	--mode sprites8x8 \
	--palette-0 \#a8f0bc,\#f0bc3c,\#787878 \
	--out-pattern-table $(S_PATTERN) \
	--out-palette-0 $(S_PALETTE0)

$(COMMIT_FILE):
	git rev-parse --short HEAD | tr -d '\n' > $(COMMIT_FILE)

clean:
	rm -f $(EXECUTABLE) $(OUTPUT_IMAGE) $(RAM_BINARY) *.lst *.nl *.bin $(COMMIT_FILE)

run: $(OUTPUT_IMAGE)
	$(EMU) $(OUTPUT_IMAGE)

write: $(OUTPUT_IMAGE)
	$(FAMICOM_DUMPER) write-fds --verify --file $(OUTPUT_IMAGE)

.PHONY: clean
