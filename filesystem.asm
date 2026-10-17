; ============================================================
; BIBIFS 1.0 initial disk image
; LBA 49 = superblock, LBA 50..57 = 128 directory entries.
; Each entry is 32 bytes: type, flags, parent, size, first_lba, name[20].
; LBA 58 onward is file data.
; ============================================================
[bits 16]

BIBIFS_MAGIC equ 0x53494642
TOTAL_SECTORS equ 128
DIR_LBA equ 50
DIR_SECTORS equ 8
DATA_LBA equ 58

; The build script appends this file immediately after the 48-sector kernel.
; Therefore its first sector becomes disk LBA 49.

; ---------------- superblock ----------------
dd BIBIFS_MAGIC
dw 1
dw 0
dd TOTAL_SECTORS
dd DIR_LBA
dd DIR_SECTORS
dd DATA_LBA
dd 0                  ; root directory entry index
 times 512 - ($ - $$) db 0

; ---------------- directory table ----------------
; type: 1=directory, 2=file
%macro DIR 3
    db 1, 0
    dw %1
    dd 0
    dd 0
    db %2, 0
    times 20 - ($ - $$) %%dummy db 0
%endmacro

; A simpler explicit entry macro avoids depending on label arithmetic.
%macro D 2
    db 1, 0
    dw %1
    dd 0
    dd 0
    db %2
    times 20 - %strlen(%2) db 0
%endmacro

%macro F 4
    db 2, 0
    dw %1
    dd %3
    dd %4
    db %2
    times 20 - %strlen(%2) db 0
%endmacro

; Entry 0: C:\ root
D 0xFFFF, "C:"
; 1..4: top-level folders
D 0, "System"
D 0, "Users"
D 0, "Programs"
D 0, "Temp"
; 5..11: C:\Users\BIBI standard folders
D 2, "BIBI"
D 5, "Desktop"
D 5, "Documents"
D 5, "Downloads"
D 5, "Pictures"
D 5, "Music"
D 5, "Videos"
; 12: BIBITHON workspace
D 5, "BIBITHON"
; 13..15: system/program folders
D 1, "Kernel"
D 1, "Drivers"
D 1, "Config"
D 3, "Notepad"
D 3, "FileExplorer"
D 3, "BIBITHON"

; Remaining entries are free.
times 4096 - ($ - $$) db 0

; ---------------- data area ----------------
; Give the initial image 70 sectors of zeroed data.
times 70 * 512 db 0
