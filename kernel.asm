; ============================================================
;  BIBI OS  -  kernel.asm
;  Part 1 (16-bit): ask the video BIOS for an 800x600 32-bit color
;                   mode, then switch the CPU into 32-bit protected mode.
;  Part 2 (32-bit): the kernel main loop.
;
;  Modules:
;     defs.asm   - shared constants (screen size, layout)
;     input.asm  - PS/2 mouse driver + mouse packet handling
;     gui.asm    - desktop, window, start menu, click handling
;     gfx.asm    - rectangles, cursor, text engine, screen copy
;     data.asm   - strings and variables
;     font.asm   - the BIBI OS pixel font
; ============================================================
%include "defs.asm"

[org 0x7e00]
[bits 16]

kernel_start:
    cld
    call vbe_setup              ; set the video mode (needs the BIOS, so do it now)
    cli
    in al, 0x92                 ; turn on the A20 line (access to memory above 1MB)
    or al, 2
    and al, 0xFE
    out 0x92, al
    lgdt [gdt_desc]             ; load our segment table
    mov eax, cr0
    or eax, 1                   ; PE bit = protected mode ON
    mov cr0, eax
    jmp 0x08:pm_start           ; far jump into the 32-bit code segment

; ---- find and set an SCREEN_W x SCREEN_H, 32 bit per pixel mode with a linear framebuffer ----
vbe_setup:
    mov di, 0x1200              ; buffer for the controller info
    mov dword [di], 'VBE2'      ; ask for the VBE 2.0 version of the info block
    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne vbe_fail
    mov bx, [0x1200 + 14]       ; pointer to the list of modes (offset)
    mov ax, [0x1200 + 16]       ; ... and its segment
    mov fs, ax
.next:
    mov cx, [fs:bx]             ; next mode number in the list
    add bx, 2
    cmp cx, 0xFFFF              ; end of list = nothing matched
    je vbe_fail
    push bx
    push cx
    mov di, 0x1000              ; buffer for this mode's info
    mov ax, 0x4F01
    int 0x10
    pop cx
    pop bx
    cmp ax, 0x004F
    jne .next
    mov ax, [0x1000]            ; mode attributes
    and ax, 0x0081              ; bit 0 = supported, bit 7 = has linear framebuffer
    cmp ax, 0x0081
    jne .next
    cmp word [0x1000 + 0x12], SCREEN_W
    jne .next
    cmp word [0x1000 + 0x14], SCREEN_H
    jne .next
    cmp byte [0x1000 + 0x19], 32
    jne .next
    mov eax, [0x1000 + 0x28]    ; physical address of the framebuffer
    mov [fb_addr], eax
    movzx eax, word [0x1000 + 0x10]   ; bytes per row on the real screen
    mov [fb_pitch], eax
    mov bx, cx
    or bx, 0x4000               ; "use the linear framebuffer"
    mov ax, 0x4F02
    int 0x10
    cmp ax, 0x004F
    jne vbe_fail
    ret

vbe_fail:
    mov si, vbe_msg
.p:
    lodsb
    or al, al
    jz .halt
    mov ah, 0x0e
    int 0x10
    jmp .p
.halt:
    cli
    hlt
    jmp .halt

; ---- the GDT: tells the CPU what memory segments exist ----
gdt:
    dq 0                                ; 0x00: null
    dw 0xFFFF, 0x0000                   ; 0x08: code, base 0, limit 4GB, 32 bit
    db 0x00, 0x9A, 0xCF, 0x00
    dw 0xFFFF, 0x0000                   ; 0x10: data, base 0, limit 4GB
    db 0x00, 0x92, 0xCF, 0x00
gdt_end:
gdt_desc:
    dw gdt_end - gdt - 1
    dd gdt

; ================= 32-BIT KERNEL STARTS HERE =================
[bits 32]
pm_start:
    mov ax, 0x10                ; load the data segment into everything
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000            ; stack
    cld
    call mouse_init
    call render

main:
    in al, 0x64                 ; any byte waiting from the PS/2 controller?
    test al, 1
    jnz .have
    cmp byte [dirty], 0         ; nothing waiting: redraw if something changed
    je main
    mov byte [dirty], 0
    call render
    jmp main
.have:
    mov ah, al
    in al, 0x60
    test ah, 0x20               ; bit 5 = byte came from the mouse
    jnz .mouse
    call handle_key
    jmp main
.mouse:
    movzx ebx, byte [idx]
    test ebx, ebx
    jnz .store
    test al, 8                  ; first byte of a packet always has bit 3 set
    jz main
.store:
    mov [pkt + ebx], al
    inc ebx
    cmp ebx, 3
    jne .save
    mov byte [idx], 0
    call handle_packet          ; got a full 3 byte packet
    jmp main
.save:
    mov [idx], bl
    jmp main

%include "input.asm"
%include "gui.asm"
%include "gfx.asm"
%include "data.asm"
%include "font.asm"

; pad the kernel to exactly KERNEL_SECTORS (see boot.asm). If the kernel grows
; past this, NASM errors out - just raise the number in both files.
times 16384 - ($ - $$) db 0
