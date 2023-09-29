  .org (ask_disk - RAMCODE)
  ; wait until a disk is inserted
ask_disk_ram:
  jsr bleep
  ; skip .wait_eject if the disk already ejected
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .to_wait_insert  
.wait_eject:
  jsr (ask_disk + (eject_disk_animation - ask_disk_ram))
  ; check for select press
  lda <MANUAL_MODE
  beq .no_manual
  ; enable manual mode
  jmp (ask_disk + (.to_wait_insert - ask_disk_ram))
.no_manual:
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject
  jsr (ask_disk + (eject_disk_animation - ask_disk_ram))  
.to_wait_insert:
  jsr waitblank
  lda #0
  sta <ANIMATION_STATE
  jsr (ask_disk + (blink_eject_button - ask_disk_ram))
  jmp (ask_disk + (wait_insert - ask_disk_ram))

blink_eject_button:
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR  
  lda #$12
  sta PPUADDR
  lda <ANIMATION_STATE
  and #%00010000
  beq .normal
  lda #$38
  sta PPUDATA
  rts
.normal:
  lda #$28
  sta PPUDATA
  rts

eject_disk_animation:
  inc <ANIMATION_STATE
  jsr waitblank
  jsr (ask_disk + (blink_eject_button - ask_disk_ram))
.print_text:
  printc_ptr_no_vblank (ask_disk + (str_eject_disk - ask_disk_ram))
  rts

wait_insert:
  lda #0
  ; lets reuse this variable
  sta <TIMER_COUNTER
.wait_insert_loop:
  jsr (ask_disk + (insert_disk_animation - ask_disk_ram))
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne wait_insert
  ; wait some time after disk insert
  lda <TIMER_COUNTER
  cmp #10
  beq .check_manual
  inc <TIMER_COUNTER
  jmp (ask_disk + (.wait_insert_loop - ask_disk_ram))
.check_manual:
  ; check for manual mode
  lda <MANUAL_MODE
  beq .end
  ; check for start press
  lda JOY1_HOLD
  ora JOY2_HOLD
  and #BTN_START
  beq .wait_insert_loop
.end:
  jsr waitblank
  lda #0
  sta ANIMATION_STATE
  jsr (ask_disk + (blink_disk - ask_disk_ram))
  rts

insert_disk_animation:
  inc <ANIMATION_STATE
  jsr waitblank
  jsr (ask_disk + (blink_disk - ask_disk_ram))
  ; print text
  lda <MANUAL_MODE
  beq .no_manual
  lda <ANIMATION_STATE
  and #%01000000
  bne .ask_press_start
.no_manual:
  lda <OPERATION
  bne .target_disk
  printc_ptr_no_vblank (ask_disk + (str_insert_source_disk - ask_disk_ram))
  rts
.target_disk:
  printc_ptr_no_vblank (ask_disk + (str_insert_target_disk - ask_disk_ram))
  rts
.ask_press_start:
  printc_ptr_no_vblank (ask_disk + (str_and_press_start - ask_disk_ram))
  rts

blink_disk:
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR  
  lda #$07
  sta PPUADDR
  lda <ANIMATION_STATE
  and #%00010000
  beq .normal
  lda #$38
  sta PPUDATA
  rts
.normal:
  lda #$28
  sta PPUDATA
  rts

str_eject_disk:
  .db "EJECT DISK", $FF
str_insert_source_disk:
  .db "INSERT SOURCE DISK", $FF
str_insert_target_disk:
  .db "INSERT TARGET DISK", $FF
str_and_press_start:
  .db "AND PRESS START", $FF
