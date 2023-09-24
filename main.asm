  .include "vars.asm"
  .include "fds_regs.asm"
  .include "macroses.asm"

  ; vectors
  .org $DFFA  ; start at $DFFA
  .dw NMI
  .dw Start
  .dw IRQ_disk_read

  .org $D000  ; code starts at $D000
Start:
  ; disable PPU
  lda #%00000000
  sta PPUCTRL
  sta PPUMASK
  ; warm-up
  jsr waitblank
  jsr waitblank 

  lda #(FDS_CONTROL_READ | FDS_CONTROL_MOTOR_OFF)
  sta FDS_CONTROL

  ; clean memory
;  lda #$00
;  sta <COPY_SOURCE_ADDR
;  lda #$02
;  sta <COPY_SOURCE_ADDR + 1
;  lda #$00
;  ldy #$00
;  ldx #$06
;.loop:
;  sta [COPY_SOURCE_ADDR], y
;  iny
;  bne .loop
;  inc <COPY_SOURCE_ADDR+1
;  dex
;  bne .loop

  ; use IRQ at $DFFE
  lda #$C0
  sta IRQ_ACTION
  ; return to BIOS on reset
  lda #$00
  sta RESET_FLAG
  sta RESET_TYPE

  ; loading palette
load_palette:
  jsr waitblank
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
.loop:
  lda palette, x
  sta PPUDATA
  inx
  cpx #16
  bne .loop

  ; loading blank nametable
;clear_nametable:
;  lda PPUSTATUS
;  lda #$20
;  sta PPUADDR
;  lda #$00
;  sta PPUADDR
;  ldy #0
;  ldx #0
;  lda #$20
;.loop:
;  cpy #$C0
;  bne .noat
;  cpx #$03
;  bne .noat
;  lda #$00
;.noat:
;  sta PPUDATA
;  iny
;  bne .loop
;  inx
;  cpx #$04
;  bne .loop
;.end:

  ; enable PPU
  bit PPUSTATUS
  lda #0
  sta PPUADDR
  sta PPUADDR
  jsr waitblank
  lda #%00001010
  sta PPUMASK  

  cli ; enable interrupts

main:
  lda #0
  sta <BLOCKS_READ
  sta <BLOCKS_WRITTEN
  sta <BLOCK_AMOUNT
  sta <FILE_AMOUNT
  sta <READ_FULL

.copy_loop
  jsr ask_source_disk
  lda #OPERATION_READING
  sta <OPERATION
  jsr transfer
  ;print "BLOCKS: "
  ldx <BLOCKS_READ
  ;jsr write_byte
  ;jsr next_line
  ;print "RESULT CODE: "
  ;ldx <STOP_REASON
  ;jsr write_byte
  ;jsr next_line

  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  bne .not_crc_error
  ; it's ok if all visible files are read
  lda <BLOCKS_READ
  cmp #2
  bcs .somethig_read
  ; can't read anything
  jmp print_error
