; zero page
  .rsset $0000
COPY_SOURCE_ADDR .rs 2  ; address storage for copy operations
TEMP             .rs 2  ; just temporary memory
JOY1_HOLD        .rs 1  ; first controller state
JOY2_HOLD        .rs 1  ; second controller state
TIMER_COUNTER    .rs 2  ; timer counter (1 for 1000 ticks)
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
BREAK_READ       .rs 1  ; flag to stop blocks reading
BLOCKS_READ      .rs 1  ; amount of blocks read
BLOCKS_WRITTEN   .rs 1  ; amount of blocks written
DUMMY_READ       .rs 1
WRITING_DONE     .rs 1  ; current state of writing
READ_FULL        .rs 1  ; non-zero when source disk reading is fully completed
MANUAL_MODE      .rs 1  ; flag that manual disk insert mode enabled
ANIMATION_STATE  .rs 1  ; animation state
ANIMATION_VECTOR .rs 2  ; animation scheduled function
PPU_MODE_NEXT    .rs 1  ; flag that we must use PPU mode on the next pass
PPU_MODE_NOW     .rs 1  ; flag that we must use PPU mode on the current pass
ANIM_PRECALC     .rs 1  ; is next animation address precalculated?
GAME_NAME_UPD    .rs 1  ; flag that game name text updated on the screen
DISK_SIDE_UPD    .rs 1  ; flag that disk side text updated on the screen
READ_CNT_UPD     .rs 1  ; flag that read block amount updated on the screen
WRITTEN_CNT_UPD  .rs 1  ; flag that written block amount updated on the screen
HEADER_CACHE     .rs 56 ; cached disk header
  .rsset $0300
SPRITES          .rs 256

; constants
BTN_A            .equ $01
BTN_B            .equ $02
BTN_SELECT       .equ $04
BTN_START        .equ $08
BTN_UP           .equ $10
BTN_DOWN         .equ $20
BTN_LEFT         .equ $40
BTN_RIGHT        .equ $80

STOP_NONE            .equ 0
STOP_CRC_ERROR       .equ 1
STOP_OUT_OF_MEMORY   .equ 2
STOP_NO_DISK         .equ 3
STOP_NO_POWER        .equ 4
STOP_END_OF_HEAD     .equ 5
STOP_WRONG_HEADER    .equ 6
STOP_NOT_READY       .equ 7
STOP_INVALID_BLOCK   .equ 8

OPERATION_READING    .equ 0
OPERATION_WRITING    .equ 1

; memory regions
MEMORY_START         .equ $6000
MEMORY_END           .equ $D500
MEMORY_PPU_START     .equ $1000
MEMORY_PPU_END       .equ $2000

; first character (space) tile id
SPACE                .equ $10

; subroutines in the RAM
RAMCODE              .equ $0400
waitblank            .equ $0400
scroll_fix           .equ $0460
printc               .equ $0480
printc_no_vblank     .equ $0483
print                .equ $0500
bleep                .equ $0520
beep                 .equ $0540
error_sound          .equ $0560
manual_mode_sound    .equ $0580
done_sound           .equ $0600
ask_disk             .equ $0640
ascii                .equ $0780
