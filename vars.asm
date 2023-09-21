  ; zero page
  .rsset $0010
COPY_SOURCE_ADDR .rs 2  ; address storage for copy operations
TEMP             .rs 2  ; just temporary memory
TIMER_COUNTER    .rs 2  ; timer counter (1 for 1000 ticks)
CURSOR           .rs 2  ; for debugging
BLOCK_CURRENT    .rs 1  ; number of the current block
BLOCK_TYPE       .rs 1  ; type that _should_ be for the current block
BYTES_LEFT       .rs 2  ; bytes left of the current block
READ_OFFSET      .rs 2  ; current read/write position in memory
FILE_AMOUNT      .rs 1  ; visible file amount
BLOCK_AMOUNT     .rs 1  ; visible block amount (file_amount*2+2)
NEXT_FILE_SIZE   .rs 2  ; size of the next file
CRC_STATE        .rs 1  ; CRC state calculation (2=finished)
CRC_RESULT       .rs 1  ; CRC: 0 - not calculated yet, 1 - ok, $FF - bad CRC
STOP_REASON      .rs 1  ; read stop reason: 0 - success, 1 - CRC error, 2 - out of memory
BLOCKS_READ      .rs 1  ; amount of blocks read
BLOCKS_WRITTEN   .rs 1  ; amount of blocks written
HEADER_CACHE     .rs 56 ; cached disk header

