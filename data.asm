; ===== data.asm: strings and variables =====
s_start db "BIBI", 0
s_title db "Notepad", 0
s_ver   db "BIBI OS v0.2", 0
s_x     db "X", 0
s_m0    db "New window", 0
s_m1    db "Change color", 0
s_m2    db "Restart", 0
s_hint  db "Click here and start typing...", 0
vbe_msg db "BIBI OS: no 32-bit video mode found", 0

text_buf times TEXT_BUF_MAX db 0    ; what's typed into the notepad window
text_len   dd 0
shift_held db 0
pa_x0      dd 0                     ; paragraph engine: left margin, cursor, clip box
pa_x       dd 0
pa_y       dd 0
pa_right   dd 0
pa_bottom  dd 0
caret_x    dd 0                     ; where the typing cursor should be drawn
caret_y    dd 0

menu_tbl dd s_m0, s_m1, s_m2
cur_off  dd -2, 0, 2, 0, 0, -2, 0, 2   ; where the white outline copies go
desk_tbl dd 0x2B6CB0, 0x1E7B4A, 0x7A2E8E, 0xB04A2B, 0x2D2D2D, 0x008080

fb_addr  dd 0                   ; real framebuffer address + row size (filled in by vbe_setup)
fb_pitch dd 0
tcol     dd 0                   ; text color and size
tscale   dd 1
cadv     dd 0
t_x      dd 0
t_y      dd 0
t_sy     dd 0
c_col    dd 0
c_x      dd 0
c_y      dd 0
mi       dd 0
iy       dd 0
mx       dd SCREEN_W / 2        ; cursor position
my       dd SCREEN_H / 2
ddx      dd 0                   ; last mouse movement
ddy      dd 0
wx       dd 220                 ; window position
wy       dd 140
pkt      db 0, 0, 0
idx      db 0
drag     db 0
win_open db 1
menu     db 0
desk     db 0
prev_btn db 0
dirty    db 0
