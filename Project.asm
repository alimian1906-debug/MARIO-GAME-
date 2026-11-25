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

HERO_SPEED equ 512
GRAVITY equ 64
JUMP_SPEED equ -1024
HERO_MAX_X_FP equ 242688

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, program_end + 2048

    mov bx, program_end
    add bx, 2063
    shr bx, 4

    mov ah, 4Ah
    int 21h
    jc memory_error_exit

    mov bx, 4000
    mov ah, 48h
    int 21h
    jc memory_error_exit

    mov [framebuffer_segment], ax

    mov ax, 0013h
    int 10h

    call InstallKeyboard
    call InstallTimer
    call ClearBuffer
    call ResetMap

    mov ax, 168
    push ax
    mov ax, 8
    push ax
    call GetTile
    add sp, 4

    mov [test_tile], al

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

    mov ax, TILE_GROUND
    push ax
    mov ax, 130
    push ax
    mov ax, 30
    push ax
    call DrawTile
    add sp, 6

    mov ax, TILE_BRICK
    push ax
    mov ax, 130
    push ax
    mov ax, 50
    push ax
    call DrawTile
    add sp, 6

    mov ax, TILE_QUESTION_COIN
    push ax
    mov ax, 130
    push ax
    mov ax, 70
    push ax
    call DrawTile
    add sp, 6

    mov ax, TILE_PIPE_TOP_LEFT
    push ax
    mov ax, 130
    push ax
    mov ax, 90
    push ax
    call DrawTile
    add sp, 6

    mov ax, TILE_COIN
    push ax
    mov ax, 130
    push ax
    mov ax, 110
    push ax
    call DrawTile
    add sp, 6

    push word [camera_x]
    push word [hero_x]
    call UpdateCamera
    add sp, 4
    mov [camera_x], ax

    mov ax, [camera_x]
    mov dx, ax
    and dx, 000Fh
    shr ax, 4

    push dx
    push ax
    call DrawMap
    add sp, 4

    call FramePresent

.game_loop:
    call ReadKeyboard

    cmp byte [exit_requested], 1
    je .exit_game

    mov ax, [timer_ticks]
    cmp ax, [last_timer_ticks]
    je .game_loop

    mov [last_timer_ticks], ax

    call UpdatePhysics
    call RenderFrame

    jmp .game_loop

.exit_game:
    call RestoreTimer
    call RestoreKeyboard

    mov ax, 0003h
    int 10h

    mov ax, [framebuffer_segment]
    mov es, ax
    mov ah, 49h
    int 21h

    mov ax, 4C00h
    int 21h


memory_error_exit:
    mov ax, 0003h
    int 10h

    mov dx, memory_error
    mov ah, 09h
    int 21h

    mov ax, 4C01h
    int 21h


; Hero variables
hero_x dw 200
hero_y dw 144
hero_hp db 1

hero_x_fp dd 51200
hero_y_fp dw 36864

hero_vx dw 0
hero_vy dw 0

hero_on_ground db 1
hero_facing db 1
jump_was_down db 0
mario_pixel_color dw 0

; Mario pixel-art sprite
mario_sprite:
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 6,6,14,14,14,14,6,6
    db 6,14,14,14,14,14,14,6
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 0,1,1,0,0,1,1,0
    db 6,6,6,0,0,6,6,6

camera_x dw 0

enemy_count db 0

score dd 0
coins dw 0
lives db START_LIVES

game_time dw START_TIME

key_states times 128 db 0
key_event db 0
keyboard_installed db 0

old_int9_offset dw 0
old_int9_segment dw 0

timer_ticks dw 0
last_timer_ticks dw 0
timer_installed db 0

old_int8_offset dw 0
old_int8_segment dw 0

input_left db 0
input_right db 0
input_jump db 0
exit_requested db 0

test_tile db 0

framebuffer_segment dw 0

memory_error db 'Not enough memory for framebuffer.$'


; Original level map
level_map_original:

    times 60 db TILE_SKY
    times 60 db TILE_SKY
    times 60 db TILE_SKY

    times 59 db TILE_SKY
    db TILE_FLAG

    times 21 db TILE_SKY
    times 5 db TILE_COIN
    times 15 db TILE_SKY
    times 5 db TILE_COIN
    times 13 db TILE_SKY
    db TILE_FLAG

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

    times 8 db TILE_SKY
    times 3 db TILE_BRICK
    times 18 db TILE_SKY
    times 3 db TILE_BRICK
    times 24 db TILE_SKY
    times 2 db TILE_STAIR
    db TILE_SKY
    db TILE_FLAG

    times 43 db TILE_SKY
    db TILE_PIPE_TOP_LEFT
    db TILE_PIPE_TOP_RIGHT
    times 9 db TILE_SKY
    times 2 db TILE_STAIR
    times 3 db TILE_SKY
    db TILE_FLAG

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

    times 17 db TILE_GROUND
    times 3 db TILE_SKY
    times 16 db TILE_GROUND
    times 4 db TILE_SKY
    times 20 db TILE_GROUND

    times 17 db TILE_GROUND
    times 3 db TILE_SKY
    times 16 db TILE_GROUND
    times 4 db TILE_SKY
    times 20 db TILE_GROUND


level_map_working:
    times MAP_SIZE db TILE_SKY


; Clear framebuffer
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


; Copy framebuffer to VGA memory
FramePresent:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    pushf

    mov ax, [framebuffer_segment]
    mov ds, ax

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


; Draw one pixel
PutPixel:
    push bp
    mov bp, sp

    push ax
    push bx
    push di
    push es

    cmp word [bp+4], SCREEN_WIDTH
    jae .done

    cmp word [bp+6], SCREEN_HEIGHT
    jae .done

    mov ax, [bp+6]
    mov bx, ax

    shl ax, 8
    shl bx, 6

    add ax, bx
    add ax, [bp+4]
    mov di, ax

    mov ax, [framebuffer_segment]
    mov es, ax

    mov al, [bp+8]
    mov [es:di], al

.done:
    pop es
    pop di
    pop bx
    pop ax
    pop bp
    ret


; Draw rectangle
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

    mov si, [bp+8]

    mov ax, [bp+4]
    test ax, 8000h
    jz .check_right

    neg ax
    cmp si, ax
    jbe .done

    sub si, ax
    mov word [bp+4], 0
    jmp .check_height

.check_right:
    cmp ax, SCREEN_WIDTH
    jae .done

    mov dx, SCREEN_WIDTH
    sub dx, ax

    cmp si, dx
    jbe .check_height

    mov si, dx

.check_height:
    cmp word [bp+6], SCREEN_HEIGHT
    jae .done

    mov dx, [bp+10]
    mov ax, SCREEN_HEIGHT
    sub ax, [bp+6]

    cmp dx, ax
    jbe .height_ok

    mov dx, ax

.height_ok:
    cmp si, 0
    je .done

    cmp dx, 0
    je .done

    mov ax, [framebuffer_segment]
    mov es, ax

    mov bx, [bp+6]

.row_loop:
    cmp dx, 0
    je .done

    mov ax, bx
    mov di, ax

    shl ax, 8
    shl di, 6

    add ax, di
    add ax, [bp+4]

    mov di, ax

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


; Get tile at pixel position
GetTile:
    push bp
    mov bp, sp

    push bx
    push dx
    push si

    cmp word [bp+4], 960
    jae .outside

    cmp word [bp+6], 192
    jae .outside

    mov ax, [bp+4]
    shr ax, 4
    mov si, ax

    mov ax, [bp+6]
    shr ax, 4

    mov bx, MAP_COLUMNS
    mul bx

    add ax, si
    mov si, ax

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


; Reset map
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


; Draw tile
DrawTile:
    push bp
    mov bp, sp

    push ax

    cmp word [bp+8], TILE_SKY
    je .sky

    cmp word [bp+8], TILE_GROUND
    je .ground

    cmp word [bp+8], TILE_BRICK
    je .brick

    cmp word [bp+8], TILE_QUESTION_COIN
    je .question

    cmp word [bp+8], TILE_QUESTION_MUSHROOM
    je .question

    cmp word [bp+8], TILE_EMPTY_BLOCK
    je .empty

    cmp word [bp+8], TILE_PIPE_TOP_LEFT
    je .pipe

    cmp word [bp+8], TILE_PIPE_TOP_RIGHT
    je .pipe

    cmp word [bp+8], TILE_PIPE_BODY_LEFT
    je .pipe

    cmp word [bp+8], TILE_PIPE_BODY_RIGHT
    je .pipe

    cmp word [bp+8], TILE_STAIR
    je .ground

    cmp word [bp+8], TILE_COIN
    je .question

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


; Draw map
DrawMap:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    sub sp, 6

    mov word [bp-14], 0

