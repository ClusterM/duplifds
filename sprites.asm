  ; sprites data

  ;  Attributes:
  ;  76543210
  ;  ||||||||
  ;  ||||||++- Palette (4 to 7) of sprite
  ;  |||+++--- Unimplemented (read 0)
  ;  ||+------ Priority (0: in front of background; 1: behind background)
  ;  |+------- Flip sprite horizontally
  ;  +-------- Flip sprite vertically

  ; Y, tile #, attributes, X
sprites:
  .db 60, $F0, %00100000, 223
  .db 75, $F1, %00100000, 223
  .db 90, $F2, %00100000, 223
  .db 92, $F3, %00100001, 149 + 8*0
  .db 92, $F3, %00100001, 149 + 8*1
  .db 92, $F3, %00100001, 149 + 8*2 

sprites_end:
