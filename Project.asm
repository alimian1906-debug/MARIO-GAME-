
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

    ; Restore working map from original map
    call ResetMap

    ; GetTile test: px = 8, py = 168
    mov ax, 168
    push ax

    mov ax, 8
    push ax

    call GetTile
    add sp, 4

    ; Save returned tile code
    mov [test_tile], al

    ; Check whether returned tile is ground
    cmp ax, TILE_GROUND
    jne .wrong_tile

    mov ax, COLOR_PIPE
    jmp .draw_result

.wrong_tile:
    mov ax, COLOR_BRICK

.draw_result:
    push ax
    mov ax, 12
    push ax
    mov ax, 20
    push ax
    mov ax, 150
    push ax
    mov ax, 150
    push ax

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

    ; Draw a ground tile
    mov ax, TILE_GROUND
    push ax
    mov ax, 130
    push ax
    mov ax, 30
    push ax
    call DrawTile
    add sp, 6

    ; Draw a brick tile
    mov ax, TILE_BRICK
    push ax
    mov ax, 130
    push ax
    mov ax, 50
    push ax
    call DrawTile
    add sp, 6

    ; Draw a question block
    mov ax, TILE_QUESTION_COIN
    push ax
    mov ax, 130
    push ax
    mov ax, 70
    push ax
    call DrawTile
    add sp, 6

    ; Draw a pipe tile
    mov ax, TILE_PIPE_TOP_LEFT
    push ax
    mov ax, 130
    push ax
    mov ax, 90
    push ax
    call DrawTile
    add sp, 6

    ; Draw a coin tile
    mov ax, TILE_COIN
    push ax
    mov ax, 130
    push ax
    mov ax, 110
    push ax
    call DrawTile
    add sp, 6

    ; Draw the middle 20 columns
    push word 20
    call DrawMap
    add sp, 2

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
; Output: One pixel is written to video memory.
; All registers used are restored.

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
; Purpose: Draw a filled rectangle directly into VGA memory.
; Inputs: x, y, width, height, colour through the stack.
; Output: A filled rectangle on the VGA screen.
; All registers and flags are restored.

FillRect:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    pushf

    ; Check starting position
    cmp word [bp+4], SCREEN_WIDTH
    jae .done

    cmp word [bp+6], SCREEN_HEIGHT
    jae .done

    ; Clip width to screen boundary
    mov si, [bp+8]
    mov ax, SCREEN_WIDTH
    sub ax, [bp+4]
    cmp si, ax
    jbe .width_ok
    mov si, ax

.width_ok:
    ; Clip height to screen boundary
    mov dx, [bp+10]
    mov ax, SCREEN_HEIGHT
    sub ax, [bp+6]
    cmp dx, ax
    jbe .height_ok
    mov dx, ax

.height_ok:
    ; Select VGA memory
    mov ax, 0A000h
    mov es, ax

    mov bx, [bp+6]

.row_loop:
    cmp dx, 0
    je .done

    ; Calculate video memory offset: y * 320 + x
    mov ax, bx
    mov di, ax
    shl ax, 8
    shl di, 6
    add ax, di
    add ax, [bp+4]
    mov di, ax

    ; Draw one complete row
    mov cx, si
    mov al, [bp+12]
    cld
    rep stosb

    inc bx
    dec dx
    jmp .row_loop

.done:
    popf
    pop es
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
; All registers except AX are restored.

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


; Procedure: DrawTile
; Purpose: Draw one 16x16 tile according to its tile code.
; Inputs: x at [BP+4], y at [BP+6], tile code at [BP+8].
; Output: One coloured tile is drawn on the screen.
; All registers are restored.

DrawTile:
    push bp
    mov bp, sp

    push ax

    ; Sky tile
    cmp word [bp+8], TILE_SKY
    je .sky

    ; Ground tile
    cmp word [bp+8], TILE_GROUND
    je .ground

    ; Brick tile
    cmp word [bp+8], TILE_BRICK
    je .brick

    ; Question blocks
    cmp word [bp+8], TILE_QUESTION_COIN
    je .question

    cmp word [bp+8], TILE_QUESTION_MUSHROOM
    je .question

    ; Empty block
    cmp word [bp+8], TILE_EMPTY_BLOCK
    je .empty

    ; Pipe tiles
    cmp word [bp+8], TILE_PIPE_TOP_LEFT
    je .pipe

    cmp word [bp+8], TILE_PIPE_TOP_RIGHT
    je .pipe

    cmp word [bp+8], TILE_PIPE_BODY_LEFT
    je .pipe

    cmp word [bp+8], TILE_PIPE_BODY_RIGHT
    je .pipe

    ; Stair tile
    cmp word [bp+8], TILE_STAIR
    je .ground

    ; Coin tile
    cmp word [bp+8], TILE_COIN
    je .question

    ; Flag tile
    cmp word [bp+8], TILE_FLAG
    je .flag

    ; Unknown tile: draw sky
    jmp .sky

.sky:
    mov ax, COLOR_SKY
    jmp .draw

.ground:
    mov ax, COLOR_GROUND
    jmp .draw

.brick:
    mov ax, COLOR_BRICK
    jmp .draw

.question:
    mov ax, COLOR_ENEMY
    jmp .draw

.empty:
    mov ax, COLOR_HUD
    jmp .draw

.pipe:
    mov ax, COLOR_PIPE
    jmp .draw

.flag:
    mov ax, COLOR_TEXT

.draw:
    ; Pass colour, height, width, y and x
    push ax
    push word 16
    push word 16
    push word [bp+6]
    push word [bp+4]

    call FillRect
    add sp, 10

    pop ax
    pop bp
    ret


; Procedure: DrawMap
; Purpose: Draw 20 columns of the level map.
; Input: Starting column at [BP+4].
; Output: Visible map section is drawn on screen.
; All registers are restored.

DrawMap:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Reserve space for local variables
    sub sp, 6

    ; [BP-14] = row
    ; [BP-16] = screen column

    mov word [bp-14], 0

.row_loop:

    ; Check whether all 12 rows are drawn
    cmp word [bp-14], MAP_ROWS
    jae .done

    mov word [bp-16], 0

.column_loop:

    ; Check whether 20 columns are drawn
    cmp word [bp-16], 20
    jae .next_row

    ; Calculate world column
    mov ax, [bp+4]
    add ax, [bp-16]

    ; Check level boundary
    cmp ax, MAP_COLUMNS
    jae .sky_tile

    mov bx, ax

    ; Calculate row * 60
    mov ax, [bp-14]
    mov dx, MAP_COLUMNS
    mul dx

    ; Calculate map index
    add ax, bx
    mov si, ax

    ; Read tile code
    xor ax, ax
    mov al, [level_map_working + si]
    jmp .draw_tile

.sky_tile:
    mov ax, TILE_SKY

.draw_tile:

    ; Calculate screen Y = row * 16
    mov bx, [bp-14]
    shl bx, 4

    ; Calculate screen X = screen column * 16
    mov cx, [bp-16]
    shl cx, 4

    ; Pass tile code, Y and X
    push ax
    push bx
    push cx

    call DrawTile
    add sp, 6

    ; Move to next column
    inc word [bp-16]
    jmp .column_loop

.next_row:

    ; Move to next row
    inc word [bp-14]
    jmp .row_loop

.done:

    ; Remove only the local variables
    add sp, 6

    ; Restore saved registers
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret
