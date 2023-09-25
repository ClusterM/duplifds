ask_source_disk:
  ; TODO: button mode
  ; TODO: sounds?
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_eject  
  printc_ptr str_eject_disk
.wait_eject
  jsr eject_disk_animation
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject
  lda #0
  sta <ANIMATION_STATE
  jsr eject_disk_animation
  printc_ptr str_insert_source_disk
.wait_insert
  jsr insert_disk_animation
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  lda #0
  sta <ANIMATION_STATE
  jsr insert_disk_animation
  printc_ptr str_reading
  rts

ask_target_disk:
  ; TODO: button mode
  ; TODO: sounds?
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_eject  
  printc_ptr str_eject_disk
.wait_eject
  jsr eject_disk_animation
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  beq .wait_eject
  lda #0
  sta <ANIMATION_STATE
  jsr eject_disk_animation
  printc_ptr str_insert_target_disk
.wait_insert
  jsr insert_disk_animation
  lda FDS_DRIVE_STATUS
  and #FDS_DRIVE_STATUS_DISK_NOT_INSERTED
  bne .wait_insert
  lda #0
  sta <ANIMATION_STATE
  jsr insert_disk_animation
  printc_ptr str_writing
  rts

eject_disk_animation:
  jsr waitblank
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR  
  lda #$12
  sta PPUADDR
  inc <ANIMATION_STATE
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
  jsr waitblank
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR  
  lda #$07
  sta PPUADDR
  inc <ANIMATION_STATE
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
