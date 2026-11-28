bits 16
org 100h

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
MAP_COLUMNS equ 60
MAP_ROWS equ 12
MAP_SIZE equ MAP_COLUMNS*MAP_ROWS
COLOR_SKY equ 1

KEY_LEFT equ 4Bh
KEY_RIGHT equ 4Dh
KEY_SPACE equ 39h
KEY_ENTER equ 1Ch
KEY_ESCAPE equ 01h
KEY_SHIFT equ 2Ah

START_LIVES equ 3
START_TIME equ 300
MAX_LIVES equ 99
MAX_SCORE equ 999999

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
TILE_COIN equ 11
TILE_FLAG equ 12

; physics, 8.8 fixed point
WALK_ACCEL equ 0040h
FRICTION equ 0100h
WALK_MAX_SPEED equ 0200h
RUN_MAX_SPEED equ 0300h
GRAVITY equ 0080h
JUMP_SPEED equ 0F800h
JUMP_CUTOFF equ 0FB00h
MAX_FALL_SPEED equ 0600h
HERO_MAX_X_FP equ 241664

STATE_TITLE equ 0
STATE_PLAYING equ 1
STATE_PAUSED equ 2
STATE_DYING equ 3
STATE_LIFE_LOST equ 4
STATE_GAME_OVER equ 5

KEY_P equ 19h

; ==========================================
; PROGRAM START
; ==========================================
start:
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,program_end+2048
    cld

    mov bx,program_end+2063
    shr bx,4
    mov ah,4Ah
    int 21h
    jc memory_error

    mov bx,4000
    mov ah,48h
    int 21h
    jc memory_error
    mov [framebuffer_segment],ax

    mov ax,13h
    int 10h

    mov al,9
    mov dx,KeyboardISR
    mov di,old_int9
    call HookInt

    mov al,8
    mov dx,TimerISR
    mov di,old_int8
    call HookInt

    call ResetPlayer
    mov byte [game_state],STATE_TITLE


.loop:
.wait:
    mov ax,[timer_ticks]
    cmp ax,[last_ticks]
    je .wait
    mov [last_ticks],ax

    ; ESC quits the game and returns to DOS
    cmp byte [key_states+KEY_ESCAPE],1
    je QuitGame

    cmp byte [game_state],STATE_TITLE
    je .title

    cmp byte [game_state],STATE_PAUSED
    je .paused

    cmp byte [game_state],STATE_PLAYING
    jne .other

.pause_check:
    cmp byte [key_states+KEY_P],1
    jne .pause_release

    cmp byte [pause_was_down],0
    jne .timer

    mov byte [pause_was_down],1
    mov byte [game_state],STATE_PAUSED
    jmp .render

.pause_release:
    mov byte [pause_was_down],0

.timer:
    inc word [second_ticks]
    cmp word [second_ticks],18
    jb .play

    mov word [second_ticks],0
    cmp word [game_time],0
    je .timeup

    dec word [game_time]
    jnz .play

.timeup:
    call StartDeath
    jmp .render

.play:
    cmp word [invulnerability_ticks],0
    je .physics

    dec word [invulnerability_ticks]

.physics:
    call UpdatePhysics

    cmp byte [game_state],STATE_PLAYING
    jne .render

    call UpdateEnemies
    call UpdateMushroom
    jmp .render

.title:
    call UpdateTitleMenu
    jmp .render

.paused:
    cmp byte [key_states+KEY_P],1
    jne .resume_release

    cmp byte [pause_was_down],0
    jne .render

    mov byte [pause_was_down],1
    mov byte [game_state],STATE_PLAYING
    jmp .render

.resume_release:
    mov byte [pause_was_down],0
    jmp .render

.other:
    call UpdateGameState

.render:
    call RenderFrame
    jmp .loop


QuitGame:
    mov al,8
    mov si,old_int8
    call UnhookInt

    mov al,9
    mov si,old_int9
    call UnhookInt

    mov ax,3
    int 10h

    mov es,[framebuffer_segment]
    mov ah,49h
    int 21h

    mov ax,4C00h
    int 21h

memory_error:
    mov ax,3
    int 10h
    mov dx,memory_error_msg
    mov ah,9
    int 21h
    mov ax,4C01h
    int 21h

; ==========================================
; INTERRUPTS
; ==========================================
; AL = vector, DX = new handler, DI = dword to store the old vector
HookInt:
    push ax
    mov ah,35h
    int 21h
    mov [di],bx
    mov [di+2],es
    pop ax
    mov ah,25h
    int 21h
    push ds
    pop es
    ret

; AL = vector, SI = dword holding the old vector
UnhookInt:
    push ds
    lds dx,[si]
    mov ah,25h
    int 21h
    pop ds
    ret

KeyboardISR:
    push ax
    push bx
    push ds
    push cs
    pop ds
    in al,60h
    mov bl,al
    in al,61h                       ; acknowledge keyboard controller
    mov ah,al
    or al,80h
    out 61h,al
    and ah,7Fh
    mov al,ah
    out 61h,al
    mov al,bl
    shr al,7                        ; 1 = released
    xor al,1                        ; 1 = pressed
    and bx,7Fh
    mov [key_states+bx],al
    mov al,20h
    out 20h,al
    pop ds
    pop bx
    pop ax
    iret

TimerISR:
    inc word [cs:timer_ticks]
    jmp far [cs:old_int8]

; ==========================================
; RESET
; ==========================================
ResetMap:
    mov di,level_map
    mov cx,MAP_SIZE
    xor ax,ax
    rep stosb

    xor bx,bx                       ; two ground rows, pits at columns 18-20 and 37-39
.ground:
    lea ax,[bx-18]
    cmp ax,2
    jbe .next
    lea ax,[bx-37]
    cmp ax,2
    jbe .next
    mov byte [level_map+600+bx],TILE_GROUND
    mov byte [level_map+660+bx],TILE_GROUND
.next:
    inc bx
    cmp bx,MAP_COLUMNS
    jb .ground

    mov si,map_data                 ; tile byte, then word indices ending in 0
.tile:
    lodsb
    test al,al
    jz .done
    mov dl,al
.index:
    lodsw
    test ax,ax
    jz .tile
    mov bx,ax
    mov [level_map+bx],dl
    jmp .index
.done:
    ret

ResetEnemies:
    mov si,enemy_init
    mov di,enemy_x
    mov cx,24
    rep movsw
    ret

ResetPlayer:
    call ResetMap
    call ResetEnemies
    xor ax,ax
    mov di,zero_start
    mov cx,zero_end-zero_start
    rep stosb
    mov word [hero_x],32
    mov word [hero_y],144
    mov word [hero_previous_y],144
    mov dword [hero_x_fp],8192
    mov word [hero_y_fp],36864
    mov byte [hero_on_ground],1
    mov byte [hero_hp],1
    ret

; ==========================================
; ENEMIES
; ==========================================
UpdateEnemies:
    xor bx,bx                       ; BX = enemy index * 2
.loop:
    mov ax,[enemy_state+bx]         ; 0 walking, 1 shell, 2 sliding shell, 3 dead
    cmp ax,3
    je .next
    mov cx,[enemy_dir+bx]           ; +1 / -1
    mov si,[enemy_x+bx]
    cmp ax,2
    je .slide
    cmp ax,1
    je .collide

    add si,cx                       ; walking: candidate position
    mov bp,si
    test cx,cx
    jl .probe
    add bp,15                       ; leading edge when walking right
.probe:
    mov ax,bp                       ; wall ahead?
    mov dx,152
    call CheckSolid
    test al,al
    jnz .turn
    xor di,di                       ; another enemy in the way?
.enemy:
    cmp di,bx
    je .enemy_next
    cmp word [enemy_state+di],3
    je .enemy_next
    mov ax,[enemy_x+di]
    lea dx,[si+16]
    cmp ax,dx
    jae .enemy_next
    add ax,16
    cmp ax,si
    ja .turn
.enemy_next:
    add di,2
    cmp di,16
    jb .enemy
    mov ax,bp                       ; ground ahead?
    mov dx,160
    call CheckSolid
    test al,al
    jnz .move
.turn:
    neg word [enemy_dir+bx]
    jmp .collide

.slide:
    imul ax,cx,3
    add si,ax
.move:
    cmp si,928
    jbe .min
    mov si,928
.min:
    cmp si,32
    jae .store
    mov si,32
.store:
    mov [enemy_x+bx],si

.collide:
    mov ax,[hero_x]
    add ax,16
    cmp ax,[enemy_x+bx]
    jbe .next
    mov ax,[enemy_x+bx]
    add ax,16
    cmp ax,[hero_x]
    jbe .next
    mov ax,[hero_y]
    add ax,16
    cmp ax,144
    jbe .next
    cmp word [hero_y],160
    jae .next
    cmp word [enemy_state+bx],1
    je .kick
    mov ax,[hero_y]                 ; moving upward: ignore
    cmp ax,[hero_previous_y]
    jb .next
    mov ax,[hero_previous_y]
    add ax,16
    cmp ax,144
    ja .side_hit

    cmp word [enemy_state+bx],2     ; stomp
    je .shell
    cmp word [enemy_type+bx],0
    jne .koopa
mov word [enemy_state+bx],3
add dword [score],200
call CapScore
jmp .bounce
.koopa:
    add dword [score],400
    call CapScore
.shell:
    mov word [enemy_state+bx],1
.bounce:
    mov word [hero_y],128
    call SaveHeroY
    mov word [hero_vy],JUMP_SPEED
    mov byte [hero_on_ground],0
    mov byte [air_jumps],0
    jmp .next

.side_hit:
    cmp word [invulnerability_ticks],0
    jne .next

    cmp byte [hero_hp],2
    mov byte [hero_hp],1
    jne .die
    mov word [invulnerability_ticks],36
    jmp .done
.die:
    call StartDeath
    jmp .done

.kick:
    mov word [enemy_state+bx],2
    mov word [enemy_dir+bx],1
    mov ax,[hero_x]
    cmp ax,[enemy_x+bx]
    jb .next
    mov word [enemy_dir+bx],-1
.next:
    add bx,2
    cmp bx,16
    jb .loop
.done:
    ret

; ==========================================
; DRAWING
; ==========================================
; Fill rectangle. DI = x (signed), BX = y, CX = width, DX = height, AL = colour
FillRect:
    pusha
    push es
    mov si,cx
    test di,di
    jns .right
    neg di
    sub si,di
    jbe .done
    xor di,di
    jmp .height
.right:
    mov cx,SCREEN_WIDTH
    sub cx,di
    jbe .done
    cmp si,cx
    jbe .height
    mov si,cx
.height:
    mov cx,SCREEN_HEIGHT
    sub cx,bx
    jbe .done
    cmp dx,cx
    jbe .go
    mov dx,cx
.go:
    mov es,[framebuffer_segment]
    imul bx,bx,SCREEN_WIDTH
    add bx,di
.row:
    mov di,bx
    mov cx,si
    rep stosb
    add bx,SCREEN_WIDTH
    dec dx
    jnz .row
.done:
    pop es
    popa
    ret

; Draw a list of rectangles (dx,dy,w,h,colour ... 0FFh) at DI = x, BX = y. SI = list
DrawShape:
    pusha
    mov bp,sp                       ; [bp] = x, [bp+8] = y
.next:
    cmp byte [si],0FFh
    je .done
    movzx di,byte [si]
    add di,[bp]
    movzx bx,byte [si+1]
    add bx,[bp+8]
    movzx cx,byte [si+2]
    movzx dx,byte [si+3]
    mov al,[si+4]
    call FillRect
    add si,5
    jmp .next
.done:
    popa
    ret

; DI = x, BX = y, DL = tile
DrawTile:
    push si
    movzx si,dl
    add si,si
    mov si,[tile_shapes+si]
    test si,si
    jz .done
    call DrawShape
.done:
    pop si
    ret

; Draw 8x8 sprite at 2x scale. SI = sprite, DI = x, BX = y, AH = colour used for colour 4
DrawSprite:
    pusha
    mov bp,64
.cell:
    lodsb
    test al,al
    jz .skip
    cmp al,4
    jne .draw
    mov al,ah
.draw:
    mov cx,2
    mov dx,cx
    call FillRect
.skip:
    add di,2
    dec bp
    test bp,7
    jnz .cell
    sub di,16
    add bx,2
    test bp,bp
    jnz .cell
    popa
    ret

DrawMap:
    mov si,[camera_x]
    mov bp,si
    and bp,15                       ; pixel offset inside first column
    shr si,4                        ; first visible map column
    xor bx,bx
.row:
    xor cx,cx
.col:
    mov ax,si
    add ax,cx
    xor dx,dx                       ; outside the map = sky
    cmp ax,MAP_COLUMNS
    jae .draw
    mov di,bx
    shr di,4
    imul di,di,MAP_COLUMNS
    add di,ax
    mov dl,[level_map+di]
.draw:
    mov di,cx
    shl di,4
    sub di,bp
    call DrawTile
    inc cx
    cmp cx,21
    jb .col
    add bx,16
    cmp bx,MAP_ROWS*16
    jb .row
    ret

DrawEnemies:
    xor bp,bp
.loop:
    cmp word [enemy_state+bp],3
    je .next
    mov si,goomba_sprite
    cmp word [enemy_type+bp],0
    je .draw
    mov si,koopa_sprite
    cmp word [enemy_state+bp],0
    je .draw
    mov si,koopa_shell_sprite
.draw:
    mov di,[enemy_x+bp]
    sub di,[camera_x]
    mov bx,144
    mov ah,4
    call DrawSprite
.next:
    add bp,2
    cmp bp,16
    jb .loop
    ret

DrawMushroom:
    cmp byte [mushroom_active],1
    jne .done
    mov di,[mushroom_x]
    sub di,[camera_x]
    mov bx,[mushroom_y]
    mov si,mushroom_shape
    jmp DrawShape
.done:
    ret

; ==========================================
; PRINTING (BIOS teletype)
; ==========================================
; DX = row:col, SI = zero-terminated string
PrintAt:
    mov ah,2
    xor bh,bh
    int 10h
PrintStr:
    lodsb
    test al,al
    jz .done
    mov ah,0Eh
    mov bx,15
    int 10h
    jmp PrintStr
.done:
    ret

; EAX = number
PrintNumber:
    mov ebx,10
    xor cx,cx
.divide:
    xor edx,edx
    div ebx
    push dx
    inc cx
    test eax,eax
    jnz .divide
.print:
    pop ax
    add al,'0'
    mov ah,0Eh
    mov bx,15
    int 10h
    loop .print
    ret

DrawHUD:
    xor dx,dx
    mov si,hud_score
    call PrintAt
    mov eax,[score]
    call PrintNumber
    mov si,hud_coins
    call PrintStr
    movzx eax,word [coins]
    call PrintNumber
    mov si,hud_lives
    call PrintStr
    movzx eax,byte [lives]
    call PrintNumber
    mov si,hud_time
    call PrintStr
    movzx eax,word [game_time]
    call PrintNumber
    mov si,hud_power
    call PrintStr
    mov si,hud_small
    cmp byte [hero_hp],2
    jne PrintStr
    mov si,hud_super
    jmp PrintStr

RenderFrame:
    mov es,[framebuffer_segment]    ; clear to sky
    xor di,di
    mov ax,COLOR_SKY*101h
    mov cx,32000
    rep stosw
    push ds
    pop es

    mov ax,[hero_x]                 ; camera follows Mario, 0..640
    sub ax,160
    jnc .cam_max
    xor ax,ax
.cam_max:
    cmp ax,640
    jbe .cam_set
    mov ax,640
.cam_set:
    mov [camera_x],ax

    call DrawMap
    call DrawEnemies
    call DrawMushroom

    cmp byte [game_state],STATE_DYING
    ja .panel
    mov di,[hero_x]
    sub di,[camera_x]
    mov bx,[hero_y]
    mov si,mario_sprite
    mov ah,[hero_hp]                ; hp 1 -> colour 4, hp 2 -> colour 12
    shl ah,3
    sub ah,4
    call DrawSprite
    jmp .present
.panel:
    mov di,40
    mov bx,70
    mov cx,240
    mov dx,60
    mov al,6
    call FillRect

.present:
    push ds
    mov ds,[framebuffer_segment]
    mov ax,0A000h
    mov es,ax
    xor si,si
    xor di,di
    mov cx,32000
    rep movsw
    pop ds
    push ds
    pop es

cmp byte [game_state],STATE_PLAYING
je DrawHUD

cmp byte [game_state],STATE_TITLE
je .title

cmp byte [game_state],STATE_PAUSED
je .pause

mov si,life_lost_msg
cmp byte [game_state],STATE_LIFE_LOST
je .message

mov si,game_over_msg
cmp byte [game_state],STATE_GAME_OVER
jne .done
.message:
mov dx,0C0Ah
jmp PrintAt

.title:
mov dx,080Ah
mov si,title_msg
call PrintAt
mov dx,0A0Ah
mov si,start_msg
call PrintAt
jmp .done

.pause:
mov dx,0A0Ah
mov si,pause_msg
call PrintAt
jmp .done
.done:
    ret

; ==========================================
; TILES
; ==========================================
; AX = x, DX = y  ->  AL = tile, SI = map index (AH clobbered)
GetTile:
    cmp ax,960
    jae .outside
    cmp dx,192
    jae .outside
    mov si,dx
    shr si,4
    imul si,si,MAP_COLUMNS
    shr ax,4
    add si,ax
    mov al,[level_map+si]
    ret
.outside:
    xor al,al
    ret

; AX = x, DX = y  ->  AL = 1 if solid (sky, coin and flag are not). Keeps all other registers
CheckSolid:
    push si
    call GetTile
    pop si
    test al,al
    jz .done
    sub al,TILE_COIN
    cmp al,1
    seta al
.done:
    ret

; CX = fixed offset; probes three points of Mario's box (offsets 1, 8, 15 on the other axis).
; HeroSide: CX is an X offset.  HeroVert: CX is a Y offset.  ZF clear = something solid
HeroSide:
    xor bx,bx
    jmp HeroProbe
HeroVert:
    mov bx,1
HeroProbe:
    push si
    mov si,probes
.next:
    movzx ax,byte [si]
    mov dx,cx
    test bx,bx
    jnz .go
    xchg ax,dx
.go:
    add ax,[hero_x]
    add dx,[hero_y]
    call CheckSolid
    test al,al
    jnz .done
    inc si
    cmp si,probes+3
    jb .next
    xor al,al
.done:
    pop si
    ret

SaveHeroY:
    mov ax,[hero_y]
    shl ax,8
    mov [hero_y_fp],ax
    ret

; ==========================================
; PHYSICS
; ==========================================
UpdatePhysics:
    pusha
    mov ax,[hero_y]
    mov [hero_previous_y],ax

    mov bx,WALK_MAX_SPEED
    cmp byte [key_states+KEY_SHIFT],1
    jne .accel
    mov bx,RUN_MAX_SPEED
.accel:
    mov ax,[hero_vx]
    cmp byte [key_states+KEY_LEFT],1
    jne .check_right
    sub ax,WALK_ACCEL
    neg bx
    cmp ax,bx
    jge .store_vx
    mov ax,bx
    jmp .store_vx
.check_right:
    cmp byte [key_states+KEY_RIGHT],1
    jne .friction
    add ax,WALK_ACCEL
    cmp ax,bx
    jle .store_vx
    mov ax,bx
    jmp .store_vx
.friction:
    test ax,ax
    jz .store_vx
    mov cx,FRICTION
    jg .slow
    neg cx
.slow:
    mov dx,ax
    sub ax,cx
    xor dx,ax                       ; sign changed = crossed zero
    jns .store_vx
    xor ax,ax
.store_vx:
    mov [hero_vx],ax

    movsx eax,ax                    ; move horizontally, clamp to level
    add eax,[hero_x_fp]
    jns .max
    xor eax,eax
.max:
    cmp eax,HERO_MAX_X_FP
    jbe .set_x
    mov eax,HERO_MAX_X_FP
.set_x:
    mov [hero_x_fp],eax
    shr eax,8
    mov [hero_x],ax

    mov cx,[hero_vx]                ; side collision
    test cx,cx
    jz .ground
    jg .right
    xor cx,cx
    call HeroSide
    jz .ground
    mov ax,[hero_x]
    and ax,0FFF0h
    add ax,16
    jmp .push_out
.right:
    mov cx,15
    call HeroSide
    jz .ground
    mov ax,[hero_x]
    add ax,15
    and ax,0FFF0h
    sub ax,16
.push_out:
    mov [hero_x],ax
    mov word [hero_vx],0
    movzx eax,ax
    shl eax,8
    mov [hero_x_fp],eax

.ground:                            ; still standing on something?
    cmp byte [hero_on_ground],1
    jne .jump_input
    mov cx,16
    call HeroVert
    jnz .jump_input
    mov byte [hero_on_ground],0

.jump_input:
    cmp byte [key_states+KEY_SPACE],1
    jne .release
    cmp byte [jump_was_down],1
    je .vertical
    mov byte [jump_was_down],1
    cmp byte [hero_on_ground],1
    jne .air
    mov byte [hero_on_ground],0
    mov byte [air_jumps],0
    jmp .jump
.air:                               ; one extra jump in the air
    cmp byte [air_jumps],1
    jae .vertical
    inc byte [air_jumps]
.jump:
    mov word [hero_vy],JUMP_SPEED
    jmp .vertical
.release:                           ; releasing Space cuts the jump short
    xor al,al
    xchg al,[jump_was_down]
    test al,al
    jz .vertical
    cmp word [hero_vy],JUMP_CUTOFF
    jge .vertical
    mov word [hero_vy],JUMP_CUTOFF

.vertical:
    cmp byte [hero_on_ground],1
    je .end
    mov ax,[hero_vy]
    add ax,GRAVITY
    cmp ax,MAX_FALL_SPEED
    jle .set_vy
    mov ax,MAX_FALL_SPEED
.set_vy:
    mov [hero_vy],ax
    add ax,[hero_y_fp]
    mov [hero_y_fp],ax
    shr ax,8
    mov [hero_y],ax
    cmp ax,200
    jbe .direction
    cmp word [hero_vy],0
    jge .pit_death
    xor ax,ax                       ; went above the top
    mov [hero_y],ax
    mov [hero_y_fp],ax
    mov [hero_vy],ax
.direction:
    cmp word [hero_vy],0
    jl .head
    mov cx,16                       ; falling: feet
    call HeroVert
    jz .pit
    mov ax,[hero_y]
    add ax,16
    and ax,0FFF0h
    sub ax,16
    mov [hero_y],ax
    call SaveHeroY
    mov word [hero_vy],0
    mov byte [hero_on_ground],1
    mov byte [air_jumps],0
    jmp .end
.head:                              ; rising: head
    xor cx,cx
    call HeroVert
    jz .pit
    mov ax,[hero_x]
    add ax,8
    mov dx,[hero_y]
    call ActivateBlock
    mov ax,[hero_y]
    and ax,0FFF0h
    add ax,16
    mov [hero_y],ax
    call SaveHeroY
    mov word [hero_vy],0
.pit:
    cmp word [hero_y],176
    jb .end
.pit_death:
    call StartDeath
.end:
    call CollectCoins
    popa
    ret

; ==========================================
; COINS, BLOCKS, MUSHROOM
; ==========================================
CollectCoins:
    cmp byte [game_state],STATE_PLAYING
    jne .done
    mov ax,[hero_x]
    add ax,8
    mov dx,[hero_y]
    add dx,8
    call GetTile
    cmp al,TILE_COIN
    jne .done
    mov byte [level_map+si],TILE_SKY
    jmp AddCoin
.done:
    ret

CapScore:
    cmp dword [score],MAX_SCORE
    jbe .done
    mov dword [score],MAX_SCORE
.done:
    ret

AddCoin:
    inc word [coins]
    add dword [score],200
    
    call CapScore
    cmp word [coins],100            ; 100 coins = extra life
    jb .done
    mov word [coins],0
    cmp byte [lives],MAX_LIVES
    jae .done
    inc byte [lives]
.done:
    ret

; AX = x, DX = y of the point that hit the block (clobbers AX, BX, DX, SI)
ActivateBlock:
    mov bx,ax
    call GetTile
    cmp al,TILE_QUESTION_COIN
    je .coin
    cmp al,TILE_QUESTION_MUSHROOM
    je .mushroom
    cmp al,TILE_BRICK
    jne .done
    cmp byte [hero_hp],2            ; only Super Mario breaks bricks
    jne .done
    mov byte [level_map+si],TILE_SKY
    add dword [score],50
    jmp CapScore
.coin:
    mov byte [level_map+si],TILE_EMPTY_BLOCK
    jmp AddCoin
.mushroom:
    mov byte [level_map+si],TILE_EMPTY_BLOCK
    and bx,0FFF0h
    add bx,2
    mov [mushroom_x],bx
    and dx,0FFF0h
    sub dx,12
    mov [mushroom_y],dx
    mov dword [mushroom_dir],1      ; dir = 1, vy = 0
    mov byte [mushroom_active],1
.done:
    ret

UpdateMushroom:
    cmp byte [mushroom_active],1
    jne .done
    mov cx,[mushroom_dir]           ; +1 / -1
    mov dx,[mushroom_y]
    add dx,6
    mov ax,[mushroom_x]
    dec ax                          ; probe x-1 going left
    test cx,cx
    jl .probe
    add ax,13                       ; probe x+12 going right
.probe:
    call CheckSolid
    test al,al
    jz .walk
    neg word [mushroom_dir]
    jmp .gravity
.walk:
    add [mushroom_x],cx

.gravity:
    mov ax,[mushroom_vy]
    inc ax
    cmp ax,3
    jbe .fall
    mov ax,3
.fall:
    mov [mushroom_vy],ax
    add [mushroom_y],ax

    mov dx,[mushroom_y]
    add dx,12
    mov ax,[mushroom_x]
    add ax,2
    call CheckSolid
    test al,al
    jnz .land
    mov ax,[mushroom_x]
    add ax,10
    call CheckSolid
    test al,al
    jz .check
.land:
    and dx,0FFF0h
    sub dx,12
    mov [mushroom_y],dx
    mov word [mushroom_vy],0

.check:
    cmp word [mushroom_y],192       ; fell out of the level
    jae .remove
    mov ax,[mushroom_x]             ; touching Mario?
    add ax,12
    cmp ax,[hero_x]
    jbe .done
    mov ax,[hero_x]
    add ax,16
    cmp ax,[mushroom_x]
    jbe .done
    mov ax,[mushroom_y]
    add ax,12
    cmp ax,[hero_y]
    jbe .done
    mov ax,[hero_y]
    add ax,16
    cmp ax,[mushroom_y]
    jbe .done
    mov byte [hero_hp],2
    add dword [score],1000
    call CapScore
.remove:
    mov byte [mushroom_active],0
.done:
    ret

; ==========================================
; TITLE MENU
; ==========================================
UpdateTitleMenu:
    cmp byte [key_states+KEY_ENTER],1
    jne .done

    mov byte [game_state],STATE_PLAYING
    mov byte [menu_selection],0
    mov byte [pause_was_down],0

    mov word [game_time],START_TIME
    mov word [second_ticks],0
    mov word [state_ticks],0

    mov byte [lives],START_LIVES
    mov word [coins],0
    mov dword [score],0

    call ResetPlayer

.done:
    ret


; ==========================================
; GAME STATES
; ==========================================
StartDeath:
    cmp byte [game_state],STATE_PLAYING
    jne .done
    mov byte [game_state],STATE_DYING
    mov word [state_ticks],0
    mov word [hero_vx],0
    mov word [hero_vy],0FD00h
    mov byte [hero_on_ground],0
.done:
    ret

UpdateGameState:
    mov al,[game_state]
    cmp al,STATE_LIFE_LOST
    je .life_lost
    ja .game_over

    inc word [state_ticks]          ; dying animation
    mov ax,[hero_vy]
    add [hero_y_fp],ax
    add word [hero_vy],GRAVITY
    mov ax,[hero_y_fp]
    shr ax,8
    mov [hero_y],ax
    cmp word [state_ticks],27
    jb .done
    mov byte [game_state],STATE_LIFE_LOST
    cmp byte [lives],0
    je .over
    dec byte [lives]
    jnz .reset_ticks
.over:
    mov byte [game_state],STATE_GAME_OVER
.reset_ticks:
    mov word [state_ticks],0
.done:
    ret

.life_lost:
    inc word [state_ticks]
    cmp word [state_ticks],36
    jae .restart
    ret

.game_over:
    cmp byte [key_states+KEY_ENTER],1
    jne .done
    mov byte [lives],START_LIVES
    mov dword [score],0
    mov word [coins],0
.restart:
    mov word [game_time],START_TIME
    mov word [second_ticks],0
    mov word [state_ticks],0
    mov byte [game_state],STATE_PLAYING
    jmp ResetPlayer

; ==========================================
; DATA
; ==========================================
memory_error_msg db 'Not enough memory for framebuffer.$'
title_msg db 'MARIO GAME',0
start_msg db 'PRESS ENTER TO START',0
pause_msg db 'PAUSED - P TO RESUME',0
hud_score db ' SCORE: ',0
hud_coins db '  COINS: ',0
hud_lives db '  LIVES: ',0
hud_time db '  TIME: ',0
hud_power db '  POWER: ',0
hud_small db 'SMALL',0
hud_super db 'SUPER',0
life_lost_msg db 'LIFE LOST - RESTARTING',0
game_over_msg db 'GAME OVER - PRESS ENTER',0

probes db 1,8,15

; level: tile code, then map indices (row*60+col), 0-terminated; 0 ends the table
map_data:
    db TILE_QUESTION_COIN
    dw 433,438,443,0
    db TILE_QUESTION_MUSHROOM
    dw 428,447,0
    db TILE_BRICK
    dw 429,430,431,448,449,450,0
    db TILE_COIN
    dw 364,365,366,376,377,390,391,404,405,406,0
    db TILE_PIPE_TOP_LEFT
    dw 502,463,0
    db TILE_PIPE_TOP_RIGHT
    dw 503,464,0
    db TILE_PIPE_BODY_LEFT
    dw 562,523,583,0
    db TILE_PIPE_BODY_RIGHT
    dw 563,524,584,0
    db TILE_FLAG
    dw 239,299,359,419,479,539,599,0
    db 0

; tile shapes: (dx,dy,w,h,colour)... 0FFh
tile_shapes dw 0,sh_ground,sh_brick,sh_qcoin,sh_qmush,sh_empty,sh_pipe,sh_pipe,sh_pipe,sh_pipe,sh_ground,sh_coin,sh_flag
sh_ground db 0,0,16,16,6,0FFh
sh_brick db 0,0,16,16,4,0FFh
sh_qcoin db 0,0,16,16,14, 6,4,8,4,15,0FFh
sh_qmush db 0,0,16,16,10, 4,4,4,8,4, 6,8,4,4,15,0FFh
sh_empty db 0,0,16,16,11,0FFh
sh_pipe db 0,0,16,16,2,0FFh
sh_coin db 4,2,8,12,14,0FFh
sh_flag db 0,0,16,16,15,0FFh
mushroom_shape db 0,0,6,12,2, 3,6,6,6,15, 3,2,2,2,15,0FFh

mario_sprite:
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 6,6,14,14,14,14,6,6
    db 6,14,14,14,14,14,14,6
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 0,1,1,0,0,1,1,0
    db 6,6,6,0,0,6,6,6
goomba_sprite:
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 4,4,6,6,6,6,4,4
    db 0,4,6,6,6,6,4,0
    db 0,0,4,4,4,4,0,0
    db 0,4,4,4,4,4,4,0
    db 4,4,0,0,0,0,4,4
    db 4,4,0,0,0,0,4,4
koopa_sprite:
    db 0,0,14,14,14,14,0,0
    db 0,14,14,14,14,14,14,0
    db 14,14,2,2,2,2,14,14
    db 14,14,2,10,10,2,14,14
    db 0,2,2,2,2,2,2,0
    db 0,2,2,2,2,2,2,0
    db 0,0,14,0,0,14,0,0
    db 0,0,14,0,0,14,0,0
koopa_shell_sprite:
    db 0,0,0,0,0,0,0,0
    db 0,2,2,2,2,2,2,0
    db 2,2,10,2,2,10,2,2
    db 2,2,2,2,2,2,2,2
    db 2,2,2,2,2,2,2,2
    db 0,2,2,2,2,2,2,0
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0

; enemy start data: x[8], dir[8], state[8]
enemy_init dw 96,240,400,520,760,880,640,840
           dw 1,-1,1,-1,1,-1,1,-1
           dw 0,0,0,0,0,0,0,0

enemy_type dw 0,0,0,0,1,1,0,1

; ---- variables ----
hero_x dw 0
hero_y dw 0
hero_previous_y dw 0
hero_x_fp dd 0
hero_y_fp dw 0
hero_on_ground db 0
hero_hp db 0

score dd 0
coins dw 0
lives db START_LIVES
game_time dw START_TIME
second_ticks dw 0
game_state db STATE_TITLE
state_ticks dw 0
menu_selection db 0
pause_was_down db 0

; cleared by ResetPlayer
zero_start:
hero_vx dw 0
hero_vy dw 0
jump_was_down db 0
air_jumps db 0
camera_x dw 0
invulnerability_ticks dw 0
mushroom_active db 0
mushroom_x dw 0
mushroom_y dw 0
mushroom_dir dw 0
mushroom_vy dw 0
zero_end:

enemy_x times 24 dw 0
enemy_dir equ enemy_x+16
enemy_state equ enemy_x+32

key_states times 128 db 0
old_int8 dd 0
old_int9 dd 0
timer_ticks dw 0
last_ticks dw 0
framebuffer_segment dw 0
level_map times MAP_SIZE db 0

program_end:
