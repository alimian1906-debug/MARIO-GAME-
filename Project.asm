bits 16
org 100h

; ==========================================
; CONSTANTS
; ==========================================

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200

MAP_COLUMNS equ 60
MAP_ROWS equ 12
MAP_SIZE equ MAP_COLUMNS * MAP_ROWS

TILE_SIZE equ 16

COLOR_SKY equ 1
COLOR_GROUND equ 6
COLOR_BRICK equ 4
COLOR_PIPE equ 2
COLOR_HERO equ 12
COLOR_ENEMY equ 14
COLOR_TEXT equ 15
COLOR_HUD equ 11
COLOR_MUSHROOM equ 10
COLOR_COIN_BLOCK equ 14

; Keyboard scan codes
KEY_LEFT equ 4Bh
KEY_RIGHT equ 4Dh
KEY_SPACE equ 39h
KEY_ENTER equ 1Ch
KEY_ESCAPE equ 01h
KEY_SHIFT equ 2Ah

; Game limits
START_LIVES equ 3
START_TIME equ 300
MAX_LIVES equ 99
MAX_SCORE equ 999999

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

; Physics values: 8.8 fixed point

WALK_ACCEL equ 0040h
FRICTION equ 0100h

WALK_MAX_SPEED equ 0200h
RUN_MAX_SPEED equ 0300h

; Increased jump height
GRAVITY equ 0080h
JUMP_SPEED equ 0F800h
JUMP_CUTOFF equ 0FB00h
MAX_FALL_SPEED equ 0600h

HERO_MAX_X_FP equ 241664

; Game states
STATE_PLAYING equ 0
STATE_DYING equ 1
STATE_LIFE_LOST equ 2
STATE_GAME_OVER equ 3


; ==========================================
; PROGRAM START
; ==========================================

start:

    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, program_end + 2048

    ; Reduce program memory
    mov bx, program_end
    add bx, 2063
    shr bx, 4

    mov ah, 4Ah
    int 21h
    jc memory_error_exit

    ; Allocate 64000-byte framebuffer
    mov bx, 4000
    mov ah, 48h
    int 21h
    jc memory_error_exit

    mov [framebuffer_segment], ax

    ; Enter VGA mode 13h
    mov ax, 0013h
    int 10h

    call InstallKeyboard
    call InstallTimer

    call ResetMap
    call ResetPlayer

    call ClearBuffer
    call RenderFrame

    mov ax, [timer_ticks]
    mov [last_timer_ticks], ax


; ==========================================
; MAIN GAME LOOP
; ==========================================

.game_loop:

    call ReadKeyboard

    cmp byte [exit_requested], 1
    je .exit_game

.wait_tick:

    mov ax, [timer_ticks]
    cmp ax, [last_timer_ticks]
    je .wait_tick

    mov [last_timer_ticks], ax

    call ReadKeyboard

    cmp byte [exit_requested], 1
    je .exit_game

    cmp byte [game_state], STATE_PLAYING
    jne .other_state

    ; Count timer ticks
    inc word [second_ticks]

    cmp word [second_ticks], 18
    jb .timer_ready

    ; One second has passed
    mov word [second_ticks], 0

    ; Decrease remaining time
    cmp word [game_time], 0
    je .time_up

    dec word [game_time]

    cmp word [game_time], 0
    jne .timer_ready

.time_up:

    ; Time has finished
    call StartDeath
    jmp .render

.timer_ready:

    call UpdateInvulnerability
    call UpdatePhysics

    cmp byte [game_state], STATE_PLAYING
    jne .render

    call UpdateEnemies
    call UpdateMushroom
    jmp .render

.other_state:

    call UpdateGameState

.render:

    call RenderFrame

    jmp .game_loop


; ==========================================
; EXIT GAME
; ==========================================

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


; ==========================================
; VARIABLES
; ==========================================

hero_x dw 32
hero_y dw 144

hero_x_fp dd 8192
hero_y_fp dw 36864

hero_vx dw 0
hero_vy dw 0

hero_previous_y dw 144
hero_previous_vy dw 0

hero_on_ground db 1
hero_facing db 1

jump_was_down db 0
air_jumps db 0

camera_x dw 0

hero_hp db 1
invulnerability_ticks dw 0

score dd 0
coins dw 0
lives db START_LIVES

; HUD text
hud_score db ' SCORE: ',0
hud_coins db '  COINS: ',0
hud_lives db '  LIVES: ',0
hud_time db '  TIME: ',0
hud_power db '  POWER: ',0

hud_small db 'SMALL',0
hud_super db 'SUPER',0

; Enemy system
ENEMY_COUNT equ 6

enemy_x dw 96, 240, 400, 520, 680, 880
enemy_dir db 1, 0FFh, 1, 0FFh, 1, 1
enemy_type db 0, 0, 0, 0, 1, 1
enemy_state db 0, 0, 0, 0, 0, 0

enemy_sprite_ptr dw 0
enemy_draw_x dw 0
enemy_draw_y dw 144
enemy_draw_row dw 0
enemy_draw_col dw 0
enemy_pixel_color db 0

game_time dw START_TIME
second_ticks dw 0

; Mushroom power-up
mushroom_active db 0
mushroom_x dw 0
mushroom_y dw 0
mushroom_dir db 1
mushroom_vy dw 0

game_state db STATE_PLAYING
state_ticks dw 0

key_states times 128 db 0

keyboard_installed db 0
timer_installed db 0

old_int9_offset dw 0
old_int9_segment dw 0

old_int8_offset dw 0
old_int8_segment dw 0

timer_ticks dw 0
last_timer_ticks dw 0

input_left db 0
input_right db 0
input_jump db 0

exit_requested db 0

framebuffer_segment dw 0

collision_flag db 0

map_start_col dw 0
map_offset_x dw 0

draw_row dw 0
draw_col dw 0
draw_world_col dw 0
draw_tile_value dw 0

mario_pixel_color dw 0

memory_error db 'Not enough memory for framebuffer.$'

life_lost_msg db 'LIFE LOST - RESTARTING',0
game_over_msg db 'GAME OVER - PRESS ENTER',0


; ==========================================
; MARIO SPRITE
; ==========================================

mario_sprite:

    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 6,6,14,14,14,14,6,6
    db 6,14,14,14,14,14,14,6
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 0,1,1,0,0,1,1,0
    db 6,6,6,0,0,6,6,6


; ==========================================
; GOOMBA SPRITE
; ==========================================

goomba_sprite:

    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 4,4,6,6,6,6,4,4
    db 0,4,6,6,6,6,4,0
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 4,4,0,0,0,0,4,4
    db 4,4,0,0,0,0,4,4


; ==========================================
; KOOPA SPRITE
; ==========================================

koopa_sprite:

    db 0,0,14,14,14,14,0,0
    db 0,14,14,14,14,14,14,0
    db 14,14,2,2,2,2,14,14
    db 14,14,2,10,10,2,14,14
    db 0,2,2,2,2,2,2,0
    db 0,2,2,2,2,2,2,0
    db 0,0,14,0,0,14,0,0
    db 0,0,14,0,0,14,0,0


; ==========================================
; KOOPA SHELL SPRITE
; ==========================================

koopa_shell_sprite:

    db 0,0,0,0,0,0,0,0
    db 0,2,2,2,2,2,2,0
    db 2,2,10,2,2,10,2,2
    db 2,2,2,2,2,2,2,2
    db 2,2,2,2,2,2,2,2
    db 0,2,2,2,2,2,2,0
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0

; ==========================================
; LEVEL MAP
; ==========================================

level_map_working:
    times MAP_SIZE db TILE_SKY


; ==========================================
; RESET MAP
; ==========================================

ResetMap:

    push ax
    push bx
    push cx
    push di
    push es
    pushf

    push ds
    pop es

    mov di, level_map_working
    mov al, TILE_SKY
    mov cx, MAP_SIZE

    cld
    rep stosb

    xor bx, bx

.ground_loop:

    cmp bx, MAP_COLUMNS
    jae .blocks

    ; First pit: columns 18 to 20
    cmp bx, 18
    jb .check_second_pit

    cmp bx, 20
    jbe .next_ground

.check_second_pit:

    ; Second pit: columns 37 to 39
    cmp bx, 37
    jb .place_ground

    cmp bx, 39
    jbe .next_ground

.place_ground:

    mov byte [level_map_working + 600 + bx], TILE_GROUND
    mov byte [level_map_working + 660 + bx], TILE_GROUND

.next_ground:

    inc bx
    jmp .ground_loop


.blocks:

       ; Three coin question blocks
    mov byte [level_map_working + 433], TILE_QUESTION_COIN
    mov byte [level_map_working + 438], TILE_QUESTION_COIN
    mov byte [level_map_working + 443], TILE_QUESTION_COIN

    ; Two mushroom question blocks
    mov byte [level_map_working + 428], TILE_QUESTION_MUSHROOM
    mov byte [level_map_working + 447], TILE_QUESTION_MUSHROOM

    ; First brick group
    mov byte [level_map_working + 429], TILE_BRICK
    mov byte [level_map_working + 430], TILE_BRICK
    mov byte [level_map_working + 431], TILE_BRICK

    ; Second brick group
    mov byte [level_map_working + 448], TILE_BRICK
    mov byte [level_map_working + 449], TILE_BRICK
    mov byte [level_map_working + 450], TILE_BRICK

    ; First brick group
    mov byte [level_map_working + 429], TILE_BRICK
    mov byte [level_map_working + 430], TILE_BRICK
    mov byte [level_map_working + 431], TILE_BRICK

    ; Second brick group
    mov byte [level_map_working + 448], TILE_BRICK
    mov byte [level_map_working + 449], TILE_BRICK
    mov byte [level_map_working + 450], TILE_BRICK

    ; Free coins
    mov byte [level_map_working + 364], TILE_COIN
    mov byte [level_map_working + 365], TILE_COIN
    mov byte [level_map_working + 366], TILE_COIN
    mov byte [level_map_working + 376], TILE_COIN
    mov byte [level_map_working + 377], TILE_COIN
    mov byte [level_map_working + 390], TILE_COIN
    mov byte [level_map_working + 391], TILE_COIN
    mov byte [level_map_working + 404], TILE_COIN
    mov byte [level_map_working + 405], TILE_COIN
    mov byte [level_map_working + 406], TILE_COIN

    ; First pipe: two tiles high
    mov byte [level_map_working + 502], TILE_PIPE_TOP_LEFT
    mov byte [level_map_working + 503], TILE_PIPE_TOP_RIGHT

    mov byte [level_map_working + 562], TILE_PIPE_BODY_LEFT
    mov byte [level_map_working + 563], TILE_PIPE_BODY_RIGHT

    ; Second pipe: three tiles high
    mov byte [level_map_working + 463], TILE_PIPE_TOP_LEFT
    mov byte [level_map_working + 464], TILE_PIPE_TOP_RIGHT

    mov byte [level_map_working + 523], TILE_PIPE_BODY_LEFT
    mov byte [level_map_working + 524], TILE_PIPE_BODY_RIGHT

    mov byte [level_map_working + 583], TILE_PIPE_BODY_LEFT
    mov byte [level_map_working + 584], TILE_PIPE_BODY_RIGHT

    ; Flagpole
    mov byte [level_map_working + 239], TILE_FLAG
    mov byte [level_map_working + 299], TILE_FLAG
    mov byte [level_map_working + 359], TILE_FLAG
    mov byte [level_map_working + 419], TILE_FLAG
    mov byte [level_map_working + 479], TILE_FLAG
    mov byte [level_map_working + 539], TILE_FLAG
    mov byte [level_map_working + 599], TILE_FLAG

    popf
    pop es
    pop di
    pop cx
    pop bx
    pop ax

    ret


; ==========================================
; RESET PLAYER
; ==========================================

ResetPlayer:

    call ResetMap
    call ResetEnemies

    mov dword [hero_x_fp], 8192
    mov word [hero_y_fp], 36864

    mov word [hero_x], 32
    mov word [hero_y], 144

    mov word [hero_vx], 0
    mov word [hero_vy], 0

    mov word [hero_previous_y], 144
    mov word [hero_previous_vy], 0


    mov byte [hero_on_ground], 1
    mov byte [hero_facing], 1
    mov byte [jump_was_down], 0
    mov byte [air_jumps], 0

    mov word [camera_x], 0

    mov byte [hero_hp], 1
    mov word [invulnerability_ticks], 0

    ; Reset mushroom power-up
    mov byte [mushroom_active], 0
    mov word [mushroom_x], 0
    mov word [mushroom_y], 0
    mov byte [mushroom_dir], 1
    mov word [mushroom_vy], 0

    ret



; ==========================================
; RESET ENEMIES
; ==========================================

ResetEnemies:

    mov word [enemy_x], 96
    mov word [enemy_x+2], 240
    mov word [enemy_x+4], 400
    mov word [enemy_x+6], 520
    mov word [enemy_x+8], 760
    mov word [enemy_x+10], 880

    mov byte [enemy_dir], 1
    mov byte [enemy_dir+1], 0FFh
    mov byte [enemy_dir+2], 1
    mov byte [enemy_dir+3], 0FFh
    mov byte [enemy_dir+4], 1
    mov byte [enemy_dir+5], 0FFh

    mov byte [enemy_state], 0
    mov byte [enemy_state+1], 0
    mov byte [enemy_state+2], 0
    mov byte [enemy_state+3], 0
    mov byte [enemy_state+4], 0
    mov byte [enemy_state+5], 0

    ret




