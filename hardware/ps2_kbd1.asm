        .cpu    "w65c02"

        .namespace hardware

kbd1    .namespace

        .section    kmem
e0      .byte   ?
flags   .fill   32
        .send

        .section kernel

init:
        stz e0
        phx
        ldx #0
_loop   stz flags,x
        inx
        cpx #32
        bne _loop
        plx            
        clc
        rts

accept:
        ldx e0
        bne _e0_key

        cmp #$e0
        beq _set_e0

        tay         ; Stash the release flag.
        and #$7f    ; Clear the release flag.

        tax
        lda mode1,x
        beq _done   ; Unknown code; drop.

        tax         ; Save translated value.
        and #$f0    ; Get code set.

        cpy #0
        bmi _release

        cmp #$10
        beq _flags
        txa

_send
        ldx #2
        stx $1
        sta $c01f
        stz $1
        jsr     kernel.keyboard.enque
        rts

_meta   .byte 1,1,2,2,4,4,8,8,1

_flags  sta flags,x
        rts

_release
        sec
        sbc #$10
        beq _flags
        rts

_set_e0 sta e0
_done   rts

_e0_key stz e0
        rts



mode1
        .byte   0, ESC, '1', '2', '3', '4', '5', '6'
        .byte   '7', '8', '9', '0', '-', '=', BKSP, TAB
        .byte   'q', 'w', 'e', 'r', 't', 'y', 'u', 'i'
        .byte   'o', 'p', '[', ']', RETURN, LCTRL, 'a', 's'
        .byte   'd', 'f', 'g', 'h', 'j', 'k', 'l', ';'
        .byte   "'", '`', LSHIFT, '\', 'z', 'x', 'c', 'v'
        .byte   'b', 'n', 'm', ',', '.', '/', RSHIFT, KTIMES
        .byte   LALT, ' ', CAPS, F1, F2, F3, F4, F5
        .byte   F6, F7, F8, F9, F10, NUM, SCROLL, K7
        .byte   K8, K9, KMINUS, K4, K5, K6, KPLUS, K1
        .byte   K2, K3, K0, KPOINT, SYSREQ, 0, 0, F11
        .byte   F12
mode1_end

e0_table
        .byte   $1c, KENTER
        .byte   $1d, RCTRL
        .byte   $35, KDIV
        .byte   $37, PRTSCR
        .byte   $38, RALT
        .byte   $46, BREAK
        .byte   $47, HOME
        .byte   $48, UP
        .byte   $49, PUP
        .byte   $4b, LEFT
        .byte   $4d, RIGHT
        .byte   $4f, END
        .byte   $50, DOWN
        .byte   $51, PDN
        .byte   $52, INS
        .byte   $53, DEL
        .byte   $5b, LMETA
        .byte   $5c, RMETA
        .byte   $5d, MENU
        .byte   $5e, POWER
        .byte   $5f, SLEEP
        .byte   $63, WAKE

; 126	72	e1-1d-45	e1-11-0b	e1-14-77	e1-1d-45	62	77	Pause

        .send
        .endn
        .endn
