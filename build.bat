@echo off
.\nasm.exe -f bin Project.asm -o Project.COM
if errorlevel 1 pause
