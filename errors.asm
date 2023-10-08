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
  jsr wait_button_or_ins
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
  rts

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

str_err_crc_error:
  .db "ERR:CRC ON BLK #", $FF
str_err_invalid_block:
  .db "ERR:BAD ID BLK #", $FF
str_err_out_of_memory:
  .db "ERR:OUT OF MEMORY", $FF
str_err_no_disk:
  .db "ERR:NO DISK", $FF
str_err_no_power:
  .db "ERR:NO POWER", $FF
str_err_end_of_head:
  .db "ERR:DISK IS FULL", $FF
str_err_different_disk:
  .db "ERR:DIFFERENT DISK", $FF
str_err_not_ready:
  .db "ERR:NOT READY", $FF
str_err_timeout_ready:
  .db "ERR:READY TIMEOUT", $FF  
str_err_timeout_read:
  .db "ERR:READ TIMEOUT", $FF  
str_err_timeout_write:
  .db "ERR:WRITE TIMEOUT", $FF  
str_err_unknown:
  .db "UNKNOWN ERROR", $FF
