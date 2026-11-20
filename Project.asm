
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
; Level map constants
MAP_COLUMNS equ 60
MAP_ROWS equ 12
MAP_SIZE equ MAP_COLUMNS * MAP_ROWS

; Tile codes
TILE_SKY equ 0
TILE_GROUND equ 1
TILE_BRICK equ 2
TILE_QUESTION_COIN equ 3
TILE_QUESTION_MUSHROOM equ 4
TILE_EMPTY_BLOCK equ 5
TILE_PIPE_TOP_LEFT equ 6
TILE_PIPE_TOP_RIGHT equ 7
TILE_PIPE_BODY_LEFT equ 8
TILE_PIPE_BODY_RIGHT equ 9
TILE_STAIR equ 10
TILE_COIN equ 11
TILE_FLAG equ 12


start:
    mov ax, 0013h
    int 10h
    
    ; Temporary test tile at row 10, column 0
    ; Restore working map from original map
    call ResetMap

    ; GetTile test: px = 8, py = 168
    mov ax, 168
    push ax              ; py

    mov ax, 8
    push ax              ; px

    call GetTile
    add sp, 4

    ; Save returned tile code
    mov [test_tile], al

    ; Check whether the returned tile is ground
    cmp ax, TILE_GROUND
    jne .wrong_tile

    ; Green rectangle means correct
    mov ax, COLOR_PIPE
    jmp .draw_result

.wrong_tile:
    ; Red rectangle means incorrect
    mov ax, COLOR_BRICK

.draw_result:
    push ax              ; Colour
    mov ax, 12
    push ax              ; Height
    mov ax, 20
    push ax              ; Width
    mov ax, 150
    push ax              ; Y
    mov ax, 150
    push ax              ; X

    call FillRect
    add sp, 10

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
test_tile db 0

; Original level map
; Each row contains exactly 60 tiles.
; Total size = 60 columns * 12 rows = 720 bytes.

level_map_original:

    ; Row 0: Reserved for HUD
    times 60 db TILE_SKY

    ; Row 1: Sky
    times 60 db TILE_SKY

    ; Row 2: Sky
    times 60 db TILE_SKY

    ; Row 3: Top part of flag pole
    times 59 db TILE_SKY
    db TILE_FLAG

    ; Row 4: Ten free coins and flag pole
    times 21 db TILE_SKY
    times 5 db TILE_COIN
    times 15 db TILE_SKY
    times 5 db TILE_COIN
    times 13 db TILE_SKY
    db TILE_FLAG

    ; Row 5: Question blocks and brick near flag
    times 7 db TILE_SKY
    db TILE_QUESTION_COIN
    times 5 db TILE_SKY
    db TILE_QUESTION_COIN
    times 14 db TILE_SKY
    db TILE_QUESTION_COIN
    times 5 db TILE_SKY
    db TILE_QUESTION_MUSHROOM
    times 12 db TILE_SKY
    db TILE_QUESTION_MUSHROOM
    times 10 db TILE_SKY
    db TILE_BRICK
    db TILE_FLAG

    ; Row 6: Two groups of three bricks and stairs
    times 8 db TILE_SKY
    times 3 db TILE_BRICK
    times 18 db TILE_SKY
    times 3 db TILE_BRICK
    times 24 db TILE_SKY
    times 2 db TILE_STAIR
    db TILE_SKY
    db TILE_FLAG

    ; Row 7: Three-tile-high pipe and stairs
    times 43 db TILE_SKY
    db TILE_PIPE_TOP_LEFT
    db TILE_PIPE_TOP_RIGHT
    times 9 db TILE_SKY
    times 2 db TILE_STAIR
    times 3 db TILE_SKY
    db TILE_FLAG

    ; Row 8: Two-tile-high pipe, three-tile-high pipe and stairs
    times 23 db TILE_SKY
    db TILE_PIPE_TOP_LEFT
    db TILE_PIPE_TOP_RIGHT
    times 18 db TILE_SKY
    db TILE_PIPE_BODY_LEFT
    db TILE_PIPE_BODY_RIGHT
    times 7 db TILE_SKY
    times 2 db TILE_STAIR
    times 5 db TILE_SKY
    db TILE_FLAG

    ; Row 9: Pipe bodies, stairs and flag pole
    times 23 db TILE_SKY
    db TILE_PIPE_BODY_LEFT
    db TILE_PIPE_BODY_RIGHT
    times 18 db TILE_SKY
    db TILE_PIPE_BODY_LEFT
    db TILE_PIPE_BODY_RIGHT
    times 6 db TILE_SKY
    db TILE_STAIR
    times 7 db TILE_SKY
    db TILE_FLAG

    ; Row 10: Ground with two pits
    times 17 db TILE_GROUND
    times 3 db TILE_SKY
    times 16 db TILE_GROUND
    times 4 db TILE_SKY
    times 20 db TILE_GROUND

    ; Row 11: Ground with two pits
    times 17 db TILE_GROUND
    times 3 db TILE_SKY
    times 16 db TILE_GROUND
    times 4 db TILE_SKY
    times 20 db TILE_GROUND


; Working level map
; ResetMap will copy the original map here.

level_map_working:
    times MAP_SIZE db TILE_SKY



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




; Procedure: GetTile
; Purpose: Find the tile code at a pixel position.
; Inputs: px at [BP+4], py at [BP+6].
; Output: Tile code returned in AX.
; Registers changed internally: AX, BX, DX, SI.
; All registers except the return register AX are restored.

GetTile:
    push bp
    mov bp, sp

    push bx
    push dx
    push si

    ; Check horizontal level boundary
    cmp word [bp+4], 960
    jae .outside

    ; Check vertical level boundary
    cmp word [bp+6], 192
    jae .outside

    ; Calculate column = px / 16
    mov ax, [bp+4]
    shr ax, 4
    mov si, ax

    ; Calculate row = py / 16
    mov ax, [bp+6]
    shr ax, 4

    ; Calculate row * 60
    mov bx, MAP_COLUMNS
    mul bx

    ; Calculate index = row * 60 + column
    add ax, si
    mov si, ax

    ; Read tile code from working map
    mov al, [level_map_working + si]
    xor ah, ah
    jmp .done

.outside:
    ; Return sky for positions outside the level
    mov ax, TILE_SKY

.done:
    pop si
    pop dx
    pop bx
    pop bp
    ret




; Procedure: ResetMap
; Purpose: Copy the original level map into the working map.
; Inputs: None.
; Output: Working map is restored to its original contents.
; Registers changed internally: CX, SI, DI, ES.
; All registers and flags are restored.

ResetMap:
    push cx
    push si
    push di
    push es
    pushf

    ; Source and destination use the program segment
    push ds
    pop es

    ; Source: Original map
    mov si, level_map_original

    ; Destination: Working map
    mov di, level_map_working

    ; Number of bytes to copy
    mov cx, MAP_SIZE

    ; Copy all 720 bytes
    cld
    rep movsb

    ; Restore flags and registers
    popf
    pop es
    pop di
    pop si
    pop cx
    ret
