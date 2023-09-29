  .include "vars.asm"
  .include "fds_regs.asm"
  .include "macroses.asm"

  ; vectors
  .org $DFFA  ; start at $DFFA
  .dw NMI
  .dw Start
  .dw IRQ_disk_read

  .org $D300  ; code starts at $D300
Start:
  ; disable PPU
  lda #%00000000
  sta PPUCTRL
  sta PPUMASK
  ; warm-up
  jsr waitblank
  jsr waitblank 

  ; stop motor
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL

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
  cpx #20
  bne .loop

load_sprites:
  ; load sprites
  ldy #0
.loop:
  lda sprites, y
  sta SPRITES, y
  iny
  cpy #(sprites_end - sprites)
  bne .loop
  lda #$FF
.blank_loop:
  sta SPRITES, y
  iny
  bne .blank_loop  
  lda #0 
  sta OAMADDR
  lda #HIGH(SPRITES)
  sta OAMDMA

  .ifdef COMMIT
print_commit:
  ; print interim commit hash
  PPU_to 24, 28
  print_ptr commit
  .endif

  ; enable PPU
  bit PPUSTATUS
  lda #0
  sta PPUADDR
  sta PPUADDR
  jsr waitblank
  lda #%00011110
  sta PPUMASK  

  lda #0
  sta MANUAL_MODE

  cli ; enable interrupts

main:
  lda #0
  sta <BLOCKS_READ
  sta <BLOCKS_WRITTEN
  sta <BLOCK_AMOUNT
  sta <FILE_AMOUNT
  sta <READ_FULL
  sta <PPU_MODE_NOW
  sta <PPU_MODE_NEXT
  jsr precalculate_game_name
  jsr precalculate_block_counters
  jsr waitblank

.copy_loop
  ; reading
  lda <PPU_MODE_NEXT
  sta <PPU_MODE_NOW
  lda #0
  sta <PPU_MODE_NEXT
  lda #OPERATION_READING
  sta <OPERATION
  jsr ask_disk
  lda <PPU_MODE_NOW
  beq .skip_warning
  ; show warning about black screen
  printc_ptr str_screen_will_be_off_1
  ldx #90
.pause1:
  jsr waitblank
  dex
  bne .pause1
  printc_ptr str_screen_will_be_off_2
  ldx #90
.pause2:
  jsr waitblank
  dex
  bne .pause2
.skip_warning:
  printc_ptr str_reading  
  jsr transfer
  ; check for errors
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .read_ok
  jmp print_error
.read_ok:
  ; let's write
  lda #OPERATION_WRITING
  sta <OPERATION
  jsr ask_disk
  printc_ptr str_writing
  jsr transfer
  ; check for errors
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .write_ok
  jmp print_error
.write_ok:
  lda <READ_FULL
  bne .copy_done
  jmp .copy_loop
.copy_done:

  ; check it  
  printc_ptr str_checking_crc
  lda #0
  sta <PPU_MODE_NOW
  jsr transfer
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .verify_ok
  jmp print_error
.verify_ok:

  jsr done_sound
  printc_ptr str_done

done:
  jsr waitblank
  lda JOY1_HOLD
  ora JOY2_HOLD
  bne .end
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq done
.end:
  jmp main

print_error:
  jsr waitblank
  jsr led_off
  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  bne .not_crc
  printc_ptr str_err_crc_error
  jmp .done
.not_crc:
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  printc_ptr str_err_out_of_memory
  jmp .done
.not_out_of_memory:
  cmp #STOP_NO_DISK
  bne .not_no_disk
  printc_ptr str_err_no_disk
  jmp .done
.not_no_disk:
  cmp #STOP_NO_POWER
  bne .not_no_power
  printc_ptr str_err_no_power
  jmp .done
.not_no_power:
  cmp #STOP_END_OF_HEAD
  bne .not_end_of_head
  printc_ptr str_err_end_of_head
  jmp .done
.not_end_of_head:
  cmp #STOP_WRONG_HEADER
  bne .not_wrong_header
  printc_ptr str_err_different_disk
  jmp .done
.not_wrong_header:
  cmp #STOP_NOT_READY
  bne .not_not_ready
  printc_ptr str_err_not_ready
  jmp .done
.not_not_ready:
  cmp #STOP_INVALID_BLOCK
  bne .not_invalid_block
  printc_ptr str_err_invalid_block
  jmp .done
.not_invalid_block:
  printc_ptr str_err_unknown
  jmp .done
.done:
  jsr error_sound
.loop:
  ; wait for any button
  jsr waitblank
  lda JOY1_HOLD
  ora JOY2_HOLD
  beq .loop
  jmp main

waitblank:
  pha
  txa
  pha
  tya
  pha
  jsr ReadOrDownPads
  ; enable manual mode if select pressed
  lda JOY1_HOLD
  ora JOY2_HOLD
  and #BTN_SELECT
  beq .no_manual
  ; already manual mode?
  lda MANUAL_MODE
  bne .no_manual
  lda #1
  sta MANUAL_MODE
  jsr manual_mode_sound
.no_manual:
  jsr scroll_fix
  bit PPUSTATUS
.loop:
  bit PPUSTATUS  ; load A with value at location PPUSTATUS
  bpl .loop  ; if bit 7 is not set (not VBlank) keep checking
  pla
  tay
  pla
  tax
  pla
  rts

scroll_fix:
  ; fix scrolling
  pha
  lda #%00000000
  sta PPUCTRL
  bit PPUSTATUS
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  pla
  rts

printc:
  ; write message to the center line
  jsr waitblank
printc_no_vblank:
  PPU_to 6, 17
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  bmi .end ; skip $80-$FF
  sec
  sbc #$20
  tax
  lda ascii, x
  sta PPUDATA
  iny
  cpy #18
  bne .loop
  jsr scroll_fix
  rts
.end:
  lda #SPACE
.loop_blank:
  cpy #18
  bne .print_space
  jsr scroll_fix
  rts
.print_space:
  sta PPUDATA
  iny
  bne .loop_blank

print:
  ; just write message
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  bmi .end ; skip $80-$FF
  sec
  sbc #$20
  tax
  lda ascii, x
  sta PPUDATA
  iny
  bne .loop
.end:
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

  .include "disk.asm"
  .include "strings.asm"
  .include "animation.asm"
  .include "askdisk.asm"
  .include "sounds.asm"

palette: 
  .incbin "palette0.bin"
  .incbin "palette1.bin"
  .incbin "palette2.bin"
  .incbin "palette3.bin"
  .incbin "spalette0.bin"

ascii:
  ; characters: <space>!"#$%&'
  .db SPACE + $00, SPACE + $01, SPACE + $02, SPACE + $03, SPACE + $04, SPACE + $05, SPACE + $06, SPACE + $07
  ; characters: ()*+,-./
  .db SPACE + $08, SPACE + $09, SPACE + $0A, SPACE + $0B, SPACE + $0C, SPACE + $0D, SPACE + $0E, SPACE + $0F
  ; characters: 01234567
  .db SPACE + $10, SPACE + $11, SPACE + $12, SPACE + $13, SPACE + $14, SPACE + $15, SPACE + $16, SPACE + $17
  ; characters: 89:;<=>?
  .db SPACE + $18, SPACE + $19, SPACE + $1A, SPACE + $1B, SPACE + $1C, SPACE + $1D, SPACE + $1E, SPACE + $1F
  ; characters: @ABCDEFG
  .db SPACE + $20, SPACE + $21, SPACE + $22, SPACE + $23, SPACE + $24, SPACE + $25, SPACE + $26, SPACE + $27
  ; characters: HIJKLMNO
  .db SPACE + $28, SPACE + $29, SPACE + $2A, SPACE + $2B, SPACE + $2C, SPACE + $2D, SPACE + $2E, SPACE + $10
  ; characters: PQRSTUVW
  .db SPACE + $2F, SPACE + $30, SPACE + $31, SPACE + $32, SPACE + $33, SPACE + $34, SPACE + $35, SPACE + $36
  ; characters: XYZ[\]^_
  .db SPACE + $37, SPACE + $38, SPACE + $39, SPACE + $3A, SPACE + $3B, SPACE + $3C, SPACE + $3D, SPACE + $3E
  ; characters: 'abcdefg
  .db SPACE + $3F, SPACE + $21, SPACE + $22, SPACE + $23, SPACE + $24, SPACE + $25, SPACE + $26, SPACE + $27
  ; characters: hijklmno
  .db SPACE + $28, SPACE + $29, SPACE + $2A, SPACE + $2B, SPACE + $2C, SPACE + $2D, SPACE + $2E, SPACE + $10
  ; characters: pqrstuvw
  .db SPACE + $2F, SPACE + $30, SPACE + $31, SPACE + $32, SPACE + $33, SPACE + $34, SPACE + $35, SPACE + $36
  ; characters: xyz{|}~
  .db SPACE + $37, SPACE + $38, SPACE + $39, SPACE + $40, SPACE + $41, SPACE + $42, SPACE + $43, SPACE + $00

sprites:
  ; X, tile #, attributes, Y
  .db 88, $F0, %00100000, 223
  .db 92, $F1, %00100000, 149 + 8*0
  .db 92, $F1, %00100000, 149 + 8*1
  .db 92, $F1, %00100000, 149 + 8*2 
sprites_end:

  .ifdef COMMIT
commit:
  .incbin COMMIT
  .db $FF
  .endif
