# BIBI OS 🖥️
A graphical operating system built entirely from scratch in x86 assembly.
No Linux. No base OS. Nothing borrowed.

## Features
- 32-bit protected mode with 800x600 true-color display
- Custom pixel font (BIBI OS font)
- PS/2 mouse with drag-and-drop window management
- Multiple overlapping windows with z-order and focus
- Notepad with keyboard input
- File Explorer
- Start menu with Applications submenu
- Built in pure x86 NASM assembly

## Build
1. Put `nasm.exe` in this folder (grab it from nasm.us)
2. Install QEMU for Windows from qemu.weilnetz.de
3. Double-click `build.bat`

## Structure
| File | What it does |
|---|---|
| `boot.asm` | 512-byte boot sector, loads the kernel |
| `kernel.asm` | Entry point, mode switch, main loop |
| `defs.asm` | Shared constants |
| `input.asm` | PS/2 mouse + keyboard driver |
| `gui.asm` | Desktop, windows, start menu, clicks |
| `gfx.asm` | Drawing engine, text renderer |
| `data.asm` | Strings and variables |
| `font.asm` | Custom pixel font |

## Roadmap
- [x] Boot sector
- [x] Protected mode + VBE graphics
- [x] Mouse cursor and dragging
- [x] Custom font renderer
- [x] Multiple windows
- [x] Keyboard input / Notepad
- [x] File Explorer
- [ ] ATA disk driver + BIBIFS filesystem
- [ ] Interrupts (IDT + PIC)
- [ ] BIBI Lang — our own programming language for BIBI OS apps
