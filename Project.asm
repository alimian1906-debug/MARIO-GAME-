
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
COLOR_ENEMY equ 14
COLOR_TEXT equ 15
COLOR_HUD equ 11

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
    mov ax, 0013h
    int 10h

    ; Rectangle 1: Sky
    mov ax, COLOR_SKY
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 20
    push ax
    mov ax, 30
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 2: Ground
    mov ax, COLOR_GROUND
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 20
    push ax
    mov ax, 180
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 3: Brick
    mov ax, COLOR_BRICK
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 45
    push ax
    mov ax, 30
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 4: Pipe
    mov ax, COLOR_PIPE
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 45
    push ax
    mov ax, 180
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 5: Hero
    mov ax, COLOR_HERO
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 70
    push ax
    mov ax, 30
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 6: Enemy
    mov ax, COLOR_ENEMY
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 70
    push ax
    mov ax, 180
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 7: Text
    mov ax, COLOR_TEXT
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 95
    push ax
    mov ax, 30
    push ax
    call FillRect
    add sp, 10

    ; Rectangle 8: HUD
    mov ax, COLOR_HUD
    push ax
    mov ax, 14
    push ax
    mov ax, 100
    push ax
    mov ax, 95
    push ax
    mov ax, 180
    push ax
    call FillRect
    add sp, 10

    ; Wait for a key
    mov ah, 00h
    int 16h

    ; Restore text mode
    mov ax, 0003h
    int 10h

    ; Exit to DOS
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


; Procedure: PutPixel
; Purpose: Draw one pixel on the VGA screen.
; Inputs: x at [BP+4], y at [BP+6], colour at [BP+8].
; Outputs: One pixel is written to video memory.
; Registers changed internally: AX, BX, DI, ES.
; All registers used are restored before returning.

PutPixel:
    push bp
    mov bp, sp

    push ax
    push bx
    push di
    push es

    ; Check screen boundaries
    cmp word [bp+4], SCREEN_WIDTH
    jae .done

    cmp word [bp+6], SCREEN_HEIGHT
    jae .done

    ; Calculate y * 320
    mov ax, [bp+6]
    mov bx, ax

    shl ax, 8
    shl bx, 6

    add ax, bx

    ; Add x to calculate final offset
    add ax, [bp+4]
    mov di, ax

    ; Select VGA video memory
    mov ax, 0A000h
    mov es, ax

    ; Write pixel colour
    mov al, [bp+8]
    mov [es:di], al

.done:
    pop es
    pop di
    pop bx
    pop ax
    pop bp
    ret


; Procedure: FillRect
; Purpose: Draw a filled rectangle using PutPixel.
; Inputs: x, y, width, height, colour through the stack.
; Output: A filled rectangle on the VGA screen.
; Registers changed internally: AX, BX, CX, DX, SI, DI.
; All registers used are restored before returning.

FillRect:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Height controls the outer loop
    mov dx, [bp+10]
    mov si, 0

.outer:
    cmp si, dx
    jae .done

    ; Width controls the inner loop
    mov cx, [bp+8]
    mov di, 0

.inner:
    cmp di, cx
    jae .next_row

    ; Calculate current x position
    mov ax, [bp+4]
    add ax, di

    ; Calculate current y position
    mov bx, [bp+6]
    add bx, si

    ; Pass colour, y and x to PutPixel
    push word [bp+12]
    push bx
    push ax

    call PutPixel
    add sp, 6

    inc di
    jmp .inner

.next_row:
    inc si
    jmp .outer

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret
