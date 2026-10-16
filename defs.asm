; ===== defs.asm: constants shared by every module =====
SCREEN_W    equ 800                 ; video mode we ask the BIOS for
SCREEN_H    equ 600
BB_PITCH    equ SCREEN_W * 4        ; bytes per row in our off-screen buffer (32 bit pixels)
BACKBUF     equ 0x200000            ; off-screen buffer lives at 2MB (needs protected mode!)

TASKBAR_Y   equ SCREEN_H - 32       ; taskbar is 32 pixels tall

WIN_W       equ 360                 ; window size
WIN_H       equ 240

MENU_X      equ 4                   ; start menu geometry
MENU_W      equ 200
ITEM_H      equ 28
MENU_ITEM0  equ TASKBAR_Y - 86      ; y of the first menu item

TEXT_BUF_MAX equ 1024               ; max characters typed into the notepad window

WIN_COUNT   equ 2                   ; one instance each: Notepad, File Explorer
APP_NOTEPAD equ 0
APP_EXPLORER equ 1

SUBMENU_X   equ MENU_X + MENU_W + 4 ; "Applications" flyout, to the right of the main menu
SUBMENU_W   equ 170
APP_ITEM_H  equ ITEM_H

EXP_ROW_H   equ 22                  ; file explorer: row height for each listed file
