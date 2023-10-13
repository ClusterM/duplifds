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
  sta <Y_OFFSET
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
  cpx #16
  bne .loop
  ; reset animation
  lda #0
  sta <ANIMATION_STATE
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
  ldx #45
.pause1:
  jsr waitblank
  dex
  bne .pause1
  printc_ptr str_screen_will_be_off_2
  ldx #45
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
  .include "errors.asm"
  .include "sprites.asm"

palette: 
  .incbin "palette0.bin"
  .incbin "palette1.bin"
  .incbin "palette2.bin"
  .incbin "palette3.bin"

  .ifdef COMMIT
commit:
  .incbin COMMIT
  .db $FF
  .endif

  ; code/data in the Famicom's RAM: $0300-$07FF
  .org $0300
  .include "ramcode.asm"
  .include "askdisk.asm"
  .include "sounds.asm"
  .include "ascii.asm"
