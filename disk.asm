transfer:
  lda #0
  sta <STOP_REASON
  sta <BREAK_READ
  lda <PPU_MODE_NOW
  beq .not_ppu_mode
  ; disable rendering
  lda #%00000000
  sta PPUMASK
  jsr waitblank
  bit PPUSTATUS
  lda #(MEMORY_PPU_START >> 8)
  sta PPUADDR
  lda #(MEMORY_PPU_START & $FF)
  sta PPUADDR
  ; TODO: change screen color?
  ; should we discard first byte?
  lda <OPERATION
  cmp #OPERATION_WRITING
  bne .not_ppu_mode
  ; discarding byte when writing
  lda PPUDATA
.not_ppu_mode:
  ; start address in memory
  lda #(MEMORY_START & $FF)
  sta <DISK_OFFSET
  lda #((MEMORY_START >> 8) & $FF)
  sta <DISK_OFFSET + 1
  ; reset
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  ; start motor
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  ; check power
  lda #$FF
  sta FDS_EXT_WRITE
  delay 5
  lda FDS_EXT_READ
  and #$80
  bne .battery_ok
  ; no power
  lda #STOP_NO_POWER
  sta <STOP_REASON
  jmp .end
.battery_ok:
  ; power ok, rewinding
  ; reset
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  ; start motor
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL  
  lda #0
  sta <BLOCK_CURRENT
.not_ready_yet:
  ; TODO: add timeout
  ; check if disk removed
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .disk_inserted1
  ; disk not inserted
  lda #STOP_NO_DISK
  sta <STOP_REASON
  jmp .end
.disk_inserted1:  
  ; wait for ready state
  ; TODO: timeout
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_READY
  bne .not_ready_yet
  ; ready! reading/writing block by block
.next_block:
  lda <OPERATION
  ; reading?
  bne .not_reading
.reading:
  ; reading block
  jsr read_block
  ; block reading done
  jmp .block_end
.not_reading:
  ; writing
  ; stop if BLOCKS_READ = BLOCK_CURRENT
  lda <BLOCKS_READ
  cmp <BLOCKS_WRITTEN
  beq .reading
  cmp <BLOCK_CURRENT
  beq .end
  ; write if BLOCK_CURRENT >= BLOCKS_WRITTEN
  ; dumb reading otherwise
  lda <BLOCK_CURRENT
  ; file amount block? force write
  cmp #1
  beq .writing
  cmp <BLOCKS_WRITTEN
  bcc .reading
.writing:
  jsr write_block
.block_end:
  ; break if need to break
  lda <BREAK_READ
  bne .end
  ; check if disk removed
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .disk_inserted2
  ; disk not inserted
  lda #STOP_NO_DISK
  sta <STOP_REASON
  jmp .end
.disk_inserted2:
  lda <STOP_REASON
  beq .next_block
  ; reset and stop motor
.end:
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  jsr waitblank
  jsr led_off
  jsr write_game_name
  jsr write_disk_side
  jsr waitblank
  jsr write_read_block_counters
  jsr write_written_block_counters
  jsr waitblank
  lda #0 
  sta OAMADDR
  lda #HIGH(SPRITES)
  sta OAMDMA
  jsr waitblank
  lda #%00011110
  sta PPUMASK
  jsr waitblank
  rts

read_block:
  ; calculating gap size
  lda <BLOCK_CURRENT
  ; delay before block
  bne .not_first_block
  delay 487
  jmp .end_delay
.not_first_block:
  delay 9
.end_delay
  ; calculate block size
  jsr calculate_block_size
  ; set animation mode
  jsr animation_prepare_read
  ; dummy read?
  lda #1
  ldx <BLOCK_CURRENT
  cpx <BLOCKS_READ
  bcc .dummy_reading
  lda #0
.dummy_reading:  
  sta <DUMMY_READ
  ; we don't need memory check for dummy reading
  bne .memory_ok_ok
  ; check free memory
  lda <PPU_MODE_NOW
  bne .ppu_memory_calculation
  sec
  lda #(MEMORY_END & $FF)
  sbc <DISK_OFFSET
  sta <TEMP
  lda #((MEMORY_END >> 8) & $FF)
  sbc <DISK_OFFSET + 1
  sta <TEMP + 1
  jmp .free_memory_calculated
.ppu_memory_calculation:
  ; we have more memory if PPU mode activated now
  sec
  lda #((MEMORY_END + (MEMORY_PPU_END - MEMORY_PPU_START)) & $FF)
  sbc <DISK_OFFSET
  sta <TEMP
  lda #((MEMORY_END + (MEMORY_PPU_END - MEMORY_PPU_START)) >> 8)
  sbc <DISK_OFFSET + 1
  sta <TEMP + 1
.free_memory_calculated:
  ; now TEMP = memory left
  ; temporary decrease BLOCK_LEFT
  dec <BLOCK_LEFT
  dec <BLOCK_LEFT + 1
  sec
  lda <TEMP
  sbc <BLOCK_LEFT
  lda <TEMP + 1
  sbc <BLOCK_LEFT + 1
  bcs .memory_ok
  ; well, it's complicated situation
  ; lets check size of the next block
  sec
  lda #((MEMORY_END - MEMORY_START) & $FF)
  sbc <BLOCK_LEFT
  lda #((MEMORY_END - MEMORY_START) >> 8)
  sbc <BLOCK_LEFT + 1
  bcs .memory_non_clitical
  ; oh, block is too large... PPU memory maybe?
  sec
  lda #(((MEMORY_END - MEMORY_START) + (MEMORY_PPU_END - MEMORY_PPU_START)) & $FF)
  sbc <BLOCK_LEFT
  lda #(((MEMORY_END - MEMORY_START) + (MEMORY_PPU_END - MEMORY_PPU_START)) >> 8)
  sbc <BLOCK_LEFT + 1
  bcs .use_ppu_mode
  ; no, out of memory :(
  lda #STOP_OUT_OF_MEMORY
  sta <STOP_REASON
  rts
.use_ppu_mode:
  ; we can fit the next block but using PPU memory
  inc <PPU_MODE_NEXT
.memory_non_clitical:
  ; it's ok, we'll read next blocks on the next pass
  inc <BREAK_READ
  rts
.memory_ok
  ; restore BLOCK_LEFT
  inc <BLOCK_LEFT
  inc <BLOCK_LEFT + 1
.memory_ok_ok
  ; reset variables
  lda #0
  sta <CRC_STATE
  sta <CRC_RESULT
  ; set IRQ vector
  ; need to determine current memory type - CPU or PPU
  sec
  lda <DISK_OFFSET
  sbc #(MEMORY_END & $FF)  
  lda <DISK_OFFSET + 1
  sbc #(MEMORY_END >> 8)
  bcc .IRQ_set_normal
  ; PPU
  set_IRQ IRQ_disk_read_PPU
  jmp .reading_start
.IRQ_set_normal:
  ; CPU
  set_IRQ IRQ_disk_read
.reading_start:
  ; start reading
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON)
  sta FDS_CONTROL
  ; wait for data
  bit PPUSTATUS
.wait_data
  ; TODO: timeout
  jsr animation
  lda <STOP_REASON
  bne .end
  lda <CRC_RESULT
  beq .wait_data
  cmp #1
  bne .end
.CRC_ok:
  ; end of read  
  ; update BLOCKS_READ if need
  inc <BLOCK_CURRENT
  lda <BLOCK_CURRENT
  cmp <BLOCKS_READ
  bcc .end
  sta <BLOCKS_READ
  jsr precalculate_game_name
  jsr precalculate_block_counters
.end:
  lda <STOP_REASON
  cmp #STOP_INVALID_BLOCK
  beq .end_of_disk_check
  cmp #STOP_CRC_ERROR
  beq .end_of_disk_check
  rts  
