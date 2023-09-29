bleep:
  ; enable channel
  lda #%00000001
  sta APUSTATUS
  ; square 1
  lda #%10000111
  sta SQ1VOL
  ; sweep
  lda #%10001001
  sta SQ1SWEEP
  lda #%11110000
  ; timer
  sta SQ1LO
  ; length counter and timer
  lda #%00001000
  sta SQ1HI
  rts

beep:
  ; enable channel
  lda #%00000100
  sta APUSTATUS
  ; triangle
  lda #%01000000
  sta TRILINEAR
  ; timer
  lda #%1000000
  sta TRILO
  ; length counter and timer
  lda #%00001000
  sta TRIHI
  rts

error_sound:
  ; enable channel
  lda #%00000100
  sta APUSTATUS
  ; triangle
  lda #%01001111
  sta TRILINEAR
  ; timer
  lda #%00000000
  sta TRILO
  ; length counter and timer
  lda #%11110011
  sta TRIHI
  rts

manual_mode_sound:
  ;enable channel
  lda #%00000001
  sta APUSTATUS
  ;square 1
  lda #%00011111
  sta SQ1VOL
  ; sweep
  lda #%10011010
  sta SQ1SWEEP
  ; timer
  lda #%11111111
  sta SQ1LO
  ; length counter and timer
  lda #%10010000
  sta SQ1HI
  rts

done_sound:
  ; enable channel
  lda #%00000001
  sta APUSTATUS
  ; square 1
  lda #%10011111
  sta SQ1VOL
  ; sweep
  lda #%10000011
  sta SQ1SWEEP
  ; timer
  lda #%00100000
  sta SQ1LO
  ; length counter and timer
  lda #%11000000
  sta SQ1HI
  rts
