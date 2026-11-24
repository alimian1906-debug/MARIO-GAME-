
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
    ; Set program segment and stack
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, program_end + 2048

    ; Reduce program memory block
    mov bx, program_end
    add bx, 2063
    shr bx, 4

    mov ah, 4Ah
    int 21h
    jc memory_error_exit

    ; Allocate 4000 paragraphs = 64000 bytes
    mov bx, 4000
    mov ah, 48h
    int 21h
    jc memory_error_exit

    ; Save allocated framebuffer segment
    mov [framebuffer_segment], ax

    ; Set graphics mode
    mov ax, 0013h
    int 10h

    ; Install our keyboard interrupt
    call InstallKeyboard

    ; Clear framebuffer
    call ClearBuffer

    ; Restore working map
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

    ; Update camera
    push word [camera_x]
    push word [hero_x]

    call UpdateCamera
    add sp, 4

    ; Save new camera position
    mov [camera_x], ax

    ; Get starting map column and pixel offset
    mov ax, [camera_x]
    mov dx, ax
    and dx, 000Fh
    shr ax, 4

    ; Pass pixel offset and starting column
    push dx
    push ax

    call DrawMap
    add sp, 4

    ; Present framebuffer on VGA screen
    call FramePresent

    ; Wait until any key is pressed
    mov byte [key_event], 0

    .wait_for_key:
    cmp byte [key_event], 1
    jne .wait_for_key

    ; Restore original keyboard interrupt
    call RestoreKeyboard

    ; Restore text mode
    mov ax, 0003h
    int 10h

    ; Free framebuffer memory
    mov ax, [framebuffer_segment]
    mov es, ax
    mov ah, 49h
    int 21h

    ; Exit to DOS
    mov ax, 4C00h
    int 21h


memory_error_exit:
    ; Return to text mode
    mov ax, 0003h
    int 10h

    ; Display memory allocation error
    mov dx, memory_error
    mov ah, 09h
    int 21h

    ; Exit with error code
    mov ax, 4C01h
    int 21h


; Hero variables
hero_x dw 200
hero_y dw 0
hero_hp db 1

; Camera variables
camera_x dw 0

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
key_event db 0
keyboard_installed db 0

; Original keyboard interrupt address
old_int9_offset dw 0
old_int9_segment dw 0

test_tile db 0

; Framebuffer segment
framebuffer_segment dw 0

; Memory error message
memory_error db 'Not enough memory for framebuffer.$'


; Original level map
; 60 columns x 12 rows = 720 bytes

level_map_original:

    ; Row 0: HUD
    times 60 db TILE_SKY

    ; Row 1: Sky
    times 60 db TILE_SKY

    ; Row 2: Sky
    times 60 db TILE_SKY

    ; Row 3: Flag pole
    times 59 db TILE_SKY
    db TILE_FLAG

    ; Row 4: Ten free coins and flag pole
    times 21 db TILE_SKY
    times 5 db TILE_COIN
    times 15 db TILE_SKY
    times 5 db TILE_COIN
    times 13 db TILE_SKY
    db TILE_FLAG

    ; Row 5: Question blocks and brick
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

    ; Row 6: Brick groups and stairs
    times 8 db TILE_SKY
    times 3 db TILE_BRICK
    times 18 db TILE_SKY
    times 3 db TILE_BRICK
    times 24 db TILE_SKY
    times 2 db TILE_STAIR
    db TILE_SKY
    db TILE_FLAG

    ; Row 7: Pipe and stairs
    times 43 db TILE_SKY
    db TILE_PIPE_TOP_LEFT
    db TILE_PIPE_TOP_RIGHT
    times 9 db TILE_SKY
    times 2 db TILE_STAIR
    times 3 db TILE_SKY
    db TILE_FLAG

    ; Row 8: Pipes and stairs
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

    ; Row 9: Pipe bodies and stairs
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
level_map_working:
    times MAP_SIZE db TILE_SKY


; Procedure: ClearBuffer
; Fill framebuffer with sky colour.

ClearBuffer:
    push ax
    push cx
    push di
    push es
    pushf

    mov ax, [framebuffer_segment]
    mov es, ax

    xor di, di
    mov cx, 64000
    mov al, COLOR_SKY

    cld
    rep stosb

    popf
    pop es
    pop di
    pop cx
    pop ax
    ret


; Procedure: FramePresent
; Copy framebuffer to VGA memory.

FramePresent:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    pushf

    ; Source: framebuffer
    mov ax, [framebuffer_segment]
    mov ds, ax

    ; Destination: VGA memory
    mov ax, 0A000h
    mov es, ax

    xor si, si
    xor di, di
    mov cx, 32000

    cld
    rep movsw

    popf
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret


; Procedure: PutPixel
; Inputs: x [BP+4], y [BP+6], colour [BP+8].

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

    ; Add x
    add ax, [bp+4]
    mov di, ax

    ; Select framebuffer
    mov ax, [framebuffer_segment]
    mov es, ax

    ; Write pixel
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
; Inputs:
; x      [BP+4]
; y      [BP+6]
; width  [BP+8]
; height [BP+10]
; colour [BP+12]

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

    ; Get original width
    mov si, [bp+8]

    ; Clip left edge
    mov ax, [bp+4]
    test ax, 8000h
    jz .check_right

    ; X is negative
    neg ax

    ; Check if rectangle is completely outside
    cmp si, ax
    jbe .done

    ; Reduce width and set X to zero
    sub si, ax
    mov word [bp+4], 0
    jmp .check_height

.check_right:
    ; Check right boundary
    cmp ax, SCREEN_WIDTH
    jae .done

    ; Calculate available width
    mov dx, SCREEN_WIDTH
    sub dx, ax

    cmp si, dx
    jbe .check_height

    ; Clip width
    mov si, dx

.check_height:
    ; Check top boundary
    cmp word [bp+6], SCREEN_HEIGHT
    jae .done

    ; Clip height at bottom
    mov dx, [bp+10]
    mov ax, SCREEN_HEIGHT
    sub ax, [bp+6]

    cmp dx, ax
    jbe .height_ok

    mov dx, ax

.height_ok:
    ; Check zero dimensions
    cmp si, 0
    je .done

    cmp dx, 0
    je .done

    ; Select framebuffer
    mov ax, [framebuffer_segment]
    mov es, ax

    ; Starting Y position
    mov bx, [bp+6]

.row_loop:
    cmp dx, 0
    je .done

    ; Calculate offset = Y * 320 + X
    mov ax, bx
    mov di, ax

    shl ax, 8
    shl di, 6

    add ax, di
    add ax, [bp+4]

    mov di, ax

    ; Draw one row
    mov cx, si
    mov al, [bp+12]

    cld
    rep stosb

    ; Next row
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
; Inputs: px [BP+4], py [BP+6].
; Output: Tile code in AX.

GetTile:
    push bp
    mov bp, sp

    push bx
    push dx
    push si

    ; Check horizontal boundary
    cmp word [bp+4], 960
    jae .outside

    ; Check vertical boundary
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

    ; Calculate index
    add ax, si
    mov si, ax

    ; Read tile code
    mov al, [level_map_working + si]
    xor ah, ah

    jmp .done

.outside:
    mov ax, TILE_SKY

.done:
    pop si
    pop dx
    pop bx
    pop bp
    ret


; Procedure: ResetMap
; Copy original map into working map.

ResetMap:
    push cx
    push si
    push di
    push es
    pushf

    push ds
    pop es

    mov si, level_map_original
    mov di, level_map_working
    mov cx, MAP_SIZE

    cld
    rep movsb

    popf
    pop es
    pop di
    pop si
    pop cx
    ret


; Procedure: DrawTile
; Inputs: x [BP+4], y [BP+6], tile code [BP+8].

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
; Starting column [BP+4].
; Pixel offset [BP+6].
; Draws 21 columns for smooth scrolling.

