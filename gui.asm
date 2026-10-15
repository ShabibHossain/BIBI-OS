; ===== gui.asm: clicks, desktop, window, start menu =====

; ---- hit: is the mouse inside rect ebx=x edx=y ecx=width esi=height ? carry set = yes ----
hit:
    mov eax, [mx]
    sub eax, ebx
    jl .no
    cmp eax, ecx
    jge .no
    mov eax, [my]
    sub eax, edx
    jl .no
    cmp eax, esi
    jge .no
    stc
    ret
.no:
    clc
    ret

; ---- a fresh left click happened at the cursor position ----
handle_click:
    cmp byte [menu], 0
    je .nomenu
    mov byte [menu], 0          ; any click closes the menu
    mov ebx, MENU_X
    mov edx, MENU_ITEM0
    mov ecx, MENU_W
    mov esi, ITEM_H * 3
    call hit                    ; did we click one of the 3 items?
    jc .item
    ret
.item:
    mov eax, [my]
    sub eax, MENU_ITEM0
    xor edx, edx
    mov ecx, ITEM_H
    div ecx                     ; eax = which item (0, 1 or 2)
    cmp eax, 0
    je .open
    cmp eax, 1
    je .color
    call wait_in                ; item 2 = restart: pull the CPU reset line
    mov al, 0xFE
    out 0x64, al
.hang:
    jmp .hang
.open:
    mov byte [win_open], 1
    ret
.color:
    movzx eax, byte [desk]
    inc eax
    cmp eax, 6
    jb .c1
    xor eax, eax
.c1:
    mov [desk], al
    ret
.nomenu:
    mov ebx, 4                  ; clicked the start button?
    mov edx, TASKBAR_Y + 4
    mov ecx, 88
    mov esi, 24
    call hit
    jnc .nostart
    mov byte [menu], 1
    ret
.nostart:
    cmp byte [win_open], 0
    jne .haswin
    ret
.haswin:
    mov ebx, [wx]               ; clicked the close button?
    add ebx, WIN_W - 26
    mov edx, [wy]
    add edx, 4
    mov ecx, 22
    mov esi, 20
    call hit
    jnc .noclose
    mov byte [win_open], 0
    ret
.noclose:
    mov ebx, [wx]               ; clicked the title bar? start dragging
    mov edx, [wy]
    mov ecx, WIN_W
    mov esi, 28
    call hit
    jnc .out
    mov byte [drag], 1
.out:
    ret

; ---- draws desktop, window, taskbar, menu ----
draw_scene:
    movzx eax, byte [desk]      ; desktop
    mov eax, [desk_tbl + eax*4]
    xor ebx, ebx
    mov ecx, SCREEN_W
    xor edx, edx
    mov esi, TASKBAR_Y
    call fill_rect

    cmp byte [win_open], 0
    je .nowin
    call draw_window
.nowin:
    mov eax, 0xC0C0C0           ; taskbar
    xor ebx, ebx
    mov ecx, SCREEN_W
    mov edx, TASKBAR_Y
    mov esi, 32
    call fill_rect

    mov eax, 0xFFFFFF           ; light line on top of the taskbar
    xor ebx, ebx
    mov ecx, SCREEN_W
    mov edx, TASKBAR_Y
    mov esi, 2
    call fill_rect

    mov eax, 0x404040           ; start button (blue while the menu is open)
    cmp byte [menu], 0
    je .sb
    mov eax, 0x0A246A
.sb:
    mov ebx, 4
    mov ecx, 88
    mov edx, TASKBAR_Y + 4
    mov esi, 24
    call fill_rect

    mov dword [tscale], 2
    mov dword [tcol], 0xFFFFFF
    mov esi, s_start
    mov ebx, 28
    mov edx, TASKBAR_Y + 7
    call draw_text

    mov dword [tcol], 0x000000
    mov esi, s_ver
    mov ebx, SCREEN_W - 150
    mov edx, TASKBAR_Y + 7
    call draw_text

    cmp byte [menu], 0
    je .nomenu
    call draw_menu
.nomenu:
    ret

