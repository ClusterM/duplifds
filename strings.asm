str_reading:
  .db "READING...", $FF
str_writing:
  .db "WRITING...", $FF
str_checking_crc:
  .db "CHECKING CRC...", $FF
str_done:
  .db "SUCCESS! @", $FF
str_screen_will_be_off_1:
  .db "SCREEN WILL BE...", $FF
str_screen_will_be_off_2:
  .db "BLANK, DON'T WORRY", $FF
str_ask_retry_cancel:
  .db "A-RETRY   B-CANCEL"
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
