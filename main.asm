  .include "vars.asm"
  .include "fds_regs.asm"
  .include "macroses.asm"

  ; vectors
  .org $DFFA  ; start at $DFFA
  .dw NMI
  .dw Start
  .dw IRQ_disk_read

  .org $D000  ; code starts at $D000
Start:
  ; disable PPU
  lda #%00000000
  sta PPUCTRL
  sta PPUMASK
  ; warm-up
  jsr waitblank
  jsr waitblank 

  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL

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
  cpx #20
  bne .loop

  jsr waitblank
load_sprites:  
  lda #0 
  sta OAMADDR
  ldy #0
.loop:
  lda sprites, y
  sta OAMDATA
  iny
  cpy #(sprites_end - sprites)
  bne .loop
  lda #$FF
.blank_loop:
  sta OAMDATA
  iny
  bne .blank_loop  

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

  cli ; enable interrupts

main:
  lda #0
  sta <BLOCKS_READ
  sta <BLOCKS_WRITTEN
  sta <BLOCK_AMOUNT
  sta <FILE_AMOUNT
  sta <READ_FULL
  jsr precalculate_game_name
  jsr precalculate_block_counters
  jsr waitblank
  jsr led_off
  jsr write_game_name
  jsr write_block_counters

.copy_loop
  jsr ask_source_disk
  lda #OPERATION_READING
  sta <OPERATION
  jsr transfer
  jsr waitblank
  jsr led_off
  jsr write_game_name
  jsr write_block_counters

  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  beq .crc_error
  cmp #STOP_INVALID_BLOCK
  beq .crc_error
  jmp .not_crc_error
.crc_error
  ; it's ok if all visible files are read
  lda <BLOCKS_READ
  cmp #2
  bcs .somethig_read
  ; can't read anything
  jmp print_error
.somethig_read:
  lda <BLOCKS_READ
  cmp <BLOCK_AMOUNT
  bcs .not_crc_error_disk_done
  ; bad block :(
  jmp print_error
.not_crc_error_disk_done:
  inc <READ_FULL
  jmp .ok_lets_write
.not_crc_error:
  ; out of memory?
  lda <STOP_REASON
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  lda <BLOCKS_READ
  cmp <BLOCKS_WRITTEN
  bne .memory_non_clitical
  ; can't fit in the memory ever single block
  jmp print_error
.memory_non_clitical:
  ; it's ok, we'll write in multiple passes
  jmp .ok_lets_write
.not_out_of_memory:
  ; other error
  jmp print_error
.ok_lets_write:

  jsr ask_target_disk
  lda #OPERATION_WRITING
  sta <OPERATION
  jsr transfer
  jsr led_off
  jsr write_game_name
  jsr write_block_counters

  lda <STOP_REASON
  cmp #STOP_NONE
  beq .write_ok
  jmp print_error
.write_ok:
  lda READ_FULL
  bne .copy_done
  jmp .copy_loop
.copy_done:

  ; check it
  printc_ptr str_checking_crc
  jsr transfer
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .verify_ok
  jmp print_error
.verify_ok:

  printc_ptr str_done

done:
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq done
  jmp main

  ; main loop        
infin:
  jsr waitblank
  jsr ReadOrDownPads
  jmp infin

print_error:
  ; TODO: error sound
  jsr waitblank
  jsr led_off
  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  bne .not_crc
  ; TODO: print number of the block?
  printc_ptr str_err_crc_error
  jmp done
.not_crc:
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  printc_ptr str_err_out_of_memory
  jmp done
.not_out_of_memory:
  cmp #STOP_NO_DISK
  bne .not_no_disk
  printc_ptr str_err_no_disk
  jmp done
.not_no_disk:
  cmp #STOP_NO_POWER
  bne .not_no_power
  printc_ptr str_err_no_power
  jmp done
.not_no_power:
  cmp #STOP_END_OF_HEAD
  bne .not_end_of_head
  printc_ptr str_err_end_of_head
  jmp done
.not_end_of_head:
  cmp #STOP_WRONG_HEADER
  bne .not_wrong_header
  printc_ptr str_err_different_disk
  jmp done
.not_wrong_header:
  cmp #STOP_NOT_READY
  bne .not_not_ready
  printc_ptr str_err_not_ready
  jmp done
.not_not_ready:
  cmp #STOP_INVALID_BLOCK
  bne .not_invalid_block
  printc_ptr str_err_invalid_block
  jmp done
.not_invalid_block:
  printc_ptr str_err_unknown
  jmp done

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
  lda #0  
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

palette: 
  .incbin "palette0.bin"
  .incbin "palette1.bin"
  .incbin "palette2.bin"
  .incbin "palette3.bin"
  .incbin "spalette0.bin"

ascii:
  ; characters: <space>!"#$%&'
  .db $00, $01, $02, $03, $04, $05, $06, $07
  ; characters: ()*+,-./
  .db $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  ; characters: 01234567
  .db $10, $11, $12, $13, $14, $15, $16, $17
  ; characters: 89:;<=>?
  .db $18, $19, $1A, $1B, $1C, $1D, $1E, $1F
  ; characters: @ABCDEFG
  .db $20, $21, $22, $23, $24, $25, $26, $27
  ; characters: HIJKLMNO
  .db $28, $29, $2A, $2B, $2C, $2D, $2E, $10
  ; characters: PQRSTUVW
  .db $2F, $30, $31, $32, $33, $34, $35, $36
  ; characters: XYZ[\]^_
  .db $37, $38, $39, $3A, $3B, $3C, $3D, $3E
  ; characters: 'abcdefg
  .db $3F, $21, $22, $23, $24, $25, $26, $27
  ; characters: hijklmno
  .db $28, $29, $2A, $2B, $2C, $2D, $2E, $10
  ; characters: pqrstuvw
  .db $2F, $30, $31, $32, $33, $34, $35, $36
  ; characters: xyz{|}~
  .db $37, $38, $39, $40, $41, $42, $43, $00

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
