
bits 16
org 100h

; Screen constants
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
TILE_SIZE equ 16

; Colour constants
COLOR_SKY equ 1
COLOR_GROUND equ 6
COLOR_BRICK equ 4
COLOR_PIPE equ 2
COLOR_HERO equ 12
COLOR_TEXT equ 15

; Keyboard scan codes
KEY_LEFT equ 4Bh
KEY_RIGHT equ 4Dh
KEY_UP equ 48h
KEY_DOWN equ 50h
KEY_SPACE equ 39h
KEY_ENTER equ 1Ch
KEY_ESCAPE equ 01h
KEY_SHIFT equ 2Ah

; Game limits
START_LIVES equ 3
MAX_LIVES equ 99
START_TIME equ 300
MAX_ENEMIES equ 8
MAX_SCORE equ 999999
LEVEL_WIDTH equ 60

start:
    start:
    mov ax, 0013h
    int 10h

    mov ah, 00h
    int 16h

    mov ax, 0003h
    int 10h

    mov ax, 4C00h
    int 21h

; Hero variables
hero_x dw 0
hero_y dw 0
hero_hp db 1

; Enemy variables
enemy_count db 0

; Score variables
score dd 0
coins dw 0
lives db START_LIVES

; Clock variables
game_time dw START_TIME

; Keyboard variables
key_states times 128 db 0
