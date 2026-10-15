; ============================================================
;  BIBI OS  -  boot.asm   (stage 1: the 512 byte boot sector)
;  The BIOS loads this to 0x7C00. Its only job: load the
;  kernel off the disk to 0x7E00 and jump to it.
; ============================================================
[org 0x7c00]
[bits 16]

KERNEL_SECTORS equ 32           ; must match the padding at the end of kernel.asm (32 * 512 = 16384)

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    mov [boot_drive], dl        ; BIOS hands us the drive number

    mov si, dap
    mov ah, 0x42                ; BIOS extended read (plain sector numbers, no CHS mess)
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    jmp 0x0000:0x7e00           ; jump into the kernel

disk_error:
    mov si, errmsg
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

boot_drive db 0
errmsg db "BIBI OS: disk error", 0

; disk address packet for the read above
dap:
    db 0x10, 0                  ; packet size, reserved
    dw KERNEL_SECTORS           ; how many sectors to read
    dw 0x7e00, 0x0000           ; where to put them (offset, segment)
    dd 1, 0                     ; start at sector 1 (sector 0 is this file)

times 510 - ($ - $$) db 0
dw 0xAA55
