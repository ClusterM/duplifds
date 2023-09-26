str_eject_disk:
  .db "EJECT DISK", $FF
str_insert_source_disk:
  .db "INSERT SOURCE DISK", $FF
str_insert_target_disk:
  .db "INSERT TARGET DISK", $FF
str_reading:
  .db "READING...", $FF
str_writing:
  .db "WRITING...", $FF
str_checking_crc:
  .db "CHECKING CRC...", $FF
str_done:
  .db "SUCCESS! @", $FF
str_and_press_start:
  .db "AND PRESS START", $FF

str_err_crc_error:
  .db "ERR:CRC MISMATCH", $FF
str_err_invalid_block:
  .db "ERR:INVALID BLOCK", $FF
str_err_out_of_memory:
  .db "ERR:OUT OF MEMORY", $FF
str_err_no_disk:
  .db "ERR:NO DISK", $FF
str_err_no_power:
  .db "ERR:NO POWER", $FF
str_err_end_of_head:
  .db "ERR:DISK IS FULL"
str_err_different_disk:
  .db "ERR:DIFFERENT DISK"
str_err_not_ready:
  .db "ERR:NOT READY"
str_err_unknown:
  .db "UNKNOWN ERROR"