; ---- the window ----
draw_window:
    mov eax, 0x111111           ; drop shadow
    mov ebx, [wx]
    add ebx, 6
    mov ecx, WIN_W
    mov edx, [wy]
    add edx, 6
    mov esi, WIN_H
    call fill_rect

    mov eax, 0xC0C0C0           ; window body
    mov ebx, [wx]
    mov ecx, WIN_W
    mov edx, [wy]
    mov esi, WIN_H
    call fill_rect

    mov eax, 0x0A246A           ; title bar
    mov ebx, [wx]
    mov ecx, WIN_W
    mov edx, [wy]
    mov esi, 28
    call fill_rect

    mov eax, 0xC02020           ; close button
    mov ebx, [wx]
    add ebx, WIN_W - 26
    mov ecx, 22
    mov edx, [wy]
    add edx, 4
    mov esi, 20
    call fill_rect

    mov eax, 0xFFFFFF           ; content area
    mov ebx, [wx]
    add ebx, 8
    mov ecx, WIN_W - 16
    mov edx, [wy]
    add edx, 36
    mov esi, WIN_H - 44
    call fill_rect

    mov dword [tscale], 2
    mov dword [tcol], 0xFFFFFF  ; title + X
    mov esi, s_title
    mov ebx, [wx]
    add ebx, 8
    mov edx, [wy]
    add edx, 5
    call draw_text

    mov esi, s_x
    mov ebx, [wx]
    add ebx, WIN_W - 20
    mov edx, [wy]
    add edx, 5
    call draw_text

    mov dword [tscale], 1       ; body text: typed content (or a grey hint if empty)
    mov eax, [wx]
    add eax, 16
    mov edx, [wy]
    add edx, 44
    mov [caret_x], eax          ; default caret: start of the content area
    mov [caret_y], edx
    mov ebx, eax
    add eax, WIN_W - 28
    mov [pa_right], eax
    mov eax, [wy]
    add eax, WIN_H - 8
    mov [pa_bottom], eax

    cmp dword [text_len], 0
    jnz .hastext
    mov dword [tcol], 0x808080
    mov esi, s_hint
    call draw_para               ; draws the hint, but we keep the start-of-box caret
    jmp .caret
.hastext:
    mov dword [tcol], 0x000000
    mov esi, text_buf
    call draw_para                ; sets [caret_x]/[caret_y] to the end of the typed text
.caret:
    mov eax, 0x000000
    mov ebx, [caret_x]
    mov ecx, 2
    mov edx, [caret_y]
    mov esi, 9
    call fill_rect
    ret

; ---- the start menu (3 items, the hovered one lights up blue) ----
draw_menu:
    mov eax, 0x000000           ; border
    mov ebx, MENU_X - 2
    mov ecx, MENU_W + 4
    mov edx, MENU_ITEM0 - 4
    mov esi, 90
    call fill_rect

    mov eax, 0xC0C0C0           ; panel
    mov ebx, MENU_X
    mov ecx, MENU_W
    mov edx, MENU_ITEM0 - 2
    mov esi, 88
    call fill_rect

    mov dword [tscale], 2
    mov dword [mi], 0
.item:
    mov eax, [mi]
    imul eax, ITEM_H
    add eax, MENU_ITEM0         ; top of this item
    mov [iy], eax
    mov ebx, MENU_X
    mov edx, eax
    mov ecx, MENU_W
    mov esi, ITEM_H
    call hit                    ; is the mouse over it?
    mov dword [tcol], 0x000000
    jnc .nohover
    mov eax, 0x0A246A
    mov ebx, MENU_X
    mov ecx, MENU_W
    mov edx, [iy]
    mov esi, ITEM_H
    call fill_rect
    mov dword [tcol], 0xFFFFFF
.nohover:
    mov eax, [mi]
    mov esi, [menu_tbl + eax*4] ; pointer to this item's label
    mov ebx, MENU_X + 8
    mov edx, [iy]
    add edx, 5
    call draw_text
    inc dword [mi]
    cmp dword [mi], 3
    jb .item
    ret
