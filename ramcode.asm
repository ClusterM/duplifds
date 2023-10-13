waitblank:
  pha
  txa
  pha
  tya
  pha
  jsr read_controller
  jsr parse_buttons
  jsr scroll_fix
  bit PPUSTATUS
.loop:
  bit PPUSTATUS  ; load A with value at location PPUSTATUS
  bpl .loop  ; if bit 7 is not set (not VBlank) keep checking
  pla
  tay
  pla
  tax
  pla
  rts

parse_buttons:
  ; enable manual mode if select pressed
  lda <JOY_BOTH_HOLD
  cmp <JOY_BOTH_LAST
  beq .no_buttons_action
  sta <JOY_BOTH_LAST
  and #BTN_SELECT
  beq .no_manual
  ; already manual mode?
  lda MANUAL_MODE
  bne .no_manual
  lda #1
  sta MANUAL_MODE
  jsr manual_mode_sound
.no_manual:
  lda <JOY_BOTH_HOLD
  and #BTN_B
  beq .normal_reset
  lda #$35
  sta RESET_FLAG
  lda #$53
  sta RESET_TYPE
  jmp .reset_end
.normal_reset:
  lda #0
  sta RESET_FLAG
  sta RESET_TYPE
.reset_end:
.no_buttons_action:
  rts

read_controller:
  ; read controller
  lda #1
  sta JOY1
  lda #0
  sta JOY1
  ldy #8
.read_button:
  lda JOY1
  and #$03
  cmp #$01
  ror <JOY1_HOLD
  lda JOY2
  and #$03
  cmp #$01
  ror <JOY2_HOLD
  dey
  bne .read_button
  lda <JOY1_HOLD
  ora <JOY2_HOLD
  sta <JOY_BOTH_HOLD
  rts

scroll_fix:
  ; fix scrolling
  pha
  bit PPUSTATUS
  lda #0
  sta PPUSCROLL
  lda <Y_OFFSET
  sta PPUSCROLL
  cmp #240
  bne .first_screen
  lda #%00000010
  sta PPUCTRL
  pla
  rts
.first_screen:
  lda #%00000000
  sta PPUCTRL
  pla
  rts

  ; write message to the center line
printc:
  jsr waitblank
printc_no_vblank:
  PPU_to 6, 17
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  bmi .end ; skip $80-$FF
  sec
  sbc #$20
  tax
  lda ascii, x
  sta PPUDATA
  iny
  cpy #18
  bne .loop
  jsr scroll_fix
  rts
.end:
  lda #SPACE
.loop_blank:
  cpy #18
  bne .print_space
  jsr scroll_fix
  rts
.print_space:
  sta PPUDATA
  iny
  bne .loop_blank

print:
  ; just write message
  ldy #0
.loop:
  lda [COPY_SOURCE_ADDR], y
  bmi .end ; skip $80-$FF
  sec
  sbc #$20
  tax
  lda ascii, x
  sta PPUDATA
  iny
  bne .loop
.end:
  rts

wait_button_or_eject:
  ; wait until any button is pressed or disk is ejected
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne wait_button_or_eject
.wait:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .end
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait
.end:
  rts

wait_button_or_insert:
  ; wait until any button is pressed or disk is insertes
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne wait_button_or_insert
.wait:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .end
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait
.end:
  rts

ask_retry_cancel:
  printc_ptr (ask_retry_cancel + (.str_ask_retry_cancel - ask_retry_cancel))
.wait_no_button
  jsr waitblank
  lda <JOY_BOTH_HOLD
  bne .wait_no_button
.wait_button:
  jsr waitblank
  lda <JOY_BOTH_HOLD
  and #BTN_A
  bne .a
  lda <JOY_BOTH_HOLD
  and #BTN_B
  bne .b
  beq .wait_button
.a:
  ldx #1
  rts
.b:
  ldx #0
  rts
.str_ask_retry_cancel:
  .db "A-RETRY   B-CANCEL"

divide10:
  ; input: a - dividend 
  ; output: a - remainder, x = quotient
  ldx #0
.div_loop:
  cmp #10
  bcc .done
  sec
  sbc #10
  inx
  bne .div_loop
.done:
  rts
