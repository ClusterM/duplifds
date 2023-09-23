  .include "vars.asm"
  .include "fds_regs.asm"
  .include "macroses.asm"

  ; vectors
  .org $DFFA  ; start at $DFFA
  .dw NMI
  .dw Start
  .dw IRQ_disk_read

  .org $C000  ; code starts at $C000
Start:
  ; disable PPU
  lda #%00000000
  sta PPUCTRL
  sta PPUMASK
  ; warm-up
  jsr waitblank
  jsr waitblank  

  ; clean memory
  lda #$00
  sta <COPY_SOURCE_ADDR
  lda #$02
  sta <COPY_SOURCE_ADDR + 1
  lda #$00
  ldy #$00
  ldx #$06
.loop:
  sta [COPY_SOURCE_ADDR], y
  iny
  bne .loop
  inc <COPY_SOURCE_ADDR+1
  dex
  bne .loop

  ; use IRQ at $DFFE
  lda #$C0
  sta IRQ_ACTION
  ; return to BIOS on reset
  lda #$00
  sta RESET_FLAG
  sta RESET_TYPE

  ; loading palette
load_palette:
  jsr waitblank
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
.loop:
  lda palette, x
  sta PPUDATA
  inx
  cpx #4
  bne .loop

  ; loading blank nametable
clear_nametable:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldy #0
  ldx #0
  lda #$20
.loop:
  cpy #$C0
  bne .noat
  cpx #$03
  bne .noat
  lda #$00
.noat:
  sta PPUDATA
  iny
  bne .loop
  inx
  cpx #$04
  bne .loop
.end:

  ; enable PPU
  jsr waitblank
  ; show background
  lda #%00001010
  sta PPUMASK

  cli ; enable interrupts

main:
  cursor_to 1, 2

  print_line "STARTED"
 
  lda #0
  sta BLOCK_CURRENT
  sta BLOCKS_READ
  sta BLOCKS_WRITTEN
  sta FILE_AMOUNT
  sta BLOCK_AMOUNT

  jsr ask_source_disk
  lda #OPERATION_READING
  sta OPERATION
  jsr transfer
  print "BLOCKS: "
  ldx <BLOCKS_READ
  jsr write_byte
  jsr next_line
  print "RESULT CODE: "
  ldx <STOP_REASON
  jsr write_byte
  jsr next_line
  ;jsr waitblank
  ;jsr update_cursor
  ;lda #$00
  ;sta <COPY_SOURCE_ADDR
  ;lda #$60
  ;sta <COPY_SOURCE_ADDR + 1
  ;jsr hexdump
  ;jsr next_line
  jsr ask_target_disk
  lda #OPERATION_WRITING
  sta OPERATION
  jsr transfer
  print "RESULT CODE: "
  ldx <STOP_REASON
  jsr write_byte
  jsr next_line

  ; main loop        
infin:
  delay 100
  jsr waitblank
  jsr ReadOrDownPads
  jmp infin

ask_source_disk:
  print_line "EJECT DISK"
.wait_eject
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject  
  print_line "INSERT SOURCE DISK"  
.wait_insert
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  rts

ask_target_disk:
  print_line "EJECT DISK"
.wait_eject
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject  
  print_line "INSERT TARGET DISK"  
.wait_insert
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  rts

waitblank:
  jsr scroll_fix
  bit PPUSTATUS
.loop:
  bit PPUSTATUS  ; load A with value at location PPUSTATUS
  bpl .loop  ; if bit 7 is not set (not VBlank) keep checking
  rts

scroll_fix:
  ; fix scrolling
  pha
  bit PPUSTATUS
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  pla
  rts

  ; writed zero-terminated string
write_text:
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  beq .end  
  sta PPUDATA
  jsr add_cursor
  iny
  bne .loop
.end:
  rts

hexdump:
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  tax
  jsr waitblank
  jsr update_cursor
  jsr write_byte
  iny
  cpy #200
  bne .loop
  rts

update_cursor:
  pha
  jsr waitblank
  lda PPUSTATUS
  lda <CURSOR
  sta PPUADDR
  lda <CURSOR + 1
  sta PPUADDR
  pla
  rts

add_cursor:
  pha
  lda CURSOR + 1
  adc #1
  sta CURSOR + 1
  lda CURSOR
  adc #0
  sta CURSOR
  pla
  rts

next_line:
  pha
  lda <CURSOR + 1
  and #$E0
  sta <CURSOR + 1
  clc
  lda <CURSOR + 1
  adc #33
  sta CURSOR + 1
  lda CURSOR
  adc #0
  sta CURSOR
  pla
  rts

write_byte:
  pha
  txa
  pha
  pha
  lsr A
  lsr A
  lsr A
  lsr A
  tax
  jsr write_digit
  pla
  and #$0F
  tax
  jsr write_digit
  pla
  tax
  pla
  jsr add_cursor
  rts   

write_digit:
  txa
  cmp #10
  bcc .low
  clc
  adc #7
.low:
  clc
  adc #$30
  sta PPUDATA
  jsr add_cursor
  rts

; delay for TIMER_COUNTER*1000 CPU cycles
delay_sub:
  set_IRQ IRQ_delay
  lda #(1000 & $FF)
  sta FDS_TIMER_LOW
  lda #((1000 >> 8) & $FF)
  sta FDS_TIMER_HIGH
  lda #%00000011
  sta FDS_TIMER_CONTROL
.wait:  
  lda <TIMER_COUNTER + 1
  bne .wait
  lda <TIMER_COUNTER
  bne .wait
  lda #%00000000
  sta FDS_TIMER_CONTROL
  rts
IRQ_delay:
  bit FDS_DISK_STATUS
  lda <TIMER_COUNTER
  bne .decr
  lda <TIMER_COUNTER + 1
  bne .decr
  lda #%00000000
  sta FDS_TIMER_CONTROL
  rti
.decr:
  lda <TIMER_COUNTER  
  sec
  sbc #1
  sta <TIMER_COUNTER  
  lda <TIMER_COUNTER + 1
  sbc #0
  sta <TIMER_COUNTER + 1
.end:
  rti

NMI:
  ; reset to the main entry point
  lda #$35
  sta $102
  lda #$AC
  sta $103
  jmp [$FFFC]

nametable:
;  .incbin "bg_name_table.bin"
;  .org nametable + $3C0
;  .incbin "bg_attr_table.bin"
palette: 
  .incbin "palette0.bin"
;  .incbin "palette1.bin"

  .include "disk.asm"
