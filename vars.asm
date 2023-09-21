  ; zero page
  .rsset $0010
COPY_SOURCE_ADDR .rs 2
COPY_DEST_ADDR   .rs 2
TIMER_COUNTER    .rs 2
CURSOR           .rs 2
CURRENT_BLOCK    .rs 1
BYTES_LEFT       .rs 2
READ_OFFSET      .rs 2
FILE_AMOUNT      .rs 1
NEXT_FILE_SIZE   .rs 2
CRC_STATE        .rs 1
CRC_RESULT       .rs 1

  ; other variables
  .rsset $0300
HEADER_CACHE     .rs 56
