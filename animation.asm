; step 0
led_on:
  ; turn LED ON - writing
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$11
  sta PPUADDR
  lda <LED_COLORS
  sta PPUDATA
  lda <LED_COLORS + 1
  sta PPUDATA
  lda <LED_COLORS + 2
  sta PPUDATA
  jsr scroll_fix
  ; move to step 1
  lda #LOW(write_game_name)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_game_name)
  sta <ANIMATION_VECTOR + 1
  rts

; step 1
write_game_name:
  lda <GAME_NAME_UPD
  bne .end
  inc <GAME_NAME_UPD
  ; write game code
  PPU_to 10, 19
  lda <TEXT_GAME_NAME
  sta PPUDATA
  lda <TEXT_GAME_NAME + 1
  sta PPUDATA
  lda <TEXT_GAME_NAME + 2
  sta PPUDATA
  jsr scroll_fix
.end:
  ; move to step 2
  lda #LOW(write_disk_side)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_disk_side)
  sta <ANIMATION_VECTOR + 1
  rts

; step 2
write_disk_side:
  lda <DISK_SIDE_UPD
  bne .end
  inc <DISK_SIDE_UPD
  ; write side
  PPU_to 21, 19
  lda <TEXT_DISK_NUM
  sta PPUDATA
  PPU_to 23, 19
  lda <TEXT_DISK_SIDE
  sta PPUDATA
  jsr scroll_fix
.end:
  ; move to step 3
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
  lda #$11
  sta PPUADDR
  lda #COLOR_REWIND_OFF
  sta PPUDATA
  lda #COLOR_READ_OFF
  sta PPUDATA
  lda #COLOR_WRITE_OFF
  sta PPUDATA
  jsr scroll_fix
  ; move to step 4
  lda #LOW(write_read_block_counters)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_read_block_counters)
  sta <ANIMATION_VECTOR + 1
  rts

; step 4
write_read_block_counters:
  lda <READ_CNT_UPD
  bne .end
  inc <READ_CNT_UPD
  ; write block counters
  PPU_to 8, 21
  lda <TEXT_BLK_READ
  sta PPUDATA
  lda <TEXT_BLK_READ + 1
  sta PPUDATA
  PPU_to 11, 21
  lda <TEXT_BLK_TOTAL
  sta PPUDATA
  lda <TEXT_BLK_TOTAL + 1
  sta PPUDATA
  jsr scroll_fix
.end:
  ; move to step 5
  lda #LOW(write_written_block_counters)
  sta <ANIMATION_VECTOR
  lda #HIGH(write_written_block_counters)
  sta <ANIMATION_VECTOR + 1
  rts

; step 5
write_written_block_counters:
  lda <WRITTEN_CNT_UPD
  bne .end
  inc <WRITTEN_CNT_UPD
  ; write block counters
  PPU_to 19, 21
  lda <TEXT_BLK_WRITTEN
  sta PPUDATA
  lda <TEXT_BLK_WRITTEN + 1
  sta PPUDATA
  PPU_to 22, 21
  lda <TEXT_BLK_TOTAL
  sta PPUDATA
  lda <TEXT_BLK_TOTAL + 1
  sta PPUDATA
  jsr scroll_fix
.end:
  ; move to step 6
  lda #LOW(animation_step_6)
  sta <ANIMATION_VECTOR
  lda #HIGH(animation_step_6)
  sta <ANIMATION_VECTOR + 1
  rts

; step 6
animation_step_6:
  ; move to step 7
  lda #LOW(animation_step_7)
  sta <ANIMATION_VECTOR
  lda #HIGH(animation_step_7)
  sta <ANIMATION_VECTOR + 1
  rts

; step 7
animation_step_7:
  ; move to step 0
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
  sta <TEXT_GAME_NAME
  sta <TEXT_GAME_NAME + 1
  sta <TEXT_GAME_NAME + 2
  sta <TEXT_DISK_NUM
  sta <TEXT_DISK_SIDE
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
  sta <TEXT_GAME_NAME
  lda HEADER_CACHE + (55 - $11)
  sec
  sbc #$20
  bmi .disk_number
  tax
  lda ascii, x  
  sta <TEXT_GAME_NAME + 1
  lda HEADER_CACHE + (55 - $12)
  sec
  sbc #$20
  bmi .disk_number
  tax
  lda ascii, x
  sta <TEXT_GAME_NAME + 2
  ; disk number
.disk_number:
  lda HEADER_CACHE + (55 - $16)
  clc
  adc #(SPACE + $11)
  sta <TEXT_DISK_NUM
  ; side number
  lda HEADER_CACHE + (55 - $15)
  clc
  adc #(SPACE + $21)
  sta <TEXT_DISK_SIDE
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
  sta <TEXT_BLK_READ + 1
  txa
  clc
  adc #(SPACE + $10)
  sta <TEXT_BLK_READ
  lda BLOCKS_WRITTEN
  jsr divide10
  clc
  adc #(SPACE + $10)
  sta <TEXT_BLK_WRITTEN + 1
  txa
  clc
  adc #(SPACE + $10)
  sta <TEXT_BLK_WRITTEN
  lda BLOCK_AMOUNT
  jsr divide10
  clc
  adc #(SPACE + $10)
  sta <TEXT_BLK_TOTAL + 1
  txa
  clc
  adc #(SPACE + $10)
  sta <TEXT_BLK_TOTAL
  rts
