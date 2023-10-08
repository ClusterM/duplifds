; step 0
led_on:
  ; turn LED ON - writing
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda <OPERATION
  cmp #OPERATION_WRITING
  bne .reading
  lda #$16 ; write color
  bne .done
.reading:
  lda #$19 ; read color
.done:
  sta PPUDATA
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  lda #LOW(write_game_name)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_game_name)
  sta <ANIMATION_VECTOR + 1
  rts

; step 1
write_game_name:
  lda <GAME_NAME_UPD
  bne write_game_name_end
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
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
write_game_name_end:
  lda #LOW(write_disk_side)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_disk_side)
  sta <ANIMATION_VECTOR + 1
  rts

; step 2
write_disk_side:
  lda <DISK_SIDE_UPD
  bne write_disk_side_end
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
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
write_disk_side_end:
  lda #LOW(led_off)
  sta <ANIMATION_VECTOR
  lda #HIGH(led_off)
  sta <ANIMATION_VECTOR + 1
  rts

; step 3
led_off:
  ; turn LED OFF
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$08 ; color
  sta PPUDATA
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  lda #LOW(write_read_block_counters)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_read_block_counters)
  sta <ANIMATION_VECTOR + 1
  rts

; step 4
write_read_block_counters:
  lda <READ_CNT_UPD
  bne write_read_block_counters_end
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
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
write_read_block_counters_end:
  lda #LOW(write_written_block_counters)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_written_block_counters)
  sta <ANIMATION_VECTOR + 1
  rts

; step 5
write_written_block_counters:
  lda <WRITTEN_CNT_UPD
  bne write_written_block_counters_end
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
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
write_written_block_counters_end:
  lda #LOW(animation_step_6)
  sta <ANIMATION_VECTOR
  lda #HIGH(animation_step_6)
  sta <ANIMATION_VECTOR + 1
  rts

animation_step_6:
  lda #LOW(animation_step_7)
  sta <ANIMATION_VECTOR
  lda #HIGH(animation_step_7)
  sta <ANIMATION_VECTOR + 1
  rts

animation_step_7:
  lda #LOW(led_on)
  sta <ANIMATION_VECTOR
  lda #HIGH(led_on)
  sta <ANIMATION_VECTOR + 1
  rts

precalculate_game_name:
  ; prepare write_game_name to update text during vblank
  ; all FDS code is located in the RAM,
  ; so we can patch it on the fly :>
  lda <BLOCKS_READ
  cmp #0
  bne .not_0
  lda #SPACE
  sta game_name_byte_1 + 1
  sta game_name_byte_2 + 1
  sta game_name_byte_3 + 1
  sta disk_number_byte + 1
  sta side_number_byte + 1
  jmp .done
.not_0:
  cmp #1
  bne .end
  ; 3-letter game code
  lda HEADER_CACHE + (55 - $10)
  sec
  sbc #$20
  bmi .disk_number
  tax
  lda ascii, x  
  sta game_name_byte_1 + 1
  lda HEADER_CACHE + (55 - $11)
  sec
  sbc #$20
  bmi .disk_number
  tax
  lda ascii, x  
  sta game_name_byte_2 + 1
  lda HEADER_CACHE + (55 - $12)
  sec
  sbc #$20
  bmi .disk_number
  tax
  lda ascii, x
  sta game_name_byte_3 + 1
  ; disk number
.disk_number:
  lda HEADER_CACHE + (55 - $16)
  clc
  adc #(SPACE + $11)
  sta disk_number_byte + 1
  ; side number
  lda HEADER_CACHE + (55 - $15)
  clc
  adc #(SPACE + $21)
  sta side_number_byte + 1
.done:
  lda #0
  sta <GAME_NAME_UPD
  sta <DISK_SIDE_UPD
.end:
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
  adc #(SPACE + $10)
  sta blocks_read_byte_2 + 1
  txa
  clc
  adc #(SPACE + $10)
  sta blocks_read_byte_1 + 1
  lda BLOCKS_WRITTEN
  jsr divide10
  clc
  adc #(SPACE + $10)
  sta blocks_written_byte_2 + 1
  txa
  clc
  adc #(SPACE + $10)
  sta blocks_written_byte_1 + 1
  lda BLOCK_AMOUNT
  jsr divide10
  clc
  adc #(SPACE + $10)
  sta blocks_total_byte_2 + 1
  sta blocks_total_byte_2b + 1
  txa
  clc
  adc #(SPACE + $10)
  sta blocks_total_byte_1 + 1
  sta blocks_total_byte_1b + 1
  rts
.no_blocks:
  lda #SPACE
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
  bit PPUSTATUS
  bpl .end
.vblank:
  ; check for vblank, do not wait for it
  lda <PPU_MODE_NOW
  bne .end
  jmp [ANIMATION_VECTOR]
.end:
  rts

animation_init:
  ; we can edit animation_vectors because code in the RAM adapter's RAM
  lda #LOW(led_on)
  sta <ANIMATION_VECTOR
  lda #HIGH(led_on)
  sta <ANIMATION_VECTOR + 1
  rts
