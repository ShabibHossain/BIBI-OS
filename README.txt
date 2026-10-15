BIBI OS
=======
boot.asm     stage 1 boot sector (512 bytes), loads the kernel
kernel.asm   16-bit part: video mode + switch to 32-bit protected mode
             32-bit part: kernel main loop
defs.asm     shared constants (screen size, layout)
input.asm    PS/2 mouse driver, mouse packet handling
gui.asm      desktop, window, start menu, click handling
gfx.asm      rectangles, cursor, text engine, screen copy
data.asm     strings and variables
font.asm     BIBI OS pixel font (generated from BIBI-OS-glyphs.txt)
build.bat    builds everything and runs it in QEMU

Build: put nasm.exe in this folder (or in PATH) and double-click build.bat