.end_of_disk_check:
  ; bad CRC or bad block
  lda <BLOCK_CURRENT
  cmp #2
  bcc .error
  cmp <BLOCK_AMOUNT
  bcc .error
  ; seems like end of the disk, it's not a error
  lda #0
  sta <STOP_REASON
  inc <READ_FULL
  inc <BREAK_READ
  rts
.error:
  rts

IRQ_disk_read:
  pha
  ; PPU mode maybe?
  sec
  lda <DISK_OFFSET
  sbc #(MEMORY_END & $FF)
  lda <DISK_OFFSET + 1
  sbc #(MEMORY_END >> 8)
  bcc .not_ppu_mode
  pla
  jmp IRQ_disk_read_PPU
.not_ppu_mode:
  ; store data
  lda FDS_DATA_READ
  ; skip blocks that already read
  ldx <DUMMY_READ
  bne .end_reading
  ldy #0
  sta [DISK_OFFSET], y
.end_reading:
  ; ack (is it required?)
  ldx #0
  stx FDS_DATA_WRITE
  ; check block type
  ldx <BLOCK_TYPE_TEST
  beq .type_check_end
  cmp <BLOCK_TYPE_TEST
  beq .type_check_no
  ; invalid block
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  lda #STOP_INVALID_BLOCK
  sta <STOP_REASON
  jmp .end
.type_check_no:
  ; do not check again, first byte only
  ldx #0
  stx <BLOCK_TYPE_TEST
.type_check_end:
  ; parse
  ; fast check
  ldx <BLOCK_TYPE_ACT
  cpx #4
  beq .skip_parse
  jsr parse_block
.skip_parse:
  ; increase address offset if reading new data
  ldx <DUMMY_READ
  bne .skip_inc_total_offset
  inc <DISK_OFFSET
  bne .skip_inc_total_offset
  inc <DISK_OFFSET + 1
.skip_inc_total_offset
  ; decrease bytes left counter
  dec BLOCK_LEFT
  bne .end
  dec BLOCK_LEFT + 1
  bne .end ; continue if not underflow
.data_end:
  set_IRQ IRQ_disk_read_CRC
  pla
  rti
.end:
  pla
  rti

IRQ_disk_read_PPU:
  pha  
  ; store data
  lda FDS_DATA_READ
  ; skip blocks that already read
  ldx <DUMMY_READ
  bne .end_reading
  sta PPUDATA
.end_reading:
  ; ack (is it required?)
  ldx #0
  stx FDS_DATA_WRITE
  ; check block type
  ldx <BLOCK_TYPE_TEST
  beq .type_check_end
  cmp <BLOCK_TYPE_TEST
  beq .type_check_no
  ; invalid block
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  lda #STOP_INVALID_BLOCK
  sta <STOP_REASON
  jmp .end
.type_check_no:
  ; do not check again, first byte only
  ldx #0
  stx <BLOCK_TYPE_TEST
.type_check_end:
  ; parse
  ; fast check
  ldx <BLOCK_TYPE_ACT
  cpx #4
  beq .skip_parse
  jsr parse_block
.skip_parse:
  ; decrease bytes left counter
  ; TODO block size > $8000 ?
  dec BLOCK_LEFT
  bne .end
  dec BLOCK_LEFT + 1
  bne .end ; continue if not underflow
.data_end:
  set_IRQ IRQ_disk_read_CRC
  pla
  rti
.end:
  pla
  rti

IRQ_disk_read_CRC:
  pha
  ; discard byte
  lda FDS_DATA_READ
  lda #0
  sta FDS_DATA_WRITE
  set_IRQ IRQ_disk_read_CRC2
  ; enable CRC control
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON | FDS_CONTROL_CRC)
  sta FDS_CONTROL 
  pla
  rti

IRQ_disk_read_CRC2:
  pha
  lda FDS_DATA_READ
  lda #0
  sta FDS_DATA_WRITE
  set_IRQ IRQ_disk_read_CRC3
  pla
  rti

IRQ_disk_read_CRC3:
  pha
  ; discard byte
  lda FDS_DATA_READ
  lda #0
  sta FDS_DATA_WRITE
  ; CRC result
  lda FDS_DISK_STATUS
  and #FDS_DISK_STATUS_CRC_ERROR
  beq .CRC_ok
  ; CRC error :(
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  dec <CRC_RESULT
  lda #STOP_CRC_ERROR
  sta <STOP_REASON
  jmp .end
.CRC_ok:
  ; CRC ok!
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  inc <CRC_RESULT
.end:
  pla
  rti

write_block:
  ; enable writing without transfer
  lda #(FDS_CONTROL_WRITE | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  ; calculating gap size
  lda BLOCK_CURRENT
  ; delay before block
  bne .not_first_block
  delay 580
  jmp .end_delay
.not_first_block:
  delay 18
.end_delay
  ; calculate block size
  jsr calculate_block_size
  ; set animation mode
  jsr animation_prepare_write
  ; need to write zero (?)
  lda #0
  sta FDS_DATA_WRITE
  ; reset variables
  lda #0
  sta <WRITING_DONE
  ; set IRQ vector
  set_IRQ IRQ_disk_write
  ; start transfer, enable IRQ
  lda #(FDS_CONTROL_WRITE | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON)
  sta FDS_CONTROL
  bit PPUSTATUS
.wait_write_end:
  jsr animation
  lda <STOP_REASON
  bne .end
  lda <WRITING_DONE
  beq .wait_write_end
  ; wait while CRC is writing
  ldx #$B2
.write_CRC_wait:
  dex
  bne .write_CRC_wait
  ; motor on without transfer
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  ; end of write  
  inc <BLOCK_CURRENT
  ; update BLOCKS_WRITTEN if success
  lda <STOP_REASON
  bne .end
  ; skip BLOCKS_WRITTEN increament
  ; if file amount block already written
  lda <BLOCK_CURRENT
  cmp #2 ; already incremented
  bne .inc_block
  lda <BLOCKS_WRITTEN
  cmp #1
  beq .inc_block
  jmp .skip_inc
.inc_block:
  inc <BLOCKS_WRITTEN
.skip_inc:
  jsr precalculate_block_counters
.end:
  rts

IRQ_disk_write:
  pha
  ; discard input byte
  bit FDS_DATA_READ
  lda <WRITING_DONE
  lda #$80
  sta FDS_DATA_WRITE
  lda <BLOCK_CURRENT
  cmp #1
  beq .file_amount
  set_IRQ IRQ_disk_write2 
  pla
  rti
.file_amount:
  ; file amount block
  set_IRQ IRQ_disk_write2_file_amount
  pla
  rti

IRQ_disk_write2:
  pha
  ; discard input byte  
  bit FDS_DATA_READ
  ; PPU mode?
  sec
  lda <DISK_OFFSET
  sbc #(MEMORY_END & $FF)
  lda <DISK_OFFSET + 1
  sbc #(MEMORY_END >> 8)
  bcc .not_ppu_mode
  lda PPUDATA
  jmp .write
.not_ppu_mode:
  ldy #0
  lda [DISK_OFFSET], y
.write:
  sta FDS_DATA_WRITE
  ldx <BLOCK_TYPE_ACT
  cpx #4
  beq .skip_parse
  jsr parse_block
.skip_parse:
  inc <DISK_OFFSET
  bne .total_offset_end
  inc <DISK_OFFSET + 1
.total_offset_end:
  ; decrease bytes left counter
  ; TODO block size > $8000 ?
  dec BLOCK_LEFT
  bne .end
  dec BLOCK_LEFT + 1
  bne .end ; continue if not underflow
.data_end:
  set_IRQ IRQ_disk_write3
  pla
  rti
.end:
  pla
  rti

IRQ_disk_write2_file_amount:
  pha
  ; discard input byte  
  bit FDS_DATA_READ
  ; first or second byte?
  lda <BLOCK_LEFT
  beq .second
  ldx #2 ; block ID
  jmp .write_data
.second:
  ; final write?
  lda <READ_FULL
  bne .final
  lda <BLOCKS_READ
  ; convert to file amount
  sec
  sbc #2
  lsr A
  tax
  jmp .write_data
.final:
  ldx <FILE_AMOUNT
.write_data:
  ; write
  stx FDS_DATA_WRITE
  ; increament offset only for first write
  lda <BLOCKS_WRITTEN
  cmp #1
  bne .total_offset_end
  inc <DISK_OFFSET
.total_offset_end:
  ; decrease bytes left counter
  ; TODO block size > $8000 ?
  dec <BLOCK_LEFT
  bne .end
  dec <BLOCK_LEFT + 1
  bne .end ; continue if not underflow
.data_end:
  set_IRQ IRQ_disk_write3
  pla
  rti
.end:
  pla
  rti

IRQ_disk_write3:
  pha
  ; discard input byte
  lda FDS_DATA_READ
  lda #$FF
  sta FDS_DATA_WRITE
  lda #(FDS_CONTROL_WRITE | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_CRC)
  sta FDS_CONTROL
  inc <WRITING_DONE
.end:
  pla
  rti

calculate_block_size:
  ; calculate block size
  lda #1
  sta <BLOCK_LEFT + 1
  lda <BLOCK_CURRENT
  ; first block (disk header)?
  bne .file_amount_block
  lda #56
  sta <BLOCK_LEFT
  lda #1
  sta <BLOCK_TYPE_TEST
  sta <BLOCK_TYPE_ACT
  rts
.file_amount_block:
  cmp #1
  bne .file_header_block
  lda #2
  sta <BLOCK_LEFT
  lda #2
  sta <BLOCK_TYPE_TEST
  sta <BLOCK_TYPE_ACT
  rts
.file_header_block:
  and #1
  bne .file_data_block
  lda #16
  sta <BLOCK_LEFT
  lda #3
  sta <BLOCK_TYPE_TEST
  sta <BLOCK_TYPE_ACT
  rts
.file_data_block:
  clc
  lda <NEXT_FILE_SIZE
  adc #1
  sta <BLOCK_LEFT
  lda <NEXT_FILE_SIZE + 1
  adc #1
  sta <BLOCK_LEFT + 1
  lda #4
  sta <BLOCK_TYPE_TEST
  sta <BLOCK_TYPE_ACT
  rts

parse_block:
  ; A - value
  ; X - offset
  ldx <BLOCK_LEFT
  ; Y - block type
  ldy <BLOCK_TYPE_ACT

  ; disk header block?
  cpy #1
  bne .not_header  
  ; cache or compare?
  ldy <BLOCKS_WRITTEN
  bne .compare_header
  ; store header in the permanent area
  sta <(HEADER_CACHE - 1), x
  rts
.compare_header:
  cmp <(HEADER_CACHE - 1), x  
  bne .wrong_header  
  rts
.wrong_header:
  lda #STOP_WRONG_HEADER
  sta STOP_REASON
  rts
.not_header:
  ; file amount block?
  cpy #2
  bne .not_file_amount
  ; store file amount
  cpx #1
  ; skip if not second byte
  bne .end
  ldx <BLOCK_AMOUNT
  ; skip if already parsed
  bne .end
  sta <FILE_AMOUNT
  clc
  adc <FILE_AMOUNT
  adc #2
  sta <BLOCK_AMOUNT
  rts
.not_file_amount:
  ; file header block?  
  cpx #(16 - $0D)
  bne .not_low_size
  sta NEXT_FILE_SIZE
  rts
.not_low_size:
  cpx #(16 - $0E)
  bne .end
  sta NEXT_FILE_SIZE + 1
.end:
  rts  