; ==========================================
; UPDATE INVULNERABILITY
; ==========================================

UpdateInvulnerability:

    cmp word [invulnerability_ticks], 0
    je .done

    dec word [invulnerability_ticks]

.done:
    ret


; ==========================================
; HANDLE MARIO DAMAGE
; ==========================================

HandleHeroHit:

    ; Already protected?
    cmp word [invulnerability_ticks], 0
    jne .done

    ; Super Mario becomes Small Mario
    cmp byte [hero_hp], 2
    jne .kill_mario

    mov byte [hero_hp], 1

    ; Give 2 seconds of protection
    mov word [invulnerability_ticks], 36

    ; Small bounce after taking damage
    mov word [hero_vy], JUMP_SPEED
    mov byte [hero_on_ground], 0

    jmp .done

.kill_mario:

    call StartDeath

.done:
    ret




; ==========================================
; UPDATE ENEMIES
; ==========================================

UpdateEnemies:

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    xor si, si

.enemy_loop:

    cmp si, ENEMY_COUNT
    jae .done

    mov bx, si
    shl bx, 1

    ; Skip defeated enemies
    cmp byte [enemy_state+si], 3
    je .next_enemy

    ; Move sliding shell
    cmp byte [enemy_state+si], 2
    je .slide_shell

    ; Stationary shell does not move
    cmp byte [enemy_state+si], 1
    je .check_collision

    ; Walking enemy moves right or left
    cmp byte [enemy_dir+si], 0
    jl .walk_left

.walk_right:
    ; Check for a wall or pipe ahead
    mov ax, [enemy_x+bx]
    add ax, 16

    mov dx, 152

    push dx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    je .turn_left

        ; Check whether another enemy is ahead
    xor di, di

.check_enemy_right:

    cmp di, ENEMY_COUNT
    jae .right_enemy_clear

    cmp di, si
    je .right_next_enemy

    cmp byte [enemy_state+di], 3
    je .right_next_enemy

    mov ax, [enemy_x+bx]
    add ax, 17

    mov bp, di
    shl bp, 1

    cmp ax, [ds:enemy_x+bp]
    jbe .right_next_enemy

    mov ax, [ds:enemy_x+bp]
    add ax, 16

    mov dx, [enemy_x+bx]
    inc dx

    cmp ax, dx
    ja .turn_left

.right_next_enemy:

    inc di
    jmp .check_enemy_right

.right_enemy_clear:

    ; Check ground ahead of enemy
    mov ax, [enemy_x+bx]
    add ax, 16

    mov dx, 160

    push dx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    jne .turn_left

    ; Ground exists, move right
    inc word [enemy_x+bx]

    cmp word [enemy_x+bx], 928
    jbe .check_collision

    mov word [enemy_x+bx], 928

    jmp .check_collision


.turn_left:

    ; Turn around at pit
    mov byte [enemy_dir+si], 0FFh

    jmp .check_collision


.walk_left:
    ; Check for a wall or pipe ahead
    mov ax, [enemy_x+bx]
    dec ax

    mov dx, 152

    push dx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    je .turn_right
        ; Check whether another enemy is ahead
    xor di, di

.check_enemy_left:

    cmp di, ENEMY_COUNT
    jae .left_enemy_clear

    cmp di, si
    je .left_next_enemy

    cmp byte [enemy_state+di], 3
    je .left_next_enemy

    mov ax, [enemy_x+bx]
    dec ax
    add ax, 16

    mov bp, di
    shl bp, 1

    cmp ax, [ds:enemy_x+bp]
    jbe .left_next_enemy

    mov ax, [ds:enemy_x+bp]
    add ax, 16

    mov dx, [enemy_x+bx]
    dec dx

    cmp dx, ax
    jae .left_next_enemy

    jmp .turn_right

.left_next_enemy:

    inc di
    jmp .check_enemy_left

.left_enemy_clear:

    ; Check ground ahead of enemy
    mov ax, [enemy_x+bx]
    dec ax

    mov dx, 160

    push dx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    jne .turn_right

    ; Ground exists, move left
    dec word [enemy_x+bx]

    cmp word [enemy_x+bx], 32
    jae .check_collision

    mov word [enemy_x+bx], 32

    jmp .check_collision


.turn_right:

    ; Turn around at pit
    mov byte [enemy_dir+si], 1

    jmp .check_collision


; ------------------------------------------
; KOOPA SHELL MOVEMENT
; ------------------------------------------

.slide_shell:

    cmp byte [enemy_dir+si], 0
    jl .slide_left

.slide_right:

    add word [enemy_x+bx], 3

    cmp word [enemy_x+bx], 928
    jbe .check_collision

    mov word [enemy_x+bx], 928
    jmp .check_collision

.slide_left:

    sub word [enemy_x+bx], 3

    cmp word [enemy_x+bx], 32
    jae .check_collision

    mov word [enemy_x+bx], 32


; ------------------------------------------
; CHECK MARIO COLLISION
; ------------------------------------------

.check_collision:


    ; Ignore enemies while Mario is invulnerable
    cmp word [invulnerability_ticks], 0
    jne .next_enemy
    ; Check horizontal overlap
    mov ax, [hero_x]
    add ax, 16

    cmp ax, [enemy_x+bx]
    jbe .next_enemy

    mov ax, [enemy_x+bx]
    add ax, 16

    cmp ax, [hero_x]
    jbe .next_enemy

    ; Check vertical overlap
    mov ax, [hero_y]
    add ax, 16

    cmp ax, 144
    jbe .next_enemy

    cmp word [hero_y], 160
    jae .next_enemy

    ; Stationary shell is kicked
    cmp byte [enemy_state+si], 1
    je .kick_shell

    ; If Mario is moving upward, do not treat it as a side hit
    mov ax, [hero_y]
    cmp ax, [hero_previous_y]
    jb .next_enemy

    mov ax, [hero_previous_y]
    add ax, 16

    cmp ax, 144
    ja .side_hit

    mov ax, [hero_y]

    cmp ax, [hero_previous_y]
    jb .side_hit

    ; Stop a sliding shell when stomped
    cmp byte [enemy_state+si], 2
    je .stop_shell

    ; Check enemy type
    cmp byte [enemy_type+si], 0
    jne .stomp_koopa

    ; Defeat Goomba
    mov byte [enemy_state+si], 3
    add dword [score], 200

    jmp .bounce_mario

.stomp_koopa:

    ; Koopa becomes a stationary shell
    mov byte [enemy_state+si], 1
    add dword [score], 400

    jmp .bounce_mario

.stop_shell:

    ; Sliding shell becomes stationary
    mov byte [enemy_state+si], 1

.bounce_mario:

    ; Place Mario on top of the enemy
    mov word [hero_y], 128
    call SaveHeroY

    mov word [hero_vy], JUMP_SPEED
    mov byte [hero_on_ground], 0
    mov byte [air_jumps], 0

    jmp .next_enemy

.kick_shell:

    mov ax, [hero_x]

    cmp ax, [enemy_x+bx]
    jae .kick_left

    mov byte [enemy_dir+si], 1
    jmp .start_shell

.kick_left:

    mov byte [enemy_dir+si], 0FFh

.start_shell:

    mov byte [enemy_state+si], 2
    jmp .next_enemy

.side_hit:

    call HandleHeroHit
    jmp .done

.shell_hit:

    call HandleHeroHit
    jmp .done


.next_enemy:

    inc si
    jmp .enemy_loop

.done:

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret


; ==========================================
; CLEAR FRAMEBUFFER
; ==========================================

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


; ==========================================
; PRESENT FRAMEBUFFER
; ==========================================

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


; ==========================================
; DRAW RECTANGLE
; Parameters: x, y, width, height, color
; ==========================================

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

    ; Handle negative X
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


; ==========================================
; GET TILE
; Parameters: x, y
; Returns: AX = tile code
; ==========================================

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


; ==========================================
; CHECK SOLID TILE
; Parameters: x, y
; Returns: AL = 1 if solid, 0 if not
; ==========================================

CheckSolid:

    push bp
    mov bp, sp

    push bx
    push dx

    push word [bp+6]
    push word [bp+4]

    call GetTile
    add sp, 4

    cmp ax, TILE_SKY
    je .not_solid

    cmp ax, TILE_COIN
    je .not_solid

    cmp ax, TILE_FLAG
    je .not_solid

    mov al, 1
    jmp .done

.not_solid:

    mov al, 0

.done:

    pop dx
    pop bx

    pop bp
    ret


; ==========================================
; DRAW TILE
; Parameters: x, y, tile
; ==========================================

DrawTile:

    push bp
    mov bp, sp

    push ax
    push bx

    mov ax, [bp+8]

    cmp ax, TILE_SKY
    je .done

    cmp ax, TILE_GROUND
    je .ground

    cmp ax, TILE_BRICK
    je .brick

    cmp ax, TILE_QUESTION_COIN
    je .question_coin

    cmp ax, TILE_QUESTION_MUSHROOM
    je .question_mushroom
    cmp ax, TILE_EMPTY_BLOCK
    je .empty

    cmp ax, TILE_PIPE_TOP_LEFT
    je .pipe

    cmp ax, TILE_PIPE_TOP_RIGHT
    je .pipe

    cmp ax, TILE_PIPE_BODY_LEFT
    je .pipe

    cmp ax, TILE_PIPE_BODY_RIGHT
    je .pipe

    cmp ax, TILE_STAIR
    je .ground

    cmp ax, TILE_COIN
    je .coin

    cmp ax, TILE_FLAG
    je .flag

    jmp .done

.ground:

    mov ax, COLOR_GROUND
    jmp .normal_tile

.brick:

    mov ax, COLOR_BRICK
    jmp .normal_tile

.question_coin:

    ; Yellow coin question block
    push word COLOR_COIN_BLOCK
    push word 16
    push word 16
    push word [bp+6]
    push word [bp+4]
    call FillRect
    add sp, 10

    ; Coin symbol
    mov ax, [bp+6]
    add ax, 4
    push word 15
    push word 4
    push word 8
    push ax

    mov ax, [bp+4]
    add ax, 6
    push ax

    call FillRect
    add sp, 10

    jmp .done


.question_mushroom:

    ; Green mushroom question block
    push word COLOR_MUSHROOM
    push word 16
    push word 16
    push word [bp+6]
    push word [bp+4]
    call FillRect
    add sp, 10

    ; Red mushroom cap
    mov ax, [bp+6]
    add ax, 4
    push word 4
    push word 8
    push word 4
    push ax

    mov ax, [bp+4]
    add ax, 4
    push ax

    call FillRect
    add sp, 10

    ; White mushroom stem
    mov ax, [bp+6]
    add ax, 8
    push word 15
    push word 4
    push word 4
    push ax

    mov ax, [bp+4]
    add ax, 6
    push ax

    call FillRect
    add sp, 10

    jmp .done

.empty:

    mov ax, COLOR_HUD
    jmp .normal_tile

.pipe:

    mov ax, COLOR_PIPE
    jmp .normal_tile

.flag:

    mov ax, COLOR_TEXT

.normal_tile:

    push ax
    push word 16
    push word 16
    push word [bp+6]
    push word [bp+4]

    call FillRect
    add sp, 10

    jmp .done

.coin:

    ; Larger, brighter coin
    mov ax, 14

    push ax
    push word 12
    push word 8

    mov ax, [bp+6]
    add ax, 2
    push ax

    mov ax, [bp+4]
    add ax, 4
    push ax

    call FillRect
    add sp, 10

.done:

    pop bx
    pop ax

    pop bp
    ret


; ==========================================
; DRAW MAP
; ==========================================

DrawMap:

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Find first visible map column
    mov ax, [camera_x]

    mov dx, ax
    and dx, 000Fh

    mov [map_offset_x], dx

    shr ax, 4
    mov [map_start_col], ax

    mov word [draw_row], 0

.row_loop:

    cmp word [draw_row], MAP_ROWS
    jae .done

    mov word [draw_col], 0

.column_loop:

    cmp word [draw_col], 21
    jae .next_row

    ; Calculate world column
    mov ax, [map_start_col]
    add ax, [draw_col]

    mov [draw_world_col], ax

    cmp ax, MAP_COLUMNS
    jae .sky_tile

    ; Calculate map index
    mov ax, [draw_row]
    mov bx, MAP_COLUMNS
    mul bx

    add ax, [draw_world_col]

    mov bx, ax

    xor ax, ax
    mov al, [level_map_working + bx]

    jmp .draw_tile

.sky_tile:

    mov ax, TILE_SKY

.draw_tile:

    mov [draw_tile_value], ax

    ; Calculate screen Y
    mov ax, [draw_row]
    shl ax, 4

    ; Calculate screen X
    mov bx, [draw_col]
    shl bx, 4

    sub bx, [map_offset_x]

    push word [draw_tile_value]
    push ax
    push bx

    call DrawTile
    add sp, 6

    inc word [draw_col]

    jmp .column_loop

.next_row:

    inc word [draw_row]

    jmp .row_loop

.done:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret


; ==========================================
; DRAW ENEMIES
; ==========================================

DrawEnemies:

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    xor si, si

