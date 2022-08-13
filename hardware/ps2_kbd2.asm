; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file is from the w6502c TinyCore kernel by the same author.

        .cpu    "w65c02"

        .namespace  hardware

kbd2    .namespace
        
            .section    kmem
e0          .byte   ?
release     .byte   ?
flags:      .fill 32

            .send
            
            .section kernel

init
            stz     e0
            stz     release
        phx
        ldx #0
_loop   stz flags,x
        inx
        cpx #32
        bne _loop
        plx            
        clc
            rts

search
    ; Map keys prefixed with $e0.
            ldx     #0
_loop       cmp     _etab,x
            beq     _found
            inx
            inx            
            cpx     #_end
            bne     _loop
            lda #0  ; Ignore for the moment
            rts

_found      lda     _etab+1,x
            rts

_etab       
            .byte   $14, RCTRL
            .byte   $6c, HOME
            .byte   $70, INS
            .byte   $74, RIGHT
            .byte   $11, RALT
            .byte   $69, END
            .byte   $71, DEL
            .byte   $75, UP
            .byte   $7d, PUP
            .byte   $72, DOWN
            .byte   $7a, PDN
            .byte   $6b, LEFT            
_end        = * - _etab

accept:
            cmp #$f0
            beq _release

            cmp #$e0
            beq _e0

            cmp #$e1
            beq _send

            cmp #$84
            bcs _drop

            ldx e0,b
            beq _std
            jsr search
            bra _code
_std
            tax
            lda keymap,b,x

_code       ldx release
            beq _press

            ; Clear mode flags
            tax
            and #$f0
            cmp #16
            bne _drop
            stz flags,b,x
            
_drop       stz e0,b
            stz release,b
            rts

_search     jsr     search
            bra     _code


_release    sta release,b
            rts

_e0         sta e0,b
            rts

_press      jsr _drop
            tax
            and #$f0
            cmp #16
            bne _key
            sta flags,b,x
            rts

_key        txa
            cmp #0
            beq _end
_send       jsr _flags

.if false
        ldx #2
        stx $1
        sta $c01f
        stz $1
.endif        
            jsr kernel.keyboard.enque

_end        rts

_flags      pha
            lda #0
            ldx #0
_loop       ldy flags+16,b,x
            beq _next
            ora _meta,b,x
_next       inx
            cpx #9
            bne _loop
            tsx
            bit #2
            bne _ctrl
            bit #1
            bne _shift
_out        pla
            rts
_meta       .byte 1,1,2,2,4,4,8,8,1                                    
_ctrl       lda Stack+1,x
            and #$1f
            sta Stack+1,x
            bra _out
_shift      lda Stack+1,x
            jsr shift
            sta Stack+1,x
            bra _out    

shift
            cmp #'a'
            bcc _find
            cmp #'z'+1
            bcs _find
            eor #$20
            rts
_find
            ldy #0
_loop       cmp _map,y
            beq _found
            iny
            iny
            cpy #_end
            bne _loop
            rts
_found      lda _map+1,y
            rts
_map
            .byte   '1', '!'
            .byte   '2', '@'
            .byte   '3', '#'
            .byte   '4', '$'
            .byte   '5', '%'
            .byte   '6', '^'
            .byte   '7', '&'
            .byte   '8', '*'
            .byte   '9', '('
            .byte   '0', ')'
            .byte   '-', '_'
            .byte   '=', '+'

            .byte   '[', '{'
            .byte   ']', '}'
            .byte   $5c, '|'

            .byte   ';', ':'
            .byte   $27, $22

            .byte   ',', '<'
            .byte   '.', '>'
            .byte   '/', '?'
            
_end        = * - _map
            


keymap:

            .byte 0, F9, 0, F5, F3, F1, F2, F12
            .byte 0, F10, F8, F6, F4, 9, '`', 0
            .byte 0, LALT, LSHIFT, 0, LCTRL, 'q', '1', 0
            .byte 0, 0, 'z', 's', 'a', 'w', '2', 0
            .byte 0, 'c', 'x', 'd', 'e', '4', '3', 0
            .byte 0, ' ', 'v', 'f', 't', 'r', '5', 0
            .byte 0, 'n', 'b', 'h', 'g', 'y', '6', 0
            .byte 0, 0, 'm', 'j', 'u', '7', '8', 0
            .byte 0, ',', 'k', 'i', 'o', '0', '9', 0
            .byte 0, '.', '/', 'l', ';', 'p', '-', 0
            .byte 0, 0, "'", 0, '[', '=', 0, 0
            .byte CAPS, RSHIFT, RETURN, ']', 0, '\', 0, 0
            .byte 0, 0, 0, 0, 0, 0, BKSP, 0
            .byte 0, K1, 0, K4, K7, 0, 0, 0
            .byte K0, KPOINT, K2, K5, K6, K8, ESC, NUM
            .byte F11, KPLUS, K3, KMINUS, KTIMES, K9, SCROLL, 0
            .byte 0, 0, 0, F7, SYSREQ, 0, 0, 0, 0

            .send
            .endn
            .endn