.row_loop:
    cmp word [bp-14], MAP_ROWS
    jae .done

    mov word [bp-16], 0

.column_loop:
    cmp word [bp-16], 21
    jae .next_row

    mov ax, [bp+4]
    add ax, [bp-16]

    cmp ax, MAP_COLUMNS
    jae .sky_tile

    mov bx, ax

    mov ax, [bp-14]
    mov dx, MAP_COLUMNS
    mul dx

    add ax, bx
    mov si, ax

    xor ax, ax
    mov al, [level_map_working + si]

    jmp .draw_tile

.sky_tile:
    mov ax, TILE_SKY

.draw_tile:
    mov bx, [bp-14]
    shl bx, 4

    mov cx, [bp-16]
    shl cx, 4
    sub cx, [bp+6]

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
    add sp, 6

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret


; Update camera
UpdateCamera:
    push bp
    mov bp, sp

    push bx
    push dx

    mov dx, [bp+6]

    mov ax, [bp+4]
    sub ax, dx

    cmp ax, 160
    jbe .keep_camera

    mov ax, [bp+4]
    sub ax, 160

    cmp ax, 640
    jbe .check_old_camera

    mov ax, 640

.check_old_camera:
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


; Install keyboard interrupt
InstallKeyboard:
    push ax
    push dx
    push ds
    push es

    mov ax, 3509h
    int 21h

    mov [old_int9_offset], bx

    mov ax, es
    mov [old_int9_segment], ax

    mov ax, cs
    mov ds, ax

    mov dx, KeyboardISR
    mov ax, 2509h
    int 21h

    mov byte [keyboard_installed], 1

    pop es
    pop ds
    pop dx
    pop ax
    ret


; Restore keyboard interrupt
RestoreKeyboard:
    push ax
    push bx
    push dx
    push ds

    mov ax, cs
    mov ds, ax

    cmp byte [keyboard_installed], 1
    jne .done

    mov byte [keyboard_installed], 0

    mov dx, [old_int9_offset]
    mov bx, [old_int9_segment]

    mov ds, bx
    mov ax, 2509h
    int 21h

.done:
    pop ds
    pop dx
    pop bx
    pop ax
    ret


; Keyboard interrupt handler
KeyboardISR:
    push ax
    push bx
    push ds

    mov ax, cs
    mov ds, ax

    in al, 60h
    mov bl, al

    ; Acknowledge keyboard controller
    in al, 61h
    mov ah, al
    or al, 80h
    out 61h, al
    mov al, ah
    and al, 7Fh
    out 61h, al

    ; Check whether the key was released
    mov al, bl
    test al, 80h
    jnz .key_released

    ; Key pressed
    and al, 7Fh
    xor bh, bh
    mov bl, al
    mov byte [key_states + bx], 1
    mov byte [key_event], 1
    jmp .send_eoi

.key_released:
    ; Correctly remove release bit before indexing
    and al, 7Fh
    xor bh, bh
    mov bl, al
    mov byte [key_states + bx], 0

.send_eoi:
    mov al, 20h
    out 20h, al

    pop ds
    pop bx
    pop ax
    iret


; Read keyboard input
ReadKeyboard:
    push ax

    mov byte [input_left], 0
    mov byte [input_right], 0
    mov byte [input_jump], 0

    cmp byte [key_states + KEY_LEFT], 1
    jne .check_right

    mov byte [input_left], 1

.check_right:
    cmp byte [key_states + KEY_RIGHT], 1
    jne .check_jump

    mov byte [input_right], 1

.check_jump:
    cmp byte [key_states + KEY_SPACE], 1
    je .jump_pressed

    cmp byte [key_states + KEY_UP], 1
    jne .check_escape

.jump_pressed:
    mov byte [input_jump], 1

.check_escape:
    cmp byte [key_states + KEY_ESCAPE], 1
    jne .done

    mov byte [exit_requested], 1

.done:
    pop ax
    ret


; Install timer interrupt
InstallTimer:
    push ax
    push bx
    push dx
    push ds
    push es

    mov ax, 3508h
    int 21h

    mov [old_int8_offset], bx
    mov ax, es
    mov [old_int8_segment], ax

    mov ax, cs
    mov ds, ax
    mov dx, TimerISR
    mov ax, 2508h
    int 21h

    mov byte [timer_installed], 1

    pop es
    pop ds
    pop dx
    pop bx
    pop ax
    ret


