read_disk:
  ; start address in memory
  lda #$00
  sta <READ_OFFSET
  lda #$60
  sta <READ_OFFSET + 1
  ; reset
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  ; check disk
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .disk_inserted
  print_line "DISK NOT INSERTED"
  jmp infin
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
  print_line "NO POWER"
  jmp infin
.battery_ok:
  lda #0
  sta <BLOCK_CURRENT
.rewind:
  ; TODO: add timeout
  ; TODO: wait not ready
  ;lda FDS_DRIVE_STATUS
  ;and #FDS_DRIVE_STATUS_DISK_NOT_READY
  ;beq .rewind
.not_ready:
  ; TODO: add timeout
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_READY
  bne .not_ready
  ; ready! reading block by block
  ; start reading
.next_block
  jsr read_block
  lda STOP_REASON
  beq .next_block
  ; reset and stop motor
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  rts

read_block:
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
  lda #$00
  sbc <READ_OFFSET
  sta <TEMP
  lda #$C0
  lda <READ_OFFSET + 1
  sta <TEMP + 1
  ; now TEMP = memory left
  sec
  lda <TEMP
  sbc <BYTES_LEFT
  lda <TEMP + 1
  sbc <BYTES_LEFT + 1
  bcs .memory_ok
  ;print_line "OUT OF MEMORY"
  lda #2
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
  lda <CRC_RESULT
  beq .wait_data
  cmp #1
  beq .CRC_ok
  ; bad CRC
  ;print_line "BAD CRC"
  lda #1
  sta <STOP_REASON
  rts
.CRC_ok:
  ; end of read  
  inc <BLOCK_CURRENT
  ; update BLOCKS_READ if it's lower than BLOCK_CURRENT
  lda <BLOCK_CURRENT
  cmp <BLOCKS_READ
  bcc .no_new_blocks
  sta <BLOCKS_READ
.no_new_blocks:
  lda #0
  sta <STOP_REASON
  rts

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

IRQ_disk_read:
  ; store data
  ldy #0
  lda FDS_DATA_READ
  sta [READ_OFFSET], y
  ; ack (is it required?)
  ldx #0
  stx FDS_DATA_WRITE
  ldx <BLOCK_TYPE
  beq .type_check_end
  cmp <BLOCK_TYPE
  beq .type_check_end
  ; invalid block
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  dec <CRC_RESULT
  rti
.type_check_end:
  ; do not check again, first byte only
  ldx #0
  stx <BLOCK_TYPE
  ; parse
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
  bne .end
  lda <BYTES_LEFT
  bne .end
  ; jump to CRC check
  set_IRQ IRQ_disk_read_CRC
.end:  
  rti

IRQ_disk_read_CRC:
  lda <CRC_STATE
  bne .not_0
  ; discard byte
  lda FDS_DATA_READ
  sta FDS_DATA_WRITE
  inc <CRC_STATE
  rti
.not_0
  cmp #1
  bne .not_1
  ; enable CRC control
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON | FDS_CONTROL_CRC)
  sta FDS_CONTROL
  inc <CRC_STATE
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
  rti
.CRC_ok:
  ; CRC ok!
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON)
  sta FDS_CONTROL
  jsr parse_block
  inc <CRC_RESULT
  rti

parse_block:
  pha
  ; disk header block?
  lda <BLOCK_CURRENT
  bne .not_header
  ; store header in the permanent area
  sec
  lda #56
  sbc <BYTES_LEFT
  tax
  pla  
  sta <HEADER_CACHE, x
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
