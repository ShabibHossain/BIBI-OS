; ===== gfx.asm: render, screen copy, cursor, rectangles, text engine (32 bit color) =====

; ---- draw everything off-screen, then copy it to the real screen ----
render:
    call draw_scene

    mov esi, cur_off            ; cursor = white outline (4 shifted copies) ...
    mov ebp, 4
.o:
    mov eax, 0xFFFFFF
    mov ebx, [mx]
    add ebx, [esi]
    mov edx, [my]
    add edx, [esi + 4]
    call draw_cursor
    add esi, 8
    dec ebp
    jnz .o
    mov eax, 0x000000           ; ... with the black arrow on top
    mov ebx, [mx]
    mov edx, [my]
    call draw_cursor

    call present
    ret

; ---- copy the off-screen buffer to the real framebuffer ----
present:
    pusha
    mov esi, BACKBUF
    mov edi, [fb_addr]
    mov eax, [fb_pitch]
    cmp eax, BB_PITCH
    jne .rows
    mov ecx, SCREEN_W * SCREEN_H    ; same row size: one big copy
    rep movsd
    jmp .done
.rows:                              ; different row size: copy row by row
    mov edx, SCREEN_H
.r:
    mov ecx, SCREEN_W
    push edi
    rep movsd
    pop edi
    add edi, eax
    dec edx
    jnz .r
.done:
    popa
    ret

; ---- draw_cursor: eax=color ebx=x edx=y  (arrow made of rows, drawn 2x size) ----
draw_cursor:
    pusha
    mov [c_col], eax
    mov [c_x], ebx
    mov [c_y], edx
    mov esi, cur_tbl
    mov ebp, 10
.r:
    movzx ecx, byte [esi]
    shl ecx, 1                  ; width * 2
    mov eax, [c_col]
    mov ebx, [c_x]
    mov edx, [c_y]
    push esi
    mov esi, 2                  ; each row is 2 pixels tall
    call fill_rect
    pop esi
    inc esi
    add dword [c_y], 2
    dec ebp
    jnz .r
    popa
    ret

cur_tbl db 1,2,3,4,5,6,7,4,3,2

; ---- fill_rect: eax=color(0x00RRGGBB) ebx=x ecx=width edx=y esi=height ----
fill_rect:
    pusha
    imul edi, edx, BB_PITCH     ; y * bytes per row
    lea edi, [edi + ebx*4 + BACKBUF]
.row:
    push edi
    push ecx
    rep stosd                   ; paint one row
    pop ecx
    pop edi
    add edi, BB_PITCH
    dec esi
    jnz .row
    popa
    ret

; ================= PARAGRAPH ENGINE: wrapped, multi-line text for the notepad =================
; draw_para: esi=zero-terminated buffer (may contain \n), ebx=left x, edx=top y.
; [pa_right]/[pa_bottom] must be set first (clip box); [tcol]/[tscale] as usual.
; Wraps at the right edge, stops drawing once past the bottom edge (buffer is still
; intact either way - this only limits what's drawn). Leaves the final draw position
; in [caret_x]/[caret_y] so the caller can draw a cursor there.
draw_para:
    pusha
    mov [pa_x0], ebx
    mov [pa_x], ebx
    mov [pa_y], edx
.next:
    movzx eax, byte [esi]
    inc esi
    test eax, eax
    jz .done
    cmp eax, 10                 ; '\n'
    je .nl
    mov ecx, [tscale]           ; rough max glyph width, just for the wrap check
    imul ecx, 7
    mov ebp, [pa_x]
    add ebp, ecx
    cmp ebp, [pa_right]
    jle .fits
    push eax                    ; .newline clobbers eax - the pending char lives there
    call .newline
    pop eax
.fits:
    mov ebp, [pa_y]
    mov ecx, [tscale]
    imul ecx, 9
    add ebp, ecx
    cmp ebp, [pa_bottom]
    jg .done                    ; out of vertical room: stop drawing (buffer keeps growing)
    mov ebx, [pa_x]
    mov edx, [pa_y]
    call draw_char               ; eax=char in, eax=advance out
    add [pa_x], eax
    jmp .next
.nl:
    call .newline
    jmp .next
.newline:
    mov eax, [pa_x0]
    mov [pa_x], eax
    mov eax, [tscale]
    imul eax, 11                ; 9px glyph + 2px line gap, scaled
    add [pa_y], eax
    ret
.done:
    mov eax, [pa_x]
    mov [caret_x], eax
    mov eax, [pa_y]
    mov [caret_y], eax
    popa
    ret

; ================= TEXT ENGINE (our own font, proportional, scalable) =================
; draw_text: esi=zero-terminated string, ebx=x, edx=y, [tcol]=color, [tscale]=1 or 2
draw_text:
    pusha
.next:
    movzx eax, byte [esi]
    inc esi
    test eax, eax
    jz .done
    call draw_char
    add ebx, eax                ; move right by this glyph's width
    jmp .next
.done:
    popa
    ret

; draw_char: eax=character, ebx=x, edx=y.  Returns eax = how many pixels to advance.
draw_char:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    sub eax, 32                 ; font starts at the space character
    jb .bad
    cmp eax, 94
    jbe .ok
.bad:
    mov eax, '?' - 32           ; unknown character -> question mark
.ok:
    lea esi, [eax + eax*4]      ; index * 5
    shl esi, 1                  ; index * 10 (each glyph is 10 bytes)
    add esi, font_tbl
    movzx eax, byte [esi]       ; first byte = glyph width
    inc esi                     ; then 9 rows of pixels
    lea ecx, [eax + 1]          ; advance = (width + 1) * scale
    imul ecx, [tscale]
    mov [cadv], ecx
    mov [t_x], ebx
    mov [t_y], edx
    mov ebp, 9                  ; 9 glyph rows
.grow:
    mov eax, [tscale]
    mov [t_sy], eax             ; paint each glyph row this many times (scaling)
.srow:
    imul edi, [t_y], BB_PITCH
    mov eax, [t_x]
    lea edi, [edi + eax*4 + BACKBUF]
    mov bl, [esi]               ; the 8 bits of this glyph row
    mov ecx, 8
.bit:
    mov eax, [tcol]
    shl bl, 1                   ; leftmost bit falls into carry
    jnc .blank
    push ecx
    mov ecx, [tscale]
    rep stosd                   ; bit was 1: paint 'scale' pixels
    pop ecx
    jmp .nextbit
.blank:
    mov eax, [tscale]
    lea edi, [edi + eax*4]      ; bit was 0: skip 'scale' pixels
.nextbit:
    dec ecx
    jnz .bit
    inc dword [t_y]
    dec dword [t_sy]
    jnz .srow
    inc esi
    dec ebp
    jnz .grow
    mov eax, [cadv]
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
