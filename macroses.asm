PPU_to .macro
  ; set PPU address to tile X, Y
  bit PPUSTATUS
  lda #($20 + \2 * 32 / $100)
  sta PPUADDR
  lda #($00 + ((\2 * 32) % $100) + \1)
  sta PPUADDR
  .endm

print_ptr .macro
  .print_\@:
  lda #LOW(\1)
  sta <COPY_SOURCE_ADDR
  lda #HIGH(\1)
  sta <COPY_SOURCE_ADDR+1
  jsr print
  .endm

printc_ptr .macro
  .print_\@:
  lda #LOW(\1)
  sta <COPY_SOURCE_ADDR
  lda #HIGH(\1)
  sta <COPY_SOURCE_ADDR+1
  jsr printc
  .endm

delay .macro
  .delay_\@:
  lda #(\1 & $FF)
  sta TIMER_COUNTER
  lda #((\1 >> 8) & $FF)
  sta TIMER_COUNTER + 1
  jsr delay_sub
  .endm

set_IRQ .macro
  lda #LOW(\1)
  sta IRQ_VECTOR
  lda #HIGH(\1)
  sta IRQ_VECTOR + 1
  .endm

set_NMI .macro
  lda #LOW(\1)
  sta NMI_VECTOR
  lda #HIGH(\1)
  sta NMI_VECTOR + 1
  .endm