DrawMap:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Reserve local variables
    sub sp, 6

    ; [BP-14] = row
    ; [BP-16] = screen column

    mov word [bp-14], 0

.row_loop:
    cmp word [bp-14], MAP_ROWS
    jae .done

    mov word [bp-16], 0

.column_loop:
    cmp word [bp-16], 21
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
    ; Calculate screen Y
    mov bx, [bp-14]
    shl bx, 4

    ; Calculate screen X with pixel offset
    mov cx, [bp-16]
    shl cx, 4
    sub cx, [bp+6]

    ; Pass tile code, Y and X
    push ax
    push bx
    push cx

    call DrawTile
    add sp, 6

    inc word [bp-16]
    jmp .column_loop

.next_row:
    inc word [bp-14]
    jmp .row_loop

.done:
    ; Remove local variables
    add sp, 6

    ; Restore registers
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret


; Procedure: UpdateCamera
; World X [BP+4], current camera X [BP+6].
; Output: New camera X in AX.

UpdateCamera:
    push bp
    mov bp, sp

    push bx
    push dx

    ; Get current camera position
    mov dx, [bp+6]

    ; Calculate screen X
    mov ax, [bp+4]
    sub ax, dx

    ; Scroll after Mario passes screen middle
    cmp ax, 160
    jbe .keep_camera

    ; New camera = world X - 160
    mov ax, [bp+4]
    sub ax, 160

    ; Maximum camera position = 640
    cmp ax, 640
    jbe .check_old_camera

    mov ax, 640

.check_old_camera:
    ; Camera must never move backwards
    cmp ax, dx
    jae .done

    mov ax, dx
    jmp .done

.keep_camera:
    mov ax, dx

.done:
    pop dx
    pop bx
    pop bp
    ret



; Procedure: InstallKeyboard
; Save the original INT 09h vector
; and install our keyboard ISR.

InstallKeyboard:
    push ax
    push dx
    push ds
    push es

    ; Get original keyboard interrupt address
    mov ax, 3509h
    int 21h

    ; Save original offset
    mov [old_int9_offset], bx

    ; Save original segment
    mov ax, es
    mov [old_int9_segment], ax

    ; Install our keyboard interrupt
    mov ax, cs
    mov ds, ax

    mov dx, KeyboardISR
    mov ax, 2509h
    int 21h

    ; Mark keyboard interrupt as installed
    mov byte [keyboard_installed], 1

    pop es
    pop ds
    pop dx
    pop ax
    ret


; Procedure: RestoreKeyboard
; Restore the original INT 09h vector.

RestoreKeyboard:
    push ax
    push bx
    push dx
    push ds

    ; Check whether our interrupt is installed
    mov ax, cs
    mov ds, ax

    cmp byte [keyboard_installed], 1
    jne .done

    ; Mark it as restored
    mov byte [keyboard_installed], 0

    ; Get original interrupt address
    mov dx, [old_int9_offset]
    mov bx, [old_int9_segment]

    ; Restore original interrupt
    mov ds, bx
    mov ax, 2509h
    int 21h

.done:
    pop ds
    pop dx
    pop bx
    pop ax
    ret




; Procedure: KeyboardISR
; Custom keyboard interrupt handler.
; Records key presses and releases.

KeyboardISR:
    push ax
    push bx
    push ds

    ; Use our program data segment
    mov ax, cs
    mov ds, ax

    ; Read keyboard scan code
    in al, 60h

    ; Save original scan code
    mov bl, al

    ; Remove release bit
    and al, 7Fh

    ; Use scan code as array index
    xor bh, bh

    ; Check whether key was released
    test bl, 80h
    jnz .key_released

    ; Key pressed
    mov byte [key_states + bx], 1
    mov byte [key_event], 1

    jmp .send_eoi

.key_released:
    ; Key released
    mov byte [key_states + bx], 0

.send_eoi:
    ; Send End Of Interrupt to PIC
    mov al, 20h
    out 20h, al

    pop ds
    pop bx
    pop ax

    iret



; End of program image
program_end:
