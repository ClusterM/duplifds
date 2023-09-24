
print .macro
  .print_\@:
  lda #LOW(.text\@)
  sta <COPY_SOURCE_ADDR
  lda #HIGH(.text\@)
  sta <COPY_SOURCE_ADDR+1
  jsr write_text
  jmp .end_print\@
  .text\@:
  .db \1, $FF
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

set_NMI .macro
  lda #LOW(\1)
  sta NMI_VECTOR
  lda #HIGH(\1)
  sta NMI_VECTOR + 1
  .endm
