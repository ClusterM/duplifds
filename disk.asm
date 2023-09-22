transfer:
  lda #STOP_NONE
  sta <STOP_REASON
  ; start address in memory
  lda #(MEMORY_START & $FF)
  sta <READ_OFFSET
  lda #((MEMORY_START >> 8) & $FF)
  sta <READ_OFFSET + 1
  ; reset
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  ; check disk
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .disk_inserted
  ; disk not inserted
  lda #STOP_NO_DISK
  sta <STOP_REASON
  jmp .end
.disk_inserted:
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
  lda #0
  sta <BLOCK_CURRENT
.not_ready_yet:
  ; TODO: add timeout
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_READY
  bne .not_ready_yet
  ; ready! reading/writing block by block
  ; start reading
.next_block
  lda OPERATION
  ; reading?
  bne .not_reading
  ; reading block
  jsr read_block
  ; block reading done
  jmp .block_end
.not_reading:
  ; writing?
  cmp #OPERATION_WRITING
  bne .not_writing
  ; writing
  ; stop if BLOCKS_READ = BLOCKS_WRITTEN
  lda <BLOCKS_READ
  cmp <BLOCKS_WRITTEN
  beq .end
  ; write if BLOCK_CURRENT >= BLOCKS_WRITTEN
  ; dump reading otherwise
  lda <BLOCK_CURRENT
  cmp <BLOCKS_WRITTEN
  bcc .dumb_reading
  ; write new block
  ; TODO
  jmp .block_end
.dumb_reading:
  ; block already written, reading without storing
  jsr read_block
  jmp .block_end
.not_writing:
.block_end
  ; check for end of the disk
  lda FDS_DISK_STATUS
  and FDS_DISK_STATUS_END_OF_HEAD
  beq .no_end_of_head
  lda #STOP_NO_POWER
  sta <STOP_REASON
  jmp .end
.no_end_of_head:
  lda <STOP_REASON
  beq .next_block
  ; reset and stop motor
.end:
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  rts

read_block:
  ; calculating gap size
  lda BLOCK_CURRENT
  ; delay before block
  bne .not_first_block
  delay 487
  jmp .end_delay
.not_first_block:
  delay 9
.end_delay
  jsr calculate_block_size
  ; check free memory
  sec
  lda #(MEMORY_END & $FF)
  sbc <READ_OFFSET
  sta <TEMP
  lda #((MEMORY_END >> 8) & $FF)
  sbc <READ_OFFSET + 1
  sta <TEMP + 1
  ; now TEMP = memory left
  sec
  lda <TEMP
  sbc <BYTES_LEFT
  lda <TEMP + 1
  sbc <BYTES_LEFT + 1
  bcs .memory_ok
  ;print_line "OUT OF MEMORY"
  lda #STOP_OUT_OF_MEMORY
  sta <STOP_REASON
  rts
.memory_ok
  ; reset variables
  lda #0
  sta <CRC_STATE
  sta <CRC_RESULT
  ; set IRQ vector
  set_IRQ IRQ_disk_read
  ; start reading
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON)
  sta FDS_CONTROL
  ; wait for data
.wait_data
  ; TODO: timeout
  lda <STOP_REASON
  bne .end
  lda <CRC_RESULT
  beq .wait_data
  cmp #1
  bne .end
.CRC_ok:
  ; end of read  
  inc <BLOCK_CURRENT
  ; update BLOCKS_READ if reading
  ldx OPERATION
  bne .end
  inc <BLOCKS_READ
.end:
  rts

IRQ_disk_read:
  pha
  ; store data
  ldy #0
  lda FDS_DATA_READ
  ldx OPERATION
  bne .dummy_reading
  sta [READ_OFFSET], y
.dummy_reading:
  ; ack (is it required?)
  ldx #0
  stx FDS_DATA_WRITE
  ; check block type
  ldx <BLOCK_TYPE
  beq .type_check_end
  cmp <BLOCK_TYPE
  beq .type_check_end
  ; invalid block
  dec <CRC_RESULT
  lda #STOP_CRC_ERROR
  sta <STOP_REASON
  pla
  rti
.type_check_end:
  ; do not check again, first byte only
  ldx #0
  stx <BLOCK_TYPE
  ; parse
  jsr parse_block
  ; increase address offset if reading
  ldx OPERATION
  bne .skip_inc
  clc
  lda <READ_OFFSET
  adc #1
  sta <READ_OFFSET
  lda <READ_OFFSET + 1
  adc #0
  sta <READ_OFFSET + 1
.skip_inc:
  ; decrement bytes left
  sec
  lda <BYTES_LEFT
  sbc #1
  sta <BYTES_LEFT
  lda <BYTES_LEFT + 1
  sbc #0
  sta <BYTES_LEFT + 1
  ; check if end of data
  bne .end
  lda <BYTES_LEFT
  bne .end
  ; enable CRC check
  set_IRQ IRQ_disk_read_CRC
.end:
  pla
  rti

IRQ_disk_read_CRC:
  pha
  lda <CRC_STATE
  bne .not_0
  ; discard byte
  lda FDS_DATA_READ
  sta FDS_DATA_WRITE
  inc <CRC_STATE
  pla
  rti
.not_0
  cmp #1
  bne .not_1
  ; enable CRC control
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON | FDS_CONTROL_CRC)
  sta FDS_CONTROL
  inc <CRC_STATE
  pla
  rti
.not_1
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
  pla
  rti
.CRC_ok:
  ; CRC ok!
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  jsr parse_block
  inc <CRC_RESULT
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
  jsr calculate_block_size
  ; need to write zero (?)
  lda #0
  sta FDS_DATA_WRITE
  ; reset writing state
  lda #0
  sta WRITING_STATE
  ; set IRQ vector
  set_IRQ IRQ_disk_write
  ; start transfer, enable IRQ
  lda #(FDS_CONTROL_WRITE | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON)
  sta FDS_CONTROL
  lda FDS_DATA_READ
  lda #$80
  sta FDS_DATA_WRITE
.wait_write_end:
  lda <STOP_REASON
  bne .end
  lda WRITING_STATE
  cmp #3
  bne .wait_write_end
  ; wait while CRC is writing
  delay 1
.wait_ready:
  ; do we really need to wait?
  lda FDS_DRIVE_STATUS
  and FDS_DRIVE_STATUS_DISK_NOT_READY
  bne .wait_ready
  ; motor on without transfer
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  ; end of write  
  inc <BLOCK_CURRENT
  ; update BLOCKS_WRITTEN if success
  lda <STOP_REASON
  bne .end
  inc <BLOCKS_WRITTEN
.end:
  rts

IRQ_disk_write:
  pha
  ; discard input byte
  lda FDS_DATA_READ
  ; start bit written?
  lda WRITING_STATE
  bne .not_writing_data
  ldy #0
  lda [READ_OFFSET], y
  sta FDS_DATA_WRITE
  ; TODO: copy protection bypass
  jsr parse_block
  ; increase address offset
  clc
  lda <READ_OFFSET
  adc #1
  sta <READ_OFFSET
  lda <READ_OFFSET + 1
  adc #0
  sta <READ_OFFSET + 1
; decrement bytes left
  sec
  lda <BYTES_LEFT
  sbc #1
  sta <BYTES_LEFT
  lda <BYTES_LEFT + 1
  sbc #0
  sta <BYTES_LEFT + 1
  ; check if end of data
  bne .end
  lda <BYTES_LEFT
  bne .end
  inc WRITING_STATE ; 1
  pla
  rti
.not_writing_data:
  cmp #1
  bne .not_writing_FF
  ; writing $FF
  lda #$FF
  sta FDS_DATA_WRITE
  inc WRITING_STATE ; 2
  pla
  rti
.not_writing_FF: 
  cmp #2
  bne .end
  ; enable CRC control
  lda #(FDS_CONTROL_WRITE | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON | FDS_CONTROL_CRC)
  sta FDS_CONTROL
  inc WRITING_STATE ; 3
.end:
  pla
  rti

calculate_block_size:
  ; calculate block size
  lda #0
  sta <BYTES_LEFT + 1
  lda <BLOCK_CURRENT
  ; first block (disk header)?
  bne .file_amount_block
  lda #56
  sta <BYTES_LEFT
  lda #1
  sta <BLOCK_TYPE
  rts
.file_amount_block:
  cmp #1
  bne .file_header_block
  lda #2
  sta <BYTES_LEFT
  lda #2
  sta <BLOCK_TYPE
  rts
.file_header_block:
  and #1
  bne .file_data_block
  lda #16
  sta <BYTES_LEFT
  lda #3
  sta <BLOCK_TYPE
  rts
.file_data_block:
  clc
  lda <NEXT_FILE_SIZE
  adc #1
  sta <BYTES_LEFT
  lda <NEXT_FILE_SIZE + 1
  adc #0
  sta <BYTES_LEFT + 1
  lda #4
  sta <BLOCK_TYPE
  rts


parse_block:
  pha
  ; disk header block?
  lda <BLOCK_CURRENT
  bne .not_header  
  ; calculate header offset
  sec
  lda #56
  sbc <BYTES_LEFT
  tax
  ldy OPERATION
  bne .compare_header
  ; store header in the permanent area
  pla  
  sta <HEADER_CACHE, x
  rts
.compare_header:
  pla
  sta <HEADER_CACHE, x  
  bne .wrong_header  
  rts
.wrong_header:
  lda #STOP_WRONG_HEADER
  sta STOP_REASON
  rts
.not_header:
  ; file amount block?
  cmp #1
  bne .not_file_amount
  ; store file amount
  lda <BYTES_LEFT
  cmp #1
  bne .keep_file_amount
  pla
  sta <FILE_AMOUNT
  clc
  adc <FILE_AMOUNT
  adc #2
  sta <BLOCK_AMOUNT
  rts
.keep_file_amount:
  pla
  rts
.not_file_amount:
  ; file header block?
  and #1
  bne .end
  ; read next file size
  lda <BYTES_LEFT
  cmp #3
  ; low byte
  bne .not_low_size
  pla
  sta <NEXT_FILE_SIZE
  rts
.not_low_size:
  cmp #2
  bne .end
  ; high byte
  pla
  sta <NEXT_FILE_SIZE + 1
  rts
.end:
  pla
  rts  