.no_blocks:
  lda #SPACE
  sta <TEXT_BLK_READ
  sta <TEXT_BLK_READ + 1
  sta <TEXT_BLK_WRITTEN
  sta <TEXT_BLK_WRITTEN + 1
  sta <TEXT_BLK_TOTAL
  sta <TEXT_BLK_TOTAL + 1
  rts

animation:
  ; check for vblank, do not wait for it
  bit PPUSTATUS
  bpl .end
.vblank:
  ; skip if PPU mode activated
  lda <PPU_MODE_NOW
  bne .end
  ; just to scheduled animation
  jmp [ANIMATION_VECTOR]
.end:
  rts

animation_init:
  lda #LOW(led_on)
  sta <ANIMATION_VECTOR
  lda #HIGH(led_on)
  sta <ANIMATION_VECTOR + 1
  rts

animation_init_rewind:
  jsr animation_init
  lda #COLOR_REWIND_ON
  sta <LED_COLORS
  lda #COLOR_READ_OFF
  sta <LED_COLORS + 1
  lda #COLOR_WRITE_OFF
  sta <LED_COLORS + 2
  rts

animation_init_read:
  jsr animation_init
  lda #COLOR_REWIND_OFF
  sta <LED_COLORS
  lda #COLOR_READ_ON
  sta <LED_COLORS + 1
  lda #COLOR_WRITE_OFF
  sta <LED_COLORS + 2
  rts

animation_init_write:
  jsr animation_init
  lda #COLOR_REWIND_OFF
  sta <LED_COLORS
  lda #COLOR_READ_OFF
  sta <LED_COLORS + 1
  lda #COLOR_WRITE_ON
  sta <LED_COLORS + 2
  rts

blank_screen_on:
  lda <PPU_MODE_NOW
  beq .end
  ; disable rendering
  jsr waitblank
  ; cache sprite coords
  ldx #0
  ldy #0
.sprites_cache_loop:
  lda sprites, y
  sta <SPRITES_Y_CACHE, x
  iny
  iny
  iny
  iny
  inx
  cpx #((sprites_end - sprites) / 4)
  bne .sprites_cache_loop

  ; scroll
.scroll_loop:
  ldx #4
.multi_loop:
  inc <Y_OFFSET
  ; move every sprite
  txa ; save X - line
  pha
  ldx #0
.move_sprite_loop:
  txa ; save X - sprite #
  pha
  ; sprite # -> sprite Y offset
  asl A
  asl A
  tax
  ; need to move sprite?
  lda SPRITES, x
  cmp #$FF
  beq .skip_sprite_move
  ; moving
  dec SPRITES, x  
.skip_sprite_move:
  pla ; restore X - sprite #
  tax
  dec <SPRITES_Y_CACHE, x
  inx
  cpx #((sprites_end - sprites) / 4)
  bne .move_sprite_loop
  pla ; restore X - line
  tax
  ; next line
  dex
  bne .multi_loop
  ; sync sprites
  lda #0
  sta OAMADDR
  lda #HIGH(SPRITES)
  sta OAMDMA
  jsr waitblank
  lda <Y_OFFSET
  cmp #240
  bne .scroll_loop
  ; blank screen
  lda #%00000000
  sta PPUMASK
  jsr waitblank
  bit PPUSTATUS
  lda #(MEMORY_PPU_START >> 8)
  sta PPUADDR
  lda #(MEMORY_PPU_START & $FF)
  sta PPUADDR
  lda <OPERATION
  cmp #OPERATION_WRITING
  bne .end
  ; discarding byte when writing
  lda PPUDATA
.end
  rts

blank_screen_off:
  lda <PPU_MODE_NOW
  beq .end
  ; enable rendering
  jsr waitblank
  lda #%00011110
  sta PPUMASK  
  ; scroll
.scroll_loop:
  ldx #4
.multi_loop:
  dec <Y_OFFSET
  ; move every sprite
  txa ; save X - line
  pha
  ldx #0
.move_sprite_loop:
  txa ; save X - sprite #
  pha
  tay ; copy to Y too
  ; sprite # -> sprite Y offset
  asl A
  asl A
  tax
  ; need to move sprite?
  lda SPRITES, x
  cmp SPRITES_Y_CACHE, y ; can't access as zero page
  bne .skip_sprite_move
  ; moving
  inc SPRITES, x  
.skip_sprite_move:
  pla ; restore X - sprite #
  tax
  inc <SPRITES_Y_CACHE, x
  inx
  cpx #((sprites_end - sprites) / 4)
  bne .move_sprite_loop
  pla ; restore X - line
  tax
  ; next line
  dex
  bne .multi_loop
  ; sync sprites
  lda #0 
  sta OAMADDR
  lda #HIGH(SPRITES)
  sta OAMDMA
  jsr waitblank
  lda <Y_OFFSET
  bne .scroll_loop
.end
  rts
