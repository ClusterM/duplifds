led_on_write:
  ; turn LED ON - writing
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$16 ; color
  sta PPUDATA
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  rts

led_on_read:
  ; turn LED ON - reading
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$19 ; color
  sta PPUDATA
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  rts

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
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  rts

write_disk_side:
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
  lda #0
  sta PPUCTRL
  sta PPUSCROLL
  sta PPUSCROLL
  rts

precalculate_game_name:
  ; prepare write_game_name to update text during vblank
  ; all FDS code is located in the RAM,
  ; so we can patch it on the fly :>
  lda #0
  sta GAME_NAME_UPD
  sta DISK_SIDE_UPD
  lda <BLOCKS_READ
  cmp #2
  bcc .no_header
  ; 3-letter game code
  lda HEADER_CACHE + (55 - $10)
  sec
  sbc #$20
  bmi .game_code
  tax
  lda ascii, x  
  sta game_name_byte_1 + 1
  lda HEADER_CACHE + (55 - $11)
  sec
  sbc #$20
  bmi .game_code
  tax
  lda ascii, x  
  sta game_name_byte_2 + 1
  lda HEADER_CACHE + (55 - $12)
  sec
  sbc #$20
  bmi .game_code
  tax
  lda ascii, x
  sta game_name_byte_3 + 1
.game_code:
  ; disk number
  lda HEADER_CACHE + (55 - $16)
  clc
  adc #(SPACE + $11)
  sta disk_number_byte + 1
  ; side number
  lda HEADER_CACHE + (55 - $15)
  clc
  adc #(SPACE + $21)
  sta side_number_byte + 1
  rts
.no_header:
  lda #SPACE
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
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
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
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
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
  bpl .precalc
.vblank:
  ; check for vblank, do not wait for it
  inc <ANIMATION_STATE
  lda <PPU_MODE_NOW
  bne animation_end
  sta <ANIM_PRECALC
  jmp [ANIMATION_VECTOR]
.precalc:
  lda <ANIM_PRECALC
  bne animation_end
  lda <ANIMATION_STATE
  and #$07
  asl A
  sei
  tax
  lda animation_vectors, x
  sta ANIMATION_VECTOR
  inx 
  lda animation_vectors, x
  sta ANIMATION_VECTOR + 1
  cli
  inc <ANIM_PRECALC
  rts
animation_vectors:
  .dw led_on_read, write_game_name, write_disk_side, led_off
  .dw write_read_block_counters, write_written_block_counters, animation_end, animation_end
animation_end:
  rts

animation_prepare_read:
  ; we can edit animation_vectors because code in the RAM adapter's RAM
  lda #LOW(led_on_read)
  sta animation_vectors
  lda #HIGH(led_on_read)
  sta animation_vectors + 1
  lda #0
  sta <ANIM_PRECALC
  rts

animation_prepare_write:
  ; we can edit animation_vectors because code in the RAM adapter's RAM
  lda #LOW(led_on_write)
  sta animation_vectors
  lda #HIGH(led_on_write)
  sta animation_vectors + 1
  lda #0
  sta <ANIM_PRECALC
  rts