.somethig_read:
  lda <BLOCKS_READ
  cmp <BLOCK_AMOUNT
  bcs .not_crc_error_disk_done
  ; bad block :(
  jmp print_error
.not_crc_error_disk_done:
  inc <READ_FULL
  jmp .ok_lets_write
.not_crc_error:
  ; out of memory?
  lda <STOP_REASON
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  lda <BLOCKS_READ
  cmp <BLOCKS_WRITTEN
  bne .memory_non_clitical
  ; can't fit in the memory ever single block
  jmp print_error
.memory_non_clitical:
  ; it's ok, we'll write in multiple passes
  jmp .ok_lets_write
.not_out_of_memory:
  ; other error
  jmp print_error
.ok_lets_write:

  ;jsr waitblank
  ;jsr update_cursor
  ;lda #$00
  ;sta <COPY_SOURCE_ADDR
  ;lda #$60
  ;sta <COPY_SOURCE_ADDR + 1
  ;jsr hexdump
  ;jsr next_line
  jsr ask_target_disk
  lda #OPERATION_WRITING
  sta <OPERATION
  jsr transfer
  ;print "RESULT CODE: "
  ;ldx <STOP_REASON
  ;jsr write_byte
  ;jsr next_line
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .write_ok
  jmp print_error
.write_ok:
  lda READ_FULL
  bne .copy_done
  jmp .copy_loop
.copy_done:

  ; check it
  print "CHECKING CRC..."
  jsr transfer
  ;print "RESULT CODE: "
  ;ldx <STOP_REASON
  ;jsr write_byte
  ;jsr next_line
  lda <STOP_REASON
  cmp #STOP_NONE
  beq .verify_ok
  jmp print_error
.verify_ok:

  print "DONE!"

.wait_eject
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject  
  jmp main

  ; main loop        
infin:
  jsr waitblank
  jsr ReadOrDownPads
  jmp infin

print_error:
  lda <STOP_REASON
  cmp #STOP_CRC_ERROR
  bne .not_crc
  print "ERR: BAD BLOCK"
  jmp infin
.not_crc:
  cmp #STOP_OUT_OF_MEMORY
  bne .not_out_of_memory
  print "ERR:OUT OF MEMORY"
  jmp infin
.not_out_of_memory:
  cmp #STOP_NO_DISK
  bne .not_no_disk
  print "ERR:NO DISK"
  jmp infin
.not_no_disk:
  cmp #STOP_NO_POWER
  bne .not_no_power
  print "ERR:NO POWER"
  jmp infin
.not_no_power:
  cmp #STOP_END_OF_HEAD
  bne .not_end_of_head
  print "ERR:DISK IS FULL"
  jmp infin
.not_end_of_head:
  cmp #STOP_WRONG_HEADER
  bne .not_wrong_header
  print "ERR:DIFFERENT DISK"
  jmp infin
.not_wrong_header:
  cmp #STOP_NOT_READY
  bne .not_not_ready
  print "ERR:NOT READY"
  jmp infin
.not_not_ready:
  print "UNKNOWN ERROR"
  jmp infin

ask_source_disk:
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_eject  
  print "EJECT DISK"
.wait_eject
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject  
  print "INSERT SOURCE DISK"  
.wait_insert
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  print "READING..."
  rts

ask_target_disk:
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_eject  
  print "EJECT DISK"
.wait_eject
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject  
  print "INSERT TARGET DISK"  
.wait_insert
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  print "WRITING..."
  rts

waitblank:
  jsr scroll_fix
  bit PPUSTATUS
.loop:
  bit PPUSTATUS  ; load A with value at location PPUSTATUS
  bpl .loop  ; if bit 7 is not set (not VBlank) keep checking
  rts

scroll_fix:
  ; fix scrolling
  pha
  bit PPUSTATUS
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  pla
  rts

  ; write message
write_text:
  jsr waitblank
  bit PPUSTATUS
  lda #$22
  sta PPUADDR
  lda #$26
  sta PPUADDR
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  bmi .end ; skip $80-$FF
  tax 
  lda .ascii, x
  sta PPUDATA
  iny
  cpy #18
  bne .loop
  jsr scroll_fix
  rts
.end:
  lda #0  
.loop_blank:
  cpy #18
  bne .print_space
  jsr scroll_fix
  rts
.print_space:
  sta PPUDATA
  iny
  bne .loop_blank
.ascii:
  ; characters 0-31
  .db $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00
  ; characters: <space>!"#$%&'
  .db $00, $01, $02, $03, $04, $05, $06, $07
  ; characters: ()*+,-./
  .db $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  ; characters: 01234567
  .db $10, $11, $12, $13, $14, $15, $16, $17
  ; characters: 89:;<=>?
  .db $18, $19, $1A, $1B, $1C, $1D, $1E, $1F
  ; characters: @ABCDEFG
  .db $20, $21, $22, $23, $24, $25, $26, $27
  ; characters: HIJKLMNO
  .db $28, $29, $2A, $2B, $2C, $2D, $2E, $10
  ; characters: PQRSTUVW
  .db $2F, $30, $31, $32, $33, $34, $35, $36
  ; characters: XYZ[\]^_
  .db $37, $38, $39, $3A, $3B, $3C, $3D, $3E
  ; characters: 'abcdefg
  .db $3F, $21, $22, $23, $24, $25, $26, $27
  ; characters: hijklmno
  .db $28, $29, $2A, $2B, $2C, $2D, $2E, $10
  ; characters: pqrstuvw
  .db $2F, $30, $31, $32, $33, $34, $35, $36
  ; characters: xyz{|}~
  .db $37, $38, $39, $40, $41, $42, $43, $00

; delay for TIMER_COUNTER*1000 CPU cycles
delay_sub:
  set_IRQ IRQ_delay
  lda #(1000 & $FF)
  sta FDS_TIMER_LOW
  lda #((1000 >> 8) & $FF)
  sta FDS_TIMER_HIGH
  lda #%00000011
  sta FDS_TIMER_CONTROL
.wait:  
  lda <TIMER_COUNTER + 1
  bne .wait
  lda <TIMER_COUNTER
  bne .wait
  lda #%00000000
  sta FDS_TIMER_CONTROL
  rts

IRQ_delay:
  bit FDS_DISK_STATUS
  lda <TIMER_COUNTER
  bne .decr
  lda <TIMER_COUNTER + 1
  bne .decr
  lda #%00000000
  sta FDS_TIMER_CONTROL
  rti
.decr:
  lda <TIMER_COUNTER  
  sec
  sbc #1
  sta <TIMER_COUNTER  
  lda <TIMER_COUNTER + 1
  sbc #0
  sta <TIMER_COUNTER + 1
.end:
  rti

NMI:
  ; reset to the main entry point
  lda #$35
  sta $102
  lda #$AC
  sta $103
  jmp [$FFFC]

nametable:
;  .incbin "bg_name_table.bin"
;  .org nametable + $3C0
;  .incbin "bg_attr_table.bin"
palette: 
  .incbin "palette0.bin"
  .incbin "palette1.bin"
  .incbin "palette2.bin"
  .incbin "palette3.bin"
  .include "disk.asm"
