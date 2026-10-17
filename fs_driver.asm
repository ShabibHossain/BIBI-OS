; ===== fs_driver.asm: BIBIFS 1.0 ATA PIO primitives =====
; Disk layout: LBA 0 boot, 1..48 kernel, 49 superblock,
; 50..57 directory table, 58.. data.

BIBIFS_SUPER_LBA   equ 49
BIBIFS_DIR_LBA     equ 50
BIBIFS_DATA_LBA    equ 58
BIBIFS_MAGIC       equ 0x53494642       ; "BFIS"
BIBIFS_MAX_ENTRIES equ 128

ATA_DATA      equ 0x1F0
ATA_SECCOUNT  equ 0x1F2
ATA_STATUS    equ 0x1F7
ATA_COMMAND   equ 0x1F7

ata_wait:
    mov ecx, 1000000
.wait:
    in al, ATA_STATUS
    test al, 0x80
    jz .ready
    loop .wait
    stc
    ret
.ready:
    test al, 1
    jnz .error
    clc
    ret
.error:
    stc
    ret

; eax=LBA, edi=512-byte destination
ata_read_sector:
    push ebx
    push ecx
    push edx
    push esi
    mov esi, eax
    call ata_wait
    jc .fail
    mov dx, ATA_SECCOUNT
    mov al, 1
    out dx, al
    inc dx
    mov eax, esi
    out dx, al
    inc dx
    shr eax, 8
    out dx, al
    inc dx
    shr eax, 8
    out dx, al
    mov dx, 0x1F6
    mov eax, esi
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    out dx, al
    mov dx, ATA_COMMAND
    mov al, 0x20
    out dx, al
    call ata_wait
    jc .fail
    mov dx, ATA_DATA
    mov ecx, 256
.read:
    in ax, dx
    mov [edi], ax
    add edi, 2
    loop .read
    clc
    jmp .done
.fail:
    stc
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; eax=LBA, esi=512-byte source
ata_write_sector:
    push ebx
    push ecx
    push edx
    push edi
    mov edi, eax
    call ata_wait
    jc .fail
    mov dx, ATA_SECCOUNT
    mov al, 1
    out dx, al
    inc dx
    mov eax, edi
    out dx, al
    inc dx
    shr eax, 8
    out dx, al
    inc dx
    shr eax, 8
    out dx, al
    mov dx, 0x1F6
    mov eax, edi
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    out dx, al
    mov dx, ATA_COMMAND
    mov al, 0x30
    out dx, al
    call ata_wait
    jc .fail
    mov dx, ATA_DATA
    mov ecx, 256
.write:
    mov ax, [esi]
    out dx, ax
    add esi, 2
    loop .write
    mov dx, ATA_COMMAND
    mov al, 0xE7
    out dx, al
    call ata_wait
    jc .fail
    clc
    jmp .done
.fail:
    stc
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; Read and validate the BIBIFS superblock.
fs_init:
    mov eax, BIBIFS_SUPER_LBA
    mov edi, fs_sector_buf
    call ata_read_sector
    jc .fail
    cmp dword [fs_sector_buf], BIBIFS_MAGIC
    jne .not_ready
    mov byte [fs_ready], 1
    clc
    ret
.not_ready:
    mov byte [fs_ready], 0
    clc
    ret
.fail:
    mov byte [fs_ready], 0
    stc
    ret

fs_ready db 0
fs_sector_buf times 512 db 0
