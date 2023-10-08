  .include "vars.asm"
  .include "fds_regs.asm"
  .include "macroses.asm"

  ; vectors
  .org $DFFA  ; start at $DFFA
  .dw NMI
  .dw Start
  .dw IRQ_none

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
  ; change color of the LED
  jsr led_off

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
  sta JOY_BOTH_LAST

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
  jsr write_game_name
  jsr write_disk_side
  jsr write_read_block_counters
  jsr write_written_block_counters
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
  beq .read
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

.read:
  printc_ptr str_reading  
  jsr transfer
  ; check for errors
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .write
  jsr print_error
  bne .read
  jmp main

  ; let's write
.write:
  lda #OPERATION_WRITING
  sta <OPERATION
  jsr ask_disk
.writing_start
  printc_ptr str_writing
  jsr transfer
  ; check for errors
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .write_ok
  jsr print_error
  bne .writing_start
  jmp main
.write_ok:
  lda <READ_FULL
  bne .copy_done
  jmp .copy_loop
.copy_done:

  ; check it  
.verify:
  printc_ptr str_checking_crc
  lda #0
  sta <PPU_MODE_NOW
  jsr transfer
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .verify_ok
  jsr print_error
  bne .verify
  jmp main
.verify_ok:

  jsr done_sound
  printc_ptr str_done
  jsr wait_button_or_eject
  jmp main

wait_button_or_eject:
  ; wait until any button is pressed or disk is ejected
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne wait_button_or_eject
.wait:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .end
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait
.end:
  rts

wait_button_or_insert:
  ; wait until any button is pressed or disk is insertes
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne wait_button_or_insert
.wait:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .end
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait
.end:
  rts

ask_retry_cancel:
  printc_ptr str_ask_retry_cancel
.wait_no_button
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .wait_no_button
.wait_button:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  and #BTN_A
  bne .a
  lda <JOY_BOTH_HOLD
  and #BTN_B
  bne .b
  jmp .wait_button
.a:
  ldx #1
  rts
.b:
  ldx #0
  rts

print_error:
  jsr error_sound
  jsr waitblank
  jsr led_off
  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  bne .not_crc
  printc_ptr str_err_crc_error
  jsr print_current_block_number
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_crc:
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  printc_ptr str_err_out_of_memory
  jsr wait_button_or_eject
  ldx #0
  rts
.not_out_of_memory:
  cmp #STOP_NO_DISK
  bne .not_no_disk
  printc_ptr str_err_no_disk
  jsr wait_button_or_insert
  jsr ask_retry_cancel
  rts
.not_no_disk:
  cmp #STOP_NO_POWER
  bne .not_no_power
  printc_ptr str_err_no_power
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_no_power:
  cmp #STOP_END_OF_HEAD
  bne .not_end_of_head
  printc_ptr str_err_end_of_head
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_end_of_head:
  cmp #STOP_WRONG_HEADER
  bne .not_wrong_header
  printc_ptr str_err_different_disk
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_wrong_header:
  cmp #STOP_NOT_READY
  bne .not_not_ready
  printc_ptr str_err_not_ready
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_not_ready:
  cmp #STOP_INVALID_BLOCK
  bne .not_invalid_block
  printc_ptr str_err_invalid_block
  jsr print_current_block_number
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_invalid_block:
  cmp #STOP_TIMEOUT_READY
  bne .not_timeout_ready
  printc_ptr str_err_timeout_ready
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_timeout_ready:
  cmp #STOP_TIMEOUT_READ
  bne .not_timeout_read
  printc_ptr str_err_timeout_read
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_timeout_read:
  cmp #STOP_TIMEOUT_WRITE
  bne .not_timeout_write
  printc_ptr str_err_timeout_write
  jsr wait_button_or_eject
  jsr ask_retry_cancel
  rts
.not_timeout_write:
  printc_ptr str_err_unknown
  jsr wait_button_or_eject
  jmp main

print_current_block_number:
  PPU_to 22, 17
  lda BLOCK_CURRENT
  jsr divide10
  pha
  txa
  clc
  adc #(SPACE + $10)
  sta PPUDATA
  pla
  clc
  adc #(SPACE + $10)
  sta PPUDATA
  rts

divide10:
  ; input: a - dividend 
  ; output: a - remainder, x = quotient
  ldx #0
.div_loop:
  cmp #10
  bcc .done
  sec
  sbc #10
  inx
  jmp .div_loop
.done:
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

IRQ_none:
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

palette: 
  .incbin "palette0.bin"
  .incbin "palette1.bin"
  .incbin "palette2.bin"
  .incbin "palette3.bin"
  .incbin "spalette0.bin"

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