; Restore timer interrupt
RestoreTimer:
    push ax
    push dx
    push ds

    mov ax, cs
    mov ds, ax

    cmp byte [timer_installed], 1
    jne .done

    mov byte [timer_installed], 0

    mov dx, [old_int8_offset]
    mov ax, [old_int8_segment]
    mov ds, ax

    mov ax, 2508h
    int 21h

.done:
    pop ds
    pop dx
    pop ax
    ret


; Timer interrupt handler
TimerISR:
    push ax
    push ds

    mov ax, cs
    mov ds, ax

    inc word [timer_ticks]

    pop ds
    pop ax

    jmp far [cs:old_int8_offset]


; Update Mario physics
UpdatePhysics:
    push ax
    push bx

    ; Move left
    cmp byte [input_left], 1
    jne .check_right

    sub dword [hero_x_fp], HERO_SPEED
    jc .clamp_left

    mov byte [hero_facing], 0
    jmp .check_jump

.clamp_left:
    mov dword [hero_x_fp], 0
    mov byte [hero_facing], 0
    jmp .check_jump

.check_right:
    cmp byte [input_right], 1
    jne .check_jump

    add dword [hero_x_fp], HERO_SPEED
    cmp dword [hero_x_fp], HERO_MAX_X_FP
    jbe .right_ok

    mov dword [hero_x_fp], HERO_MAX_X_FP

.right_ok:
    mov byte [hero_facing], 1

.check_jump:
    ; Jump only once per key press
    cmp byte [input_jump], 1
    jne .jump_released

    cmp byte [jump_was_down], 1
    je .vertical_update

    mov byte [jump_was_down], 1

    cmp byte [hero_on_ground], 1
    jne .vertical_update

    mov word [hero_vy], JUMP_SPEED
    mov byte [hero_on_ground], 0
    jmp .vertical_update

.jump_released:
    mov byte [jump_was_down], 0

.vertical_update:
    cmp byte [hero_on_ground], 1
    je .save_positions

    mov ax, [hero_vy]
    add [hero_y_fp], ax

    add word [hero_vy], GRAVITY

    mov ax, [hero_y_fp]
    mov cl, 8
    shr ax, cl
    mov [hero_y], ax

    cmp word [hero_vy], 0
    jl .save_positions

    mov ax, [hero_y]
    add ax, 16
    push ax

    mov ax, [hero_x]
    add ax, 8
    push ax

    call GetTile
    add sp, 4

    cmp ax, TILE_SKY
    je .save_positions

    cmp ax, TILE_COIN
    je .save_positions

    mov ax, [hero_y]
    add ax, 16
    and ax, 0FFF0h
    sub ax, 16
    shl ax, 8
    mov [hero_y_fp], ax

    mov word [hero_vy], 0
    mov byte [hero_on_ground], 1

.save_positions:
    mov ax, [hero_x_fp + 1]
    mov [hero_x], ax

    mov ax, [hero_y_fp]
    mov cl, 8
    shr ax, cl
    mov [hero_y], ax

    pop bx
    pop ax
    ret


; Draw complete frame
RenderFrame:
    push ax
    push dx

    call ClearBuffer

    push word [camera_x]
    push word [hero_x]
    call UpdateCamera
    add sp, 4
    mov [camera_x], ax

    mov ax, [camera_x]
    mov dx, ax
    and dx, 000Fh
    shr ax, 4

    push dx
    push ax
    call DrawMap
    add sp, 4

    mov ax, [hero_x]
    sub ax, [camera_x]

    push word [hero_y]
    push ax
    call DrawMario
    add sp, 4

    call FramePresent

    pop dx
    pop ax
    ret


; Draw Mario sprite
DrawMario:
    push bp
    mov bp, sp

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    xor si, si
    xor di, di

.row_loop:
    xor bx, bx

.column_loop:
    mov al, [mario_sprite + si]
    inc si

    cmp al, 0
    je .next_cell

    mov [mario_pixel_color], al

    mov ax, bx
    shl ax, 1
    add ax, [bp+4]

    mov dx, di
    shl dx, 1
    add dx, [bp+6]

    push word [mario_pixel_color]
    push word 2
    push word 2
    push dx
    push ax
    call FillRect
    add sp, 10

.next_cell:
    inc bx
    cmp bx, 8
    jb .column_loop

    inc di
    cmp di, 8
    jb .row_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret

program_end: