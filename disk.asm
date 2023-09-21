read_disk:
  ; start address in memory
  lda #$00
  sta READ_OFFSET
  lda #$60
  sta READ_OFFSET + 1
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
  ; print_line "REWINDED"
  ; start reading
  jsr read_block
  jsr read_block
  jsr read_block
  jsr read_block
  jsr read_block
  jsr read_block
  ; reset and stop motor
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL
  rts

read_block:
  lda CURRENT_BLOCK
  ; delay before block
  bne .not_first_block
  delay 487
  jmp .end_delay
.not_first_block:
  delay 9
.end_delay
  ; calculate block size
  lda #0
  sta <BYTES_LEFT + 1
  lda <CURRENT_BLOCK
  ; first block (disk header)?
  bne .file_amount_block
  lda #56
  sta <BYTES_LEFT
  jmp .end_block_size
.file_amount_block:
  cmp #1
  bne .file_header_block
  lda #2
  sta <BYTES_LEFT
  jmp .end_block_size
.file_header_block:
  and #1
  bne .file_data_block
  lda #16
  sta <BYTES_LEFT
  jmp .end_block_size
.file_data_block:
  clc
  lda <NEXT_FILE_SIZE
  adc #1
  sta <BYTES_LEFT
  lda <NEXT_FILE_SIZE + 1
  adc #0
  sta <BYTES_LEFT + 1
.end_block_size:
  ; TODO: check free memory
  ; reset variables
  lda #0
  sta CRC_STATE
  sta CRC_RESULT
  ; set IRQ vector
  set_IRQ IRQ_disk_read
  ; start reading
  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_ON | FDS_CONTROL_TRANSFER_ON | FDS_CONTROL_IRQ_ON)
  sta FDS_CONTROL
  ; wait for data
.wait_data
  ; TODO: timeout
  lda CRC_RESULT
  beq .wait_data
  cmp #1
  beq .CRC_ok
  ; bad CRC
  print_line "BAD CRC"
  jmp infin
.CRC_ok:
  ; end of read  
  inc CURRENT_BLOCK
  rts

IRQ_disk_read:
  ; store data
  ldy #0
  lda FDS_DATA_READ
  sta [READ_OFFSET], y
  ; ack
  lda #0
  sta FDS_DATA_WRITE
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
  ; disk header block?
  lda <CURRENT_BLOCK
  bne .not_header
  ; store header in the permanent area
  sec
  lda <READ_OFFSET
  sbc #56
  sta <COPY_SOURCE_ADDR
  lda <READ_OFFSET + 1
  sbc #0
  sta <COPY_SOURCE_ADDR + 1
  ldy #55
.disk_header_loop
  lda [COPY_SOURCE_ADDR], y
  sta HEADER_CACHE, y
  dey
  bpl .disk_header_loop
  rts
  ldy <READ_OFFSET
  sta HEADER_CACHE, y
  rts
.not_header:
  ; file amount block?
  cmp #1
  bne .not_file_amount
  ; store file amount
  sec
  lda <READ_OFFSET
  sbc #2
  sta <COPY_SOURCE_ADDR
  lda <READ_OFFSET + 1
  sbc #0
  sta <COPY_SOURCE_ADDR + 1
  ldy #1
  lda [COPY_SOURCE_ADDR], y
  sta <FILE_AMOUNT  
  rts
.not_file_amount:
  ; file header block?
  and #1
  bne .end
  ; read next file size
  sec
  lda <READ_OFFSET
  sbc #16
  sta <COPY_SOURCE_ADDR
  lda <READ_OFFSET + 1
  sbc #0
  sta <COPY_SOURCE_ADDR + 1
  ldy #$0D
  lda [COPY_SOURCE_ADDR], y
  sta <NEXT_FILE_SIZE
  iny
  lda [COPY_SOURCE_ADDR], y
  sta <NEXT_FILE_SIZE + 1
.end:
  rts  
