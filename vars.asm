  ; zero page
  .rsset $0010
COPY_SOURCE_ADDR .rs 2  ; address storage for copy operations
TEMP             .rs 2  ; just temporary memory
TEMP_X           .rs 1  ; temporary variable for X
TEMP_Y           .rs 1  ; temporary variable for Y
TIMER_COUNTER    .rs 2  ; timer counter (1 for 1000 ticks)
CURSOR           .rs 2  ; for debugging
BLOCK_CURRENT    .rs 1  ; number of the current block
BLOCK_TYPE_TEST  .rs 1  ; type that _should_ be for the current block
BLOCK_TYPE_ACT   .rs 1  ; type the current block
BLOCK_SIZE       .rs 2  ; current block size
BLOCK_OFFSET     .rs 2  ; current block offset
READ_OFFSET      .rs 2  ; current read/write position in memory
FILE_AMOUNT      .rs 1  ; visible file amount
BLOCK_AMOUNT     .rs 1  ; visible block amount (file_amount*2+2)
NEXT_FILE_SIZE   .rs 2  ; size of the next file
CRC_STATE        .rs 1  ; CRC state calculation (2=finished)
CRC_RESULT       .rs 1  ; CRC: 0 - not calculated yet, 1 - ok, $FF - bad CRC
OPERATION        .rs 1  ; current operation code: 0 - reading, 1 - writing, 2 - verifying
STOP_REASON      .rs 1  ; read/write stop reason
BLOCKS_READ      .rs 1  ; amount of blocks read
BLOCKS_WRITTEN   .rs 1  ; amount of blocks written
DUMMY_READ       .rs 1
WRITING_DONE    .rs 1  ; current state of writing
READ_FULL        .rs 1  ; non-zero when source disk reading fully completed
ANIMATION_STATE  .rs 1  ; animation state
HEADER_CACHE     .rs 56 ; cached disk header

STOP_NONE            .equ 0
STOP_CRC_ERROR       .equ 1
STOP_OUT_OF_MEMORY   .equ 2
STOP_NO_DISK         .equ 3
STOP_NO_POWER        .equ 4
STOP_END_OF_HEAD     .equ 5
STOP_WRONG_HEADER    .equ 6
STOP_NOT_READY       .equ 7

OPERATION_READING    .equ 0
OPERATION_WRITING    .equ 1
OPERATION_VIRIFYING  .equ 2

MEMORY_START         .equ $6000
MEMORY_END           .equ $D000
