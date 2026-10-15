@echo off
REM BIBI OS build script: assemble, glue together, run in QEMU
nasm -f bin boot.asm -o boot.bin
if errorlevel 1 goto fail
nasm -f bin kernel.asm -o kernel.bin
if errorlevel 1 goto fail
copy /b boot.bin + kernel.bin bibios.img > nul
"C:\Program Files\qemu\qemu-system-x86_64.exe" -accel whpx -accel tcg -drive format=raw,file=bibios.img
goto end
:fail
echo.
echo BUILD FAILED - read the error above
pause
:end