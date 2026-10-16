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

; ---- bring_to_front: ebp = window index to raise to the top of win_order ----
; WIN_COUNT is 2, so "to front" is just "make sure it's win_order[0]" - a plain swap.
bring_to_front:
    cmp dword [win_order], ebp
    je .done
    mov eax, [win_order]
    mov [win_order + 4], eax
    mov [win_order], ebp
.done:
    ret

; ---- launch_app: eax = app index (APP_NOTEPAD / APP_EXPLORER) - open it, focus it, raise it ----
launch_app:
    mov byte [win_open + eax], 1
    mov [focus], eax
    mov ebp, eax
    call bring_to_front
    mov byte [dirty], 1
    ret

; ---- explorer_click: the File Explorer's content area was clicked - select the row ----
explorer_click:
    mov eax, [my]
    mov ebx, [win_y + APP_EXPLORER*4]
    add ebx, 40
    sub eax, ebx
    jl .none
    xor edx, edx
    mov ecx, EXP_ROW_H
    div ecx
    cmp eax, FILE_COUNT
    jae .none
    mov [exp_sel], eax
    ret
.none:
    ret

; ---- a fresh left click happened at the cursor position ----
handle_click:
    cmp byte [menu], 0
    jne .menu_open

    mov ebx, 4                  ; not in a menu: clicked the start button?
    mov edx, TASKBAR_Y + 4
    mov ecx, 88
    mov esi, 24
    call hit
    jnc .checkwindows
    mov byte [menu], 1
    mov byte [app_menu], 0
    ret

.checkwindows:                  ; else: check real windows, topmost first
    xor ecx, ecx
.wloop:
    mov eax, [win_order + ecx*4]
    push ecx
    mov ebp, eax                 ; ebp = this window's index (survives calls below)
    cmp byte [win_open + ebp], 0
    je .wnext

    mov ebx, [win_x + ebp*4]     ; its close button?
    add ebx, WIN_W - 26
    mov edx, [win_y + ebp*4]
    add edx, 4
    mov ecx, 22
    mov esi, 20
    call hit
    jnc .notclose
    mov byte [win_open + ebp], 0
    pop ecx
    ret
.notclose:
    mov ebx, [win_x + ebp*4]     ; its title bar - focus + raise + start dragging?
    mov edx, [win_y + ebp*4]
    mov ecx, WIN_W
    mov esi, 28
    call hit
    jnc .nottitle
    mov byte [drag], 1
    mov [drag_win], ebp
    mov [focus], ebp
    call bring_to_front
    pop ecx
    ret
.nottitle:
    mov ebx, [win_x + ebp*4]     ; anywhere else in the window - just focus + raise it
    mov edx, [win_y + ebp*4]
    mov ecx, WIN_W
    mov esi, WIN_H
    call hit
    jnc .wnext
    mov [focus], ebp
    call bring_to_front
    cmp ebp, APP_EXPLORER
    jne .wdone
    call explorer_click
.wdone:
    pop ecx
    ret
.wnext:
    pop ecx
    inc ecx
    cmp ecx, WIN_COUNT
    jb .wloop
    ret                           ; clicked the bare desktop

.menu_open:
    cmp byte [app_menu], 0
    jne .submenu_open

    mov ebx, MENU_X              ; main menu: did we click one of its 3 items?
    mov edx, MENU_ITEM0
    mov ecx, MENU_W
    mov esi, ITEM_H * 3
    call hit
    jc .item
    mov byte [menu], 0           ; clicked elsewhere: just close
    ret
.item:
    mov eax, [my]
    sub eax, MENU_ITEM0
    xor edx, edx
    mov ecx, ITEM_H
    div ecx                      ; eax = which item (0, 1 or 2)
    cmp eax, 0
    je .apps
    cmp eax, 1
    je .color
    call wait_in                 ; item 2 = restart: pull the CPU reset line
    mov al, 0xFE
    out 0x64, al
.hang:
    jmp .hang
.apps:
    mov byte [app_menu], 1       ; keep the menu open, show the Applications flyout
    ret
.color:
    movzx eax, byte [desk]
    inc eax
    cmp eax, 6
    jb .c1
    xor eax, eax
.c1:
    mov [desk], al
    mov byte [menu], 0
    ret

.submenu_open:
    mov ebx, SUBMENU_X           ; the Applications flyout: one of its 2 items?
    mov edx, MENU_ITEM0
    mov ecx, SUBMENU_W
    mov esi, APP_ITEM_H * 2
    call hit
    jc .subitem
    mov byte [menu], 0           ; clicked elsewhere: close both menus
    mov byte [app_menu], 0
    ret
.subitem:
    mov eax, [my]
    sub eax, MENU_ITEM0
    xor edx, edx
    mov ecx, APP_ITEM_H
    div ecx                      ; eax = APP_NOTEPAD or APP_EXPLORER
    mov byte [menu], 0
    mov byte [app_menu], 0
    call launch_app
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

    mov eax, [win_order + 4]    ; draw back-to-front so the topmost window paints last
    cmp byte [win_open + eax], 0
    je .skipback
    mov ebp, eax
    call draw_window
.skipback:
    mov eax, [win_order]
    cmp byte [win_open + eax], 0
    je .nowin
    mov ebp, eax
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

; ---- the window: ebp = which window (APP_NOTEPAD or APP_EXPLORER) ----
; ebp is never clobbered by fill_rect/draw_text/draw_char/draw_para (they all save/restore it).
draw_window:
    mov eax, 0x111111           ; drop shadow
    mov ebx, [win_x + ebp*4]
    add ebx, 6
    mov ecx, WIN_W
    mov edx, [win_y + ebp*4]
    add edx, 6
    mov esi, WIN_H
    call fill_rect

    mov eax, 0xC0C0C0           ; window body
    mov ebx, [win_x + ebp*4]
    mov ecx, WIN_W
    mov edx, [win_y + ebp*4]
    mov esi, WIN_H
    call fill_rect

    mov eax, 0x0A246A           ; title bar
    mov ebx, [win_x + ebp*4]
    mov ecx, WIN_W
    mov edx, [win_y + ebp*4]
    mov esi, 28
    call fill_rect

    mov eax, 0xC02020           ; close button
    mov ebx, [win_x + ebp*4]
    add ebx, WIN_W - 26
    mov ecx, 22
    mov edx, [win_y + ebp*4]
    add edx, 4
    mov esi, 20
    call fill_rect

    mov eax, 0xFFFFFF           ; content area
    mov ebx, [win_x + ebp*4]
    add ebx, 8
    mov ecx, WIN_W - 16
    mov edx, [win_y + ebp*4]
    add edx, 36
    mov esi, WIN_H - 44
    call fill_rect

    mov dword [tscale], 2
    mov dword [tcol], 0xFFFFFF  ; title + X
    mov esi, [win_title_tbl + ebp*4]
    mov ebx, [win_x + ebp*4]
    add ebx, 8
    mov edx, [win_y + ebp*4]
    add edx, 5
    call draw_text

    mov esi, s_x
    mov ebx, [win_x + ebp*4]
    add ebx, WIN_W - 20
    mov edx, [win_y + ebp*4]
    add edx, 5
    call draw_text

    cmp ebp, APP_EXPLORER
    je .explorer

; ---- Notepad: typed content (or a grey hint if empty), plus a caret when focused ----
    mov dword [tscale], 1
    mov eax, [win_x + ebp*4]
    add eax, 16
    mov edx, [win_y + ebp*4]
    add edx, 44
    mov ebx, eax
    cmp dword [focus], APP_NOTEPAD
    jne .nocaretset
    mov [caret_x], eax
    mov [caret_y], edx          ; default caret: start of the content area
.nocaretset:
    add eax, WIN_W - 28
    mov [pa_right], eax
    mov eax, [win_y + ebp*4]
    add eax, WIN_H - 8
    mov [pa_bottom], eax

    cmp dword [text_len], 0
    jnz .hastext
    mov dword [tcol], 0x808080
    mov esi, s_hint
    call draw_para
    jmp .maybecaret
.hastext:
    mov dword [tcol], 0x000000
    mov esi, text_buf
    call draw_para                ; sets [caret_x]/[caret_y] to the end of the typed text
.maybecaret:
    cmp dword [focus], APP_NOTEPAD   ; only the focused window shows a caret
    jne .done
    mov eax, 0x000000
    mov ebx, [caret_x]
    mov ecx, 2
    mov edx, [caret_y]
    mov esi, 9
    call fill_rect
    jmp .done

; ---- File Explorer: a simple file list (not wired to real storage yet) ----
.explorer:
    mov dword [tscale], 1
    mov dword [mi], 0
.erow:
    mov eax, [mi]
    imul eax, EXP_ROW_H
    add eax, [win_y + ebp*4]
    add eax, 40
    mov [iy], eax                ; this row's y

    mov eax, [exp_sel]
    cmp eax, [mi]
    jne .erow_nohi
    mov eax, 0xB8D6F2            ; selected-row highlight
    mov ebx, [win_x + ebp*4]
    add ebx, 8
    mov ecx, WIN_W - 16
    mov edx, [iy]
    mov esi, EXP_ROW_H
    call fill_rect
.erow_nohi:
    mov dword [tcol], 0x000000
    mov eax, [mi]
    mov esi, [file_tbl + eax*4]
    mov ebx, [win_x + ebp*4]
    add ebx, 14
    mov edx, [iy]
    add edx, 4
    call draw_text
    inc dword [mi]
    cmp dword [mi], FILE_COUNT
    jb .erow
.done:
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
    jc .hovered
    cmp dword [mi], 0            ; item 0 ("Applications") also lights up while its
    jne .nohover                ; flyout is open, even if the mouse has moved off it
    cmp byte [app_menu], 0
    je .nohover
.hovered:
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
    cmp byte [app_menu], 0
    je .noapps
    call draw_submenu
.noapps:
    ret

; ---- the Applications flyout: lists the 2 apps, same hover-highlight style ----
draw_submenu:
    mov eax, 0x000000            ; border
    mov ebx, SUBMENU_X - 2
    mov ecx, SUBMENU_W + 4
    mov edx, MENU_ITEM0 - 4
    mov esi, APP_ITEM_H * 2 + 6
    call fill_rect

    mov eax, 0xC0C0C0            ; panel
    mov ebx, SUBMENU_X
    mov ecx, SUBMENU_W
    mov edx, MENU_ITEM0 - 2
    mov esi, APP_ITEM_H * 2 + 2
    call fill_rect

    mov dword [tscale], 2
    mov dword [mi], 0
.item:
    mov eax, [mi]
    imul eax, APP_ITEM_H
    add eax, MENU_ITEM0
    mov [iy], eax
    mov ebx, SUBMENU_X
    mov edx, eax
    mov ecx, SUBMENU_W
    mov esi, APP_ITEM_H
    call hit
    mov dword [tcol], 0x000000
    jnc .nohover
    mov eax, 0x0A246A
    mov ebx, SUBMENU_X
    mov ecx, SUBMENU_W
    mov edx, [iy]
    mov esi, APP_ITEM_H
    call fill_rect
    mov dword [tcol], 0xFFFFFF
.nohover:
    mov eax, [mi]
    mov esi, [apps_tbl + eax*4]
    mov ebx, SUBMENU_X + 8
    mov edx, [iy]
    add edx, 5
    call draw_text
    inc dword [mi]
    cmp dword [mi], 2
    jb .item
    ret
