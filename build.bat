@echo off
nasm -f bin Project.asm -o Project.COM
if errorlevel 1 pause