led_on:
  ; turn LED ON
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$16
  sta PPUDATA
  bit PPUSTATUS
  lda #0
  sta PPUADDR
  sta PPUADDR
  rts

led_off:
  ; turn LED OFF
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$07
  sta PPUDATA
  bit PPUSTATUS
  lda #0
  sta PPUADDR
  sta PPUADDR
  rts

write_game_name:
  lda <GAME_NAME_UPD
  beq .continue
  rts
.continue:
  inc <GAME_NAME_UPD
  ; write game code
  PPU_to 10, 19
game_name_byte_1:
  lda #$00
  sta PPUDATA
game_name_byte_2:
  lda #$00
  sta PPUDATA
game_name_byte_3:
  lda #$00
  sta PPUDATA
  rts

write_disk_size:
  lda <DISK_SIDE_UPD
  beq .continue
  rts
.continue:
  inc <DISK_SIDE_UPD
  ; write side
  PPU_to 21, 19
disk_number_byte:
  lda #$00
  sta PPUDATA
  PPU_to 23, 19
side_number_byte:
  lda #$00
  sta PPUDATA
  rts

precalculate_game_name:
  ; prepare write_game_name to update text during vblank
  ; all FDS code is located in the RAM,
  ; so we can patch it on the fly :>
  lda #0
  sta GAME_NAME_UPD
  sta DISK_SIDE_UPD
  lda <BLOCKS_READ
  beq .no_header
  ; 3-letter game code
  lda HEADER_CACHE + $10
  sec
  sbc #$20
  bmi .no_game_code
  tax
  lda ascii, x  
  sta game_name_byte_1 + 1
  lda HEADER_CACHE + $11
  sec
  sbc #$20
  bmi .no_game_code
  tax
  lda ascii, x  
  sta game_name_byte_2 + 1
  lda HEADER_CACHE + $12
  sec
  sbc #$20
  bmi .no_game_code
  tax
  lda ascii, x
  sta game_name_byte_3 + 1
.no_game_code:
  ; disk number
  lda HEADER_CACHE + $16
  clc
  adc #$11
  sta disk_number_byte + 1
  ; side number
  lda HEADER_CACHE + $15
  clc
  adc #$21
  sta side_number_byte + 1
  rts
.no_header:
  lda #0
  sta game_name_byte_1 + 1
  sta game_name_byte_2 + 1
  sta game_name_byte_3 + 1
  sta disk_number_byte + 1
  sta side_number_byte + 1
  rts

write_read_block_counters:
  lda <READ_CNT_UPD
  beq .continue
  rts
.continue:
  inc <READ_CNT_UPD
  ; write block counters
  PPU_to 8, 21
blocks_read_byte_1:
  lda #$00
  sta PPUDATA
blocks_read_byte_2:
  lda #$00
  sta PPUDATA
  PPU_to 11, 21
blocks_total_byte_1:
  lda #$00
  sta PPUDATA
blocks_total_byte_2:
  lda #$00
  sta PPUDATA
  rts

write_written_block_counters:
  lda <WRITTEN_CNT_UPD
  beq .continue
  rts
.continue:
  inc <WRITTEN_CNT_UPD
  ; write block counters
  PPU_to 19, 21
blocks_written_byte_1:
  lda #$00
  sta PPUDATA
blocks_written_byte_2:
  lda #$00
  sta PPUDATA
  PPU_to 22, 21
blocks_total_byte_1b:
  lda #$00
  sta PPUDATA
blocks_total_byte_2b:
  lda #$00
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

precalculate_block_counters:
  ; prepare write_block_counters to update text during vblank
  ; all FDS code is located in the RAM,
  ; so we can patch it on the fly :>
  lda #0
  sta READ_CNT_UPD
  sta WRITTEN_CNT_UPD
  lda <BLOCK_AMOUNT
  beq .no_blocks
  lda <BLOCKS_READ
  jsr divide10
  clc
  adc #$10
  sta blocks_read_byte_2 + 1
  txa
  clc
  adc #$10
  sta blocks_read_byte_1 + 1
  lda BLOCKS_WRITTEN
  jsr divide10
  clc
  adc #$10
  sta blocks_written_byte_2 + 1
  txa
  clc
  adc #$10
  sta blocks_written_byte_1 + 1
  lda BLOCK_AMOUNT
  jsr divide10
  clc
  adc #$10
  sta blocks_total_byte_2 + 1
  sta blocks_total_byte_2b + 1
  txa
  clc
  adc #$10
  sta blocks_total_byte_1 + 1
  sta blocks_total_byte_1b + 1
  rts
.no_blocks:
  lda #0
  sta blocks_read_byte_1 + 1
  sta blocks_read_byte_2 + 1
  sta blocks_written_byte_1 + 1
  sta blocks_written_byte_2 + 1
  sta blocks_total_byte_1 + 1
  sta blocks_total_byte_2 + 1
  sta blocks_total_byte_1b + 1
  sta blocks_total_byte_2b + 1
  rts

animation:
  ; check for vblank, do not wait for it
  lda <PPU_MODE_NOW
  beq .not_ppu_mode
  ; disable animation during PPU mode
  rts
.not_ppu_mode:
  bit PPUSTATUS
  bmi .vblank
  ; return if not vlank
  rts
.vblank:
  inc <ANIMATION_STATE
  lda <ANIMATION_STATE
  and #$07
  cmp #$00
  bne .step_1
  jsr led_on
  jmp .end
.step_1:
  cmp #$01
  bne .step_2
  ; TODO: call it only when it's changed?
  jsr write_game_name
  jmp .end
.step_2:
  cmp #$02
  bne .step_3
  ; TODO: call it only when it's changed?
  jsr write_disk_size
  jmp .end
.step_3:
  cmp #$03
  bne .step_4
  jsr led_off
  jmp .end
.step_4:
  cmp #$04
  bne .step_5
  jsr write_read_block_counters
  jmp .end
.step_5
  cmp #$05
  bne .end
  jsr write_written_block_counters
.end:
  jsr scroll_fix
  rts