.enemy_loop:

    cmp si, ENEMY_COUNT
    jae .done

    ; Skip defeated enemies
    cmp byte [enemy_state+si], 3
    je .next_enemy

    ; Calculate enemy screen position
    mov bx, si
    shl bx, 1

    mov ax, [enemy_x+bx]
    sub ax, [camera_x]
    mov [enemy_draw_x], ax

    mov word [enemy_draw_y], 144

    ; Select Goomba or Koopa sprite
    cmp byte [enemy_type+si], 0
    jne .koopa

    mov word [enemy_sprite_ptr], goomba_sprite
    jmp .draw_sprite

.koopa:

    ; Draw shell when Koopa is not walking
    cmp byte [enemy_state+si], 0
    jne .draw_shell

    mov word [enemy_sprite_ptr], koopa_sprite
    jmp .draw_sprite

.draw_shell:

    mov word [enemy_sprite_ptr], koopa_shell_sprite


; ------------------------------------------
; DRAW 8 x 8 SPRITE
; ------------------------------------------

.draw_sprite:

    mov word [enemy_draw_row], 0

.row_loop:

    cmp word [enemy_draw_row], 8
    jae .next_enemy

    mov word [enemy_draw_col], 0

.column_loop:

    cmp word [enemy_draw_col], 8
    jae .next_row

    ; Calculate sprite position
    mov bx, [enemy_draw_row]
    shl bx, 3

    add bx, [enemy_draw_col]
    add bx, [enemy_sprite_ptr]

    mov al, [bx]

    ; Zero means transparent
    cmp al, 0
    je .next_column

    mov [enemy_pixel_color], al

    ; Calculate screen X
    mov ax, [enemy_draw_col]
    shl ax, 1
    add ax, [enemy_draw_x]

    ; Calculate screen Y
    mov dx, [enemy_draw_row]
    shl dx, 1
    add dx, [enemy_draw_y]

    ; Draw one 2 x 2 pixel block
    push word [enemy_pixel_color]
    push word 2
    push word 2
    push dx
    push ax

    call FillRect
    add sp, 10

.next_column:

    inc word [enemy_draw_col]
    jmp .column_loop

.next_row:

    inc word [enemy_draw_row]
    jmp .row_loop


.next_enemy:

    inc si
    jmp .enemy_loop

.done:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret


; ==========================================
; DRAW MUSHROOM
; ==========================================

DrawMushroom:

    push ax
    push bx

    cmp byte [mushroom_active], 1
    jne .done

    ; Calculate screen X
    mov ax, [mushroom_x]
    sub ax, [camera_x]
    mov bx, ax

    ; Mushroom cap
    push word 2
    push word 12
    push word 6

    mov ax, [mushroom_y]
    push ax

    push bx

    call FillRect
    add sp, 10

    ; Mushroom stem
    push word 15
    push word 6
    push word 6

    mov ax, [mushroom_y]
    add ax, 6
    push ax

    mov ax, bx
    add ax, 3
    push ax

    call FillRect
    add sp, 10

    ; White spot on cap
    push word 15
    push word 2
    push word 2

    mov ax, [mushroom_y]
    add ax, 2
    push ax

    mov ax, bx
    add ax, 3
    push ax

    call FillRect
    add sp, 10

.done:

    pop bx
    pop ax

    ret

; ==========================================
; DRAW MARIO
; Parameters: x, y
; ==========================================

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

    ; Change Mario's red color after power-up
    cmp byte [hero_hp], 2
    jne .normal_color

    cmp al, 4
    jne .normal_color

    mov al, 12

.normal_color:

    cmp al, 0
    je .next_cell

    mov [mario_pixel_color], al

    ; X position
    mov ax, bx
    shl ax, 1
    add ax, [bp+4]

    ; Y position
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


; ==========================================
; READ KEYBOARD INPUT
; ==========================================

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
    jne .check_escape

    mov byte [input_jump], 1

.check_escape:

    cmp byte [key_states + KEY_ESCAPE], 1
    jne .done

    mov byte [exit_requested], 1

.done:

    pop ax
    ret


; ==========================================
; UPDATE PHYSICS
; ==========================================

UpdatePhysics:

    push ax
    push bx
    push dx

    mov ax, [hero_y]
    mov [hero_previous_y], ax

    mov ax, [hero_vy]
    mov [hero_previous_vy], ax

    ; Choose maximum speed
    mov bx, WALK_MAX_SPEED

    cmp byte [key_states + KEY_SHIFT], 1
    jne .movement

    mov bx, RUN_MAX_SPEED


; ------------------------------------------
; HORIZONTAL ACCELERATION
; ------------------------------------------

.movement:

    cmp byte [input_left], 1
    jne .check_right

    sub word [hero_vx], WALK_ACCEL

    mov ax, bx
    neg ax

    cmp word [hero_vx], ax
    jge .left_ok

    mov word [hero_vx], ax

.left_ok:

    mov byte [hero_facing], 0

    jmp .move_horizontal

.check_right:

    cmp byte [input_right], 1
    jne .apply_friction

    add word [hero_vx], WALK_ACCEL

    cmp word [hero_vx], bx
    jle .right_ok

    mov word [hero_vx], bx

.right_ok:

    mov byte [hero_facing], 1

    jmp .move_horizontal


; ------------------------------------------
; FRICTION
; ------------------------------------------

.apply_friction:

    cmp word [hero_vx], 0
    je .move_horizontal

    jg .slow_right

.slow_left:

    add word [hero_vx], FRICTION

    cmp word [hero_vx], 0
    jl .move_horizontal

    mov word [hero_vx], 0

    jmp .move_horizontal

.slow_right:

    sub word [hero_vx], FRICTION

    cmp word [hero_vx], 0
    jg .move_horizontal

    mov word [hero_vx], 0


; ------------------------------------------
; MOVE HORIZONTALLY
; ------------------------------------------

.move_horizontal:

    movsx eax, word [hero_vx]

    add dword [hero_x_fp], eax

    ; Prevent movement to the left of the level
    cmp dword [hero_x_fp], 0
    jns .check_right_limit

    mov dword [hero_x_fp], 0

.check_right_limit:

    cmp dword [hero_x_fp], HERO_MAX_X_FP
    jbe .horizontal_position

    mov dword [hero_x_fp], HERO_MAX_X_FP

.horizontal_position:

    mov ax, [hero_x_fp+1]
    mov [hero_x], ax

    ; Check right-side collision
    cmp word [hero_vx], 0
    jle .check_left_collision

    ; Upper point
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    add bx, 1
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_right

    ; Middle point
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    add bx, 8
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_right

    ; Lower point
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    add bx, 15
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_right

    jmp .check_ground_support

.hit_right:

    mov ax, [hero_x]
    add ax, 15
    and ax, 0FFF0h
    sub ax, 16
    mov [hero_x], ax

    mov word [hero_vx], 0
    call SaveHeroX

    jmp .check_ground_support


; ------------------------------------------
; LEFT-SIDE COLLISION
; ------------------------------------------

.check_left_collision:

    cmp word [hero_vx], 0
    jge .check_ground_support

    ; Upper point
    mov ax, [hero_x]
    mov bx, [hero_y]
    add bx, 1
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_left

    ; Middle point
    mov ax, [hero_x]
    mov bx, [hero_y]
    add bx, 8
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_left

    ; Lower point
    mov ax, [hero_x]
    mov bx, [hero_y]
    add bx, 15
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_left

    jmp .check_ground_support

.hit_left:

    mov ax, [hero_x]
    and ax, 0FFF0h
    add ax, 16
    mov [hero_x], ax

    mov word [hero_vx], 0
    call SaveHeroX

    jmp .check_ground_support


; ------------------------------------------
; CHECK WHETHER GROUND EXISTS
; ------------------------------------------

.check_ground_support:

    cmp byte [hero_on_ground], 1
    jne .check_jump

    ; Left foot
    mov ax, [hero_x]
    add ax, 1
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .check_jump

    ; Middle foot
    mov ax, [hero_x]
    add ax, 8
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .check_jump

    ; Right foot
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .check_jump

    ; No ground below Mario
    mov byte [hero_on_ground], 0


; ------------------------------------------
; JUMP INPUT
; ------------------------------------------

.check_jump:

    cmp byte [input_jump], 1
    jne .jump_released

    ; Do not jump repeatedly while Space is held
    cmp byte [jump_was_down], 1
    je .vertical_update

    mov byte [jump_was_down], 1

    ; Normal jump from the ground
    cmp byte [hero_on_ground], 1
    jne .extra_jump

    mov word [hero_vy], JUMP_SPEED

    mov byte [hero_on_ground], 0
    mov byte [air_jumps], 0

    jmp .vertical_update

.extra_jump:

    ; Allow one additional jump in the air
    cmp byte [air_jumps], 1
    jae .vertical_update

    mov word [hero_vy], JUMP_SPEED

    inc byte [air_jumps]

    jmp .vertical_update

.jump_released:

    ; Cut the jump short when Space is released
    cmp byte [jump_was_down], 1
    jne .release_done

    cmp word [hero_vy], JUMP_CUTOFF
    jge .release_done

    mov word [hero_vy], JUMP_CUTOFF

.release_done:

    mov byte [jump_was_down], 0


; ------------------------------------------
; APPLY GRAVITY
; ------------------------------------------

.vertical_update:

    cmp byte [hero_on_ground], 1
    je .finish_physics

    add word [hero_vy], GRAVITY

    ; Limit maximum falling speed
    cmp word [hero_vy], 0
    jl .move_vertical

    cmp word [hero_vy], MAX_FALL_SPEED
    jle .move_vertical

    mov word [hero_vy], MAX_FALL_SPEED


; ------------------------------------------
; MOVE VERTICALLY
; ------------------------------------------

.move_vertical:

    mov ax, [hero_y_fp]
    add ax, [hero_vy]

    mov [hero_y_fp], ax

    mov ax, [hero_y_fp]
    shr ax, 8

    mov [hero_y], ax

    ; Prevent negative Y caused by underflow
    cmp word [hero_y], 200
    jbe .check_vertical_direction

    cmp word [hero_vy], 0
    jge .start_pit_death

    mov word [hero_y], 0
    mov word [hero_y_fp], 0
    mov word [hero_vy], 0

.check_vertical_direction:

    cmp word [hero_vy], 0
    jl .check_head_collision

    jmp .check_foot_collision


; ------------------------------------------
; HEAD COLLISION
; ------------------------------------------

.check_head_collision:

    ; Left point
    mov ax, [hero_x]
    add ax, 1
    mov bx, [hero_y]
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_head

    ; Middle point
    mov ax, [hero_x]
    add ax, 8
    mov bx, [hero_y]
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_head

    ; Right point
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .hit_head

    jmp .check_pit

.hit_head:

    ; Check which block Mario hit
    mov ax, [hero_x]
    add ax, 8

    mov bx, [hero_y]

    push bx
    push ax
    call ActivateBlock
    add sp, 4

    ; Place Mario below the block
    mov ax, [hero_y]
    and ax, 0FFF0h
    add ax, 16

    mov [hero_y], ax
    call SaveHeroY

    mov word [hero_vy], 0

    jmp .check_pit


; ------------------------------------------
; FOOT COLLISION
; ------------------------------------------

.check_foot_collision:

    ; Left point
    mov ax, [hero_x]
    add ax, 1
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .landed

    ; Middle point
    mov ax, [hero_x]
    add ax, 8
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .landed

    ; Right point
    mov ax, [hero_x]
    add ax, 15
    mov bx, [hero_y]
    add bx, 16
    push bx
    push ax
    call CheckSolid
    add sp, 4
    cmp al, 1
    je .landed

    jmp .check_pit

.landed:

    ; Place Mario directly above the tile
    mov ax, [hero_y]
    add ax, 16
    and ax, 0FFF0h
    sub ax, 16

    mov [hero_y], ax
    call SaveHeroY

    mov word [hero_vy], 0
    mov byte [hero_on_ground], 1
    mov byte [air_jumps], 0

    jmp .finish_physics


; ------------------------------------------
; PIT DETECTION
; ------------------------------------------

.check_pit:

    ; Mario's feet have reached the bottom
    mov ax, [hero_y]
    add ax, 16

    cmp ax, 192
    jae .start_pit_death

    jmp .finish_physics

.start_pit_death:

    call StartDeath


.finish_physics:

    ; Collect a coin if Mario touches one
    call CollectCoins

    pop dx
    pop bx
    pop ax

    ret


; ==========================================
; COLLECT COINS
; ==========================================

CollectCoins:

    push ax
    push bx
    push dx
    push si

    ; Do not collect coins while dying
    cmp byte [game_state], STATE_PLAYING
    jne .done

    ; Check Mario's centre position
    mov ax, [hero_x]
    add ax, 8

    mov bx, [hero_y]
    add bx, 8

    push bx
    push ax

    call GetTile
    add sp, 4

    ; Is there a coin at this position?
    cmp ax, TILE_COIN
    jne .done

    ; Calculate coin's map index
    mov ax, [hero_y]
    add ax, 8
    shr ax, 4

    mov bx, MAP_COLUMNS
    mul bx

    mov si, ax

    mov ax, [hero_x]
    add ax, 8
    shr ax, 4

    add si, ax

    ; Remove the collected coin
    mov byte [level_map_working + si], TILE_SKY

    ; Add coin and award points
    call AddCoin

.done:

    pop si
    pop dx
    pop bx
    pop ax

    ret



; ==========================================
; ADD COIN
; ==========================================

AddCoin:

    push ax

    inc word [coins]

    add dword [score], 200

    cmp dword [score], MAX_SCORE
    jbe .check_life

    mov dword [score], MAX_SCORE

.check_life:

    ; 100 coins give an extra life
    cmp word [coins], 100
    jb .done

    mov word [coins], 0

    cmp byte [lives], MAX_LIVES
    jae .done

    inc byte [lives]

.done:

    pop ax
    ret


; ==========================================
; ACTIVATE BLOCK
; Parameters: x, y
; ==========================================

ActivateBlock:

    push bp
    mov bp, sp

    push ax
    push bx
    push si

    ; Get the tile
    push word [bp+6]
    push word [bp+4]
    call GetTile
    add sp, 4

    ; Calculate tile index
    mov bx, ax

    mov ax, [bp+6]
    shr ax, 4

    mov si, MAP_COLUMNS
    mul si

    mov si, ax

    mov ax, [bp+4]
    shr ax, 4

    add si, ax

    ; Coin question block
    cmp bx, TILE_QUESTION_COIN
    je .coin_block

    ; Mushroom question block
    cmp bx, TILE_QUESTION_MUSHROOM
    je .mushroom_block

    ; Brick block
    cmp bx, TILE_BRICK
    je .brick_block

    jmp .done


.coin_block:

    mov byte [level_map_working+si], TILE_EMPTY_BLOCK

    call AddCoin

    jmp .done


.mushroom_block:

    mov byte [level_map_working+si], TILE_EMPTY_BLOCK

    ; Spawn mushroom above the block
    mov ax, [bp+4]
    and ax, 0FFF0h
    add ax, 2
    mov [mushroom_x], ax

    mov ax, [bp+6]
    and ax, 0FFF0h
    sub ax, 12
    mov [mushroom_y], ax

    mov byte [mushroom_dir], 1
    mov word [mushroom_vy], 0

    mov byte [mushroom_active], 1

    jmp .done


.brick_block:

    ; Only Super Mario can break bricks
    cmp byte [hero_hp], 2
    jne .done

    mov byte [level_map_working+si], TILE_SKY

    add dword [score], 50

    cmp dword [score], MAX_SCORE
    jbe .done

    mov dword [score], MAX_SCORE


.done:

    pop si
    pop bx
    pop ax

    pop bp
    ret




; ==========================================
; UPDATE MUSHROOM
; ==========================================

UpdateMushroom:

    push ax
    push bx
    push dx

    cmp byte [mushroom_active], 1
    jne .done

    ; Move mushroom right
    cmp byte [mushroom_dir], 0
    jl .move_left

.move_right:

    mov ax, [mushroom_x]
    add ax, 12

    mov bx, [mushroom_y]
    add bx, 6

    push bx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    je .turn_left

    inc word [mushroom_x]
    jmp .vertical

.turn_left:

    mov byte [mushroom_dir], 0FFh
    jmp .vertical


.move_left:

    mov ax, [mushroom_x]
    dec ax

    mov bx, [mushroom_y]
    add bx, 6

    push bx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    je .turn_right

    dec word [mushroom_x]
    jmp .vertical

.turn_right:

    mov byte [mushroom_dir], 1


.vertical:

    ; Apply gravity
    inc word [mushroom_vy]

    cmp word [mushroom_vy], 3
    jbe .apply_gravity

    mov word [mushroom_vy], 3

.apply_gravity:

    mov ax, [mushroom_vy]
    add [mushroom_y], ax

    ; Check ground under mushroom
    mov ax, [mushroom_x]
    add ax, 2

    mov bx, [mushroom_y]
    add bx, 12

    push bx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    je .landed

    mov ax, [mushroom_x]
    add ax, 10

    mov bx, [mushroom_y]
    add bx, 12

    push bx
    push ax
    call CheckSolid
    add sp, 4

    cmp al, 1
    jne .check_collection

.landed:

    mov ax, [mushroom_y]
    add ax, 12
    and ax, 0FFF0h
    sub ax, 12

    mov [mushroom_y], ax
    mov word [mushroom_vy], 0


.check_collection:

    ; Remove mushroom if it falls off the level
    cmp word [mushroom_y], 192
    jae .remove

    ; Check horizontal overlap with Mario
    mov ax, [mushroom_x]
    add ax, 12

    cmp ax, [hero_x]
    jbe .done

    mov ax, [hero_x]
    add ax, 16

    cmp ax, [mushroom_x]
    jbe .done

    ; Check vertical overlap with Mario
    mov ax, [mushroom_y]
    add ax, 12

    cmp ax, [hero_y]
    jbe .done

    mov ax, [hero_y]
    add ax, 16

    cmp ax, [mushroom_y]
    jbe .done

    ; Mario collects mushroom
    mov byte [mushroom_active], 0

    ; Super Mario has 2 HP
    mov byte [hero_hp], 2

    ; Add 1000 points
    add dword [score], 1000

    cmp dword [score], MAX_SCORE
    jbe .done

    mov dword [score], MAX_SCORE

    jmp .done


.remove:

    mov byte [mushroom_active], 0


.done:

    pop dx
    pop bx
    pop ax

    ret

; ==========================================
; SAVE HORIZONTAL POSITION
; ==========================================

SaveHeroX:

    push ax
    push eax

    movzx eax, word [hero_x]

    shl eax, 8

    mov [hero_x_fp], eax

    pop eax
    pop ax

    ret


; ==========================================
; SAVE VERTICAL POSITION
; ==========================================

SaveHeroY:

    push ax

    mov ax, [hero_y]
    shl ax, 8

    mov [hero_y_fp], ax

    pop ax

    ret


; ==========================================
; START DEATH
; ==========================================

StartDeath:

    cmp byte [game_state], STATE_PLAYING
    jne .done

    mov byte [game_state], STATE_DYING

    mov word [state_ticks], 0

    mov word [hero_vx], 0

    mov word [hero_vy], 0FD00h

    mov byte [hero_on_ground], 0

.done:

    ret


; ==========================================
; UPDATE GAME STATES
; ==========================================

UpdateGameState:

    cmp byte [game_state], STATE_DYING
    je .dying

    cmp byte [game_state], STATE_LIFE_LOST
    je .life_lost

    cmp byte [game_state], STATE_GAME_OVER
    je .game_over

    ret


; ------------------------------------------
; DYING STATE
; ------------------------------------------

.dying:

    inc word [state_ticks]

    ; Move Mario during death animation
    mov ax, [hero_y_fp]
    add ax, [hero_vy]

    mov [hero_y_fp], ax

    add word [hero_vy], GRAVITY

    mov ax, [hero_y_fp]
    shr ax, 8

    mov [hero_y], ax

    cmp word [state_ticks], 27
    jb .done

    ; Decrease lives
    cmp byte [lives], 0
    je .game_over_now

    dec byte [lives]

    cmp byte [lives], 0
    je .game_over_now

    ; Show Life Lost state
    mov byte [game_state], STATE_LIFE_LOST

    mov word [state_ticks], 0

    jmp .done

.game_over_now:

    mov byte [game_state], STATE_GAME_OVER

    mov word [state_ticks], 0

    jmp .done


; ------------------------------------------
; LIFE LOST STATE
; ------------------------------------------

.life_lost:

    inc word [state_ticks]

    cmp word [state_ticks], 36
    jb .done

    call ResetPlayer

    mov word [game_time], START_TIME
    mov word [second_ticks], 0

    mov byte [game_state], STATE_PLAYING

    mov word [state_ticks], 0

    jmp .done


; ------------------------------------------
; GAME OVER STATE
; ------------------------------------------

.game_over:

    cmp byte [key_states + KEY_ENTER], 1
    jne .done

    ; Restart the game
    mov byte [lives], START_LIVES

    mov dword [score], 0
    mov word [coins], 0

    mov word [game_time], START_TIME
    mov word [second_ticks], 0

    call ResetPlayer

    mov byte [game_state], STATE_PLAYING

    mov word [state_ticks], 0

.done:

    ret


; ==========================================
; UPDATE CAMERA
; ==========================================

; ==========================================
; UPDATE CAMERA
; ==========================================

UpdateCamera:

    push ax
    push bx

    ; Camera follows Mario when moving right
    mov ax, [hero_x]
    cmp ax, 160
    jbe .camera_zero

    sub ax, 160
    jmp .check_camera_position

.camera_zero:

    xor ax, ax

.check_camera_position:

    ; Maximum camera position is 640
    cmp ax, 640
    jbe .save_camera

    mov ax, 640

.save_camera:

    mov [camera_x], ax

    pop bx
    pop ax

    ret


; ==========================================
; PRINT GAME MESSAGE
; ==========================================

PrintMessage:

    push ax
    push bx
    push si

    ; Position text
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 10
    int 10h

.print_loop:

    lodsb

    cmp al, 0
    je .done

    mov ah, 0Eh
    mov bh, 0
    mov bl, COLOR_TEXT

    int 10h

    jmp .print_loop

.done:

    pop si
    pop bx
    pop ax

    ret


; ==========================================
; PRINT HUD TEXT
; SI = address of string
; ==========================================

PrintHUDText:

    push ax
    push bx

.print_loop:

    lodsb

    cmp al, 0
    je .done

    mov ah, 0Eh
    mov bh, 0
    mov bl, 15
    int 10h

    jmp .print_loop

.done:

    pop bx
    pop ax
    ret


; ==========================================
; PRINT NUMBER
; Input: DX:AX
; ==========================================

PrintNumber:

    push ax
    push bx
    push cx
    push dx

    mov bx, 10
    xor cx, cx

.divide:

    div bx
    push dx
    inc cx

    xor dx, dx

    cmp ax, 0
    jne .divide

.print_digits:

    pop dx

    mov al, dl
    add al, '0'

    mov ah, 0Eh
    mov bh, 0
    mov bl, 15
    int 10h

    dec cx
    jnz .print_digits

    pop dx
    pop cx
    pop bx
    pop ax

    ret


; ==========================================
; DRAW HUD
; ==========================================

DrawHUD:

    push ax
    push dx
    push si

    ; Position HUD at top of screen
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 10h

    ; SCORE
    mov si, hud_score
    call PrintHUDText

    mov ax, [score]
    mov dx, [score+2]
    call PrintNumber

    ; COINS
    mov si, hud_coins
    call PrintHUDText

    mov ax, [coins]
    xor dx, dx
    call PrintNumber

    ; LIVES
    mov si, hud_lives
    call PrintHUDText

    xor ax, ax
    mov al, [lives]
    xor dx, dx
    call PrintNumber

    ; TIME
    mov si, hud_time
    call PrintHUDText

    mov ax, [game_time]
    xor dx, dx
    call PrintNumber

    ; POWER
    mov si, hud_power
    call PrintHUDText

    cmp byte [hero_hp], 2
    jne .small

    mov si, hud_super
    call PrintHUDText
    jmp .done

.small:

    mov si, hud_small
    call PrintHUDText

.done:

    pop si
    pop dx
    pop ax

    ret


; ==========================================
; RENDER COMPLETE FRAME
; ==========================================

RenderFrame:

    push ax
    push bx

    call ClearBuffer

    call UpdateCamera

    call DrawMap
    call DrawEnemies
    call DrawMushroom

    ; Draw Mario during normal play or death
    cmp byte [game_state], STATE_PLAYING
    je .draw_mario

    cmp byte [game_state], STATE_DYING
    je .draw_mario

    jmp .draw_state_screen

.draw_mario:

    mov ax, [hero_x]
    sub ax, [camera_x]

    push word [hero_y]
    push ax

    call DrawMario
    add sp, 4

    jmp .present

.draw_state_screen:

    ; Draw a panel over the level
    mov ax, COLOR_GROUND

    push ax
    push word 60
    push word 240
    push word 70
    push word 40

    call FillRect
    add sp, 10

.present:

    call FramePresent

    ; Display HUD during gameplay
    cmp byte [game_state], STATE_PLAYING
    jne .check_message

    call DrawHUD

.check_message:

    ; Print state message after presenting frame
    cmp byte [game_state], STATE_LIFE_LOST
    jne .check_game_over

    mov si, life_lost_msg
    call PrintMessage

    jmp .done

.check_game_over:

    cmp byte [game_state], STATE_GAME_OVER
    jne .done

    mov si, game_over_msg
    call PrintMessage

.done:

    pop bx
    pop ax

    ret


; ==========================================
; INSTALL KEYBOARD INTERRUPT
; ==========================================

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


; ==========================================
; RESTORE KEYBOARD INTERRUPT
; ==========================================

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


; ==========================================
; KEYBOARD INTERRUPT HANDLER
; ==========================================

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

    ; Check key release
    mov al, bl

    test al, 80h
    jnz .key_released

    ; Key pressed
    and al, 7Fh

    xor bh, bh
    mov bl, al

    mov byte [key_states + bx], 1

    jmp .send_eoi

.key_released:

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


; ==========================================
; INSTALL TIMER INTERRUPT
; ==========================================

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


; ==========================================
; RESTORE TIMER INTERRUPT
; ==========================================

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


; ==========================================
; TIMER INTERRUPT HANDLER
; ==========================================

TimerISR:

    push ax
    push ds

    mov ax, cs
    mov ds, ax

    inc word [timer_ticks]

    pop ds
    pop ax

    jmp far [cs:old_int8_offset]


program_end: