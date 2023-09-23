
; macro to print text: print x, y, text
cursor_to .macro
  .cursor_to_\@:
  lda #($20 + \2 * 32 / $100)
  sta CURSOR
  lda #($00 + ((\2 * 32) % $100) + \1)
  sta CURSOR + 1
  .endm

print .macro
  .print_\@:
  jsr update_cursor
  lda #LOW(.text\@)
  sta <COPY_SOURCE_ADDR
  lda #HIGH(.text\@)
  sta <COPY_SOURCE_ADDR+1
  jsr write_text
  jsr scroll_fix
  jmp .end_print\@
  .text\@:
  .db \1, #0
  .end_print\@:
  .endm

print_line .macro
  .print_\@:
  jsr update_cursor
  lda #LOW(.text\@)
  sta <COPY_SOURCE_ADDR
  lda #HIGH(.text\@)
  sta <COPY_SOURCE_ADDR+1
  jsr write_text
  jsr scroll_fix
  jmp .end_print\@
  .text\@:
  .db \1, #0
  .end_print\@:
  jsr next_line
  .endm

; macro to print text: print x, y, text
print_to .macro
  .print_to_\@:
  jsr waitblank
  lda PPUSTATUS
  lda #($20 + \2 * 32 / $100)
  sta PPUADDR
  lda #($00 + ((\2 * 32) % $100) + \1)
  sta PPUADDR
  lda #LOW(.text\@)
  sta COPY_SOURCE_ADDR
  lda #HIGH(.text\@)
  sta COPY_SOURCE_ADDR+1
  jsr write_text
  jsr scroll_fix
  jmp .end_print\@
  .text\@:
  .db \3, #0
  .end_print\@:
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
