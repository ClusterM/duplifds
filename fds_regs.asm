; BIOS calls
ReadPads             .equ $E9EB
OrPads               .equ $EA0D
ReadDownPads         .equ $EA1A
ReadOrDownPads       .equ $EA1F
ReadDownVerifyPads   .equ $EA36
ReadOrDownVerifyPads .equ $EA4C
ReadDownExpPads      .equ $EA68
SetScroll            .equ $EAEA

; FDS registers
FDS_TIMER_LOW        .equ $4020
FDS_TIMER_HIGH       .equ $4021
FDS_TIMER_CONTROL    .equ $4022
FDS_MASTER_IO        .equ $4023
FDS_DATA_WRITE       .equ $4024
FDS_CONTROL          .equ $4025
FDS_EXT_WRITE        .equ $4026
FDS_DISK_STATUS      .equ $4030
FDS_DATA_READ        .equ $4031
FDS_DRIVE_STATUS     .equ $4032
FDS_EXT_READ         .equ $4033

; values for FDS_CONTROL
FDS_CONTROL_MOTOR_ON      .equ %00100001
FDS_CONTROL_MOTOR_OFF     .equ %00100010
FDS_CONTROL_READ          .equ %00100100
FDS_CONTROL_WRITE         .equ %00100000
FDS_CONTROL_CRC           .equ %00110000
FDS_CONTROL_TRANSFER_ON   .equ %01100000
FDS_CONTROL_IRQ_ON        .equ %10100000

; values for FDS_DRIVE_STATUS
FDS_DRIVE_STATUS_DISK_NOT_INSERTED    .equ %00000001
FDS_DRIVE_STATUS_DISK_NOT_READY       .equ %00000010
FDS_DRIVE_STATUS_DISK_WRITE_PROTECTED .equ %00000100

; values for FDS_DISK_STATUS
FDS_DISK_STATUS_TIMER_IRQ      .equ %00000001
FDS_DISK_STATUS_BYTE_TRANSFER  .equ %00000010
FDS_DISK_STATUS_CRC_ERROR      .equ %00010000
FDS_DISK_STATUS_END_OF_HEAD    .equ %01000000
FDS_DISK_STATUS_DATA_ENABLE    .equ %10000000

; variables reserved by BIOS
  .rsset $00F5
JOY1_NEWPRESS    .rs 1
JOY2_NEWPRESS    .rs 1
JOY1_HOLD        .rs 1
JOY2_HOLD        .rs 1
  .rsset $00FC
MIRR_SCROLL_X         .rs 1
MIRR_SCROLL_Y         .rs 1
MIRR_PPU_MASK  .rs 1
MIRR_PPU_CTRL  .rs 1
  .rsset $0100
NMI_ACTION       .rs 1
IRQ_ACTION       .rs 1
RESET_FLAG       .rs 1
RESET_TYPE       .rs 1

; IRQ vectors
  .rsset $DFFA
NMI_VECTOR       .rs 2
RESET_VECTOR     .rs 2
IRQ_VECTOR       .rs 2