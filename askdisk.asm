ask_disk:
  jsr bleep
  ; skip .wait_eject if the disk already ejected
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert  
.wait_eject:
  jsr eject_disk_animation
  ; check for select press
  lda <MANUAL_MODE
  beq .no_manual
  ; enable manual mode
  jmp .wait_insert
.no_manual:
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject
  jsr eject_disk_animation  
.wait_insert:
  jsr waitblank
  lda #0
  sta <ANIMATION_STATE
  jsr blink_eject_button
.wait_insert_reset:
  lda #0
  ; lets reuse this variable
  sta <TIMER_COUNTER
.wait_insert_loop:
  jsr insert_disk_animation
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert_reset
  ; wait some time after disk insert
  lda <TIMER_COUNTER
  cmp #10
  beq .check_manual
  inc <TIMER_COUNTER
  jmp .wait_insert_loop
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
  jsr blink_disk
  rts

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
  jsr blink_eject_button
.print_text:
  printc_ptr_no_vblank str_eject_disk
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

insert_disk_animation:
  inc <ANIMATION_STATE
  jsr waitblank
  jsr blink_disk
  lda <MANUAL_MODE
  beq .no_manual
  lda <ANIMATION_STATE
  and #%01000000
  bne .ask_press_start
.no_manual:
  lda <OPERATION
  bne .target_disk
  printc_ptr_no_vblank str_insert_source_disk
  rts
.target_disk:
  printc_ptr_no_vblank str_insert_target_disk
  rts
.ask_press_start:
  printc_ptr_no_vblank str_and_press_start
  rts
