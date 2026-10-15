; ===== input.asm: mouse packet handling + PS/2 mouse driver =====

; ---- process one 3 byte mouse packet ----
handle_packet:
    movsx eax, byte [pkt+1]     ; x movement
    mov [ddx], eax
    movsx eax, byte [pkt+2]     ; y movement (mouse up = positive, screen is flipped)
    neg eax
    mov [ddy], eax

    mov eax, [mx]               ; move the cursor
    add eax, [ddx]
    mov ebx, 2                  ; keep 2 pixels from the edge so the outline fits
    mov ecx, SCREEN_W - 16
    call clamp
    mov [mx], eax

    mov eax, [my]
    add eax, [ddy]
    mov ebx, 2
    mov ecx, SCREEN_H - 24
    call clamp
    mov [my], eax

    mov al, [pkt]               ; left button state
    and al, 1
    mov bl, [prev_btn]
    mov [prev_btn], al
    test al, al
    jnz .held
    mov byte [drag], 0
    jmp .done
.held:
    cmp byte [drag], 1
    je .moving
    test bl, bl                 ; was it already held? then it isn't a fresh click
    jnz .done
    call handle_click
    jmp .done
.moving:
    mov eax, [wx]
    add eax, [ddx]
    xor ebx, ebx
    mov ecx, SCREEN_W - WIN_W
    call clamp
    mov [wx], eax
    mov eax, [wy]
    add eax, [ddy]
    xor ebx, ebx
    mov ecx, TASKBAR_Y - WIN_H
    call clamp
    mov [wy], eax
.done:
    mov byte [dirty], 1         ; something changed, redraw when the packets stop coming
    ret

; ================= PS/2 KEYBOARD: scancode -> typing into the notepad buffer =================
; ---- handle_key: al = raw scancode byte just read from port 0x60 ----
handle_key:
    test al, 0x80                ; bit 7 set = key release (break code)
    jnz .brk
    cmp al, 0x2A                 ; left shift pressed
    je .shift_on
    cmp al, 0x36                 ; right shift pressed
    je .shift_on
    cmp al, 0x0E                 ; backspace
    je .bksp
    cmp al, 0x1C                 ; enter
    je .enter
    cmp al, 0x3A                 ; beyond our table (F-keys, capslock, keypad, ...)
    jae .ignore
    movzx ebx, al
    cmp byte [shift_held], 0
    jne .hi
    movzx eax, byte [kbd_lo + ebx]
    jmp .have
.hi:
    movzx eax, byte [kbd_hi + ebx]
.have:
    test eax, eax                 ; 0 = no character on this key (ctrl, alt, ...)
    jz .ignore
    call text_insert
.ignore:
    ret
.bksp:
    call text_backspace
    ret
.enter:
    mov eax, 10
    call text_insert
    ret
.shift_on:
    mov byte [shift_held], 1
    ret
.brk:
    and al, 0x7F
    cmp al, 0x2A
    je .shift_off
    cmp al, 0x36
    je .shift_off
    ret
.shift_off:
    mov byte [shift_held], 0
    ret

; ---- text_insert: eax = ascii character to type into the open window ----
text_insert:
    cmp byte [win_open], 0
    je .no
    mov ebx, [text_len]
    cmp ebx, TEXT_BUF_MAX - 2    ; leave room for the character + null terminator
    jae .no
    mov [text_buf + ebx], al
    inc ebx
    mov [text_len], ebx
    mov byte [text_buf + ebx], 0
    mov byte [dirty], 1
.no:
    ret

; ---- text_backspace: delete the last typed character ----
text_backspace:
    cmp byte [win_open], 0
    je .no
    mov ebx, [text_len]
    test ebx, ebx
    jz .no
    dec ebx
    mov byte [text_buf + ebx], 0
    mov [text_len], ebx
    mov byte [dirty], 1
.no:
    ret

; US QWERTY, scancode set 1, indices 0x00-0x39. 0 = no character on that key.
kbd_lo: db 0,   0,   '1','2','3','4','5','6','7','8'
        db '9', '0', '-','=', 0,   0,  'q','w','e','r'
        db 't', 'y', 'u','i','o','p','[',']', 0,   0
        db 'a', 's', 'd','f','g','h','j','k','l',';'
        db 39,  '`', 0,  '\','z','x','c','v','b','n'
        db 'm', ',', '.','/', 0,   0,   0,  ' '

kbd_hi: db 0,   0,   '!','@','#','$','%','^','&','*'
        db '(', ')', '_','+', 0,   0,  'Q','W','E','R'
        db 'T', 'Y', 'U','I','O','P','{','}', 0,   0
        db 'A', 'S', 'D','F','G','H','J','K','L',':'
        db 34,  '~', 0,  '|','Z','X','C','V','B','N'
        db 'M', '<', '>','?', 0,   0,   0,  ' '

; ---- clamp eax between ebx (min) and ecx (max), signed ----
clamp:
    cmp eax, ebx
    jge .a
    mov eax, ebx
.a:
    cmp eax, ecx
    jle .b
    mov eax, ecx
.b:
    ret

; ================= PS/2 MOUSE DRIVER =================
wait_in:                        ; wait until the controller can take a byte
    in al, 0x64
    test al, 2
    jnz wait_in
    ret

wait_out:                       ; wait until a byte is ready to read
    in al, 0x64
    test al, 1
    jz wait_out
    ret

mouse_cmd:                      ; send al to the mouse, eat the ACK
    mov bl, al
    call wait_in
    mov al, 0xD4                ; "next byte goes to the mouse"
    out 0x64, al
    call wait_in
    mov al, bl
    out 0x60, al
    call wait_out
    in al, 0x60
    ret

mouse_init:
.flush:                         ; empty any leftover bytes
    in al, 0x64
    test al, 1
    jz .go
    in al, 0x60
    jmp .flush
.go:
    call wait_in
    mov al, 0xA8                ; enable the mouse port
    out 0x64, al
    call wait_in
    mov al, 0x20                ; read controller config
    out 0x64, al
    call wait_out
    in al, 0x60
    and al, 0xDC                ; no IRQs (we poll), mouse clock on
    mov bl, al
    call wait_in
    mov al, 0x60                ; write controller config
    out 0x64, al
    call wait_in
    mov al, bl
    out 0x60, al
    mov al, 0xF6                ; mouse default settings
    call mouse_cmd
    mov al, 0xF4                ; start sending movement data
    call mouse_cmd
    ret
