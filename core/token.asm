; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file is from the w6502c TinyCore kernel by the same author.

            .cpu        "w65c02"
            
            .namespace  kernel
token       .namespace

entry       .namespace
            .virtual    Tokens
data        .fill       3
next        .byte       ?
end         .endv
size =      end - Tokens
            .endn
            
            .section    kmem
entries     .byte       ?       ; free list
            .send
            
            .section    kernel

init
            stz     entries
            lda     #<tokens_start
_loop       tay
            jsr     free
            clc
            adc     #entry.size
            bne     _loop
            
            clc
            rts

alloc
    ; Y <- next token, or carry set.
    ; Thread safe.
            pha
            php
            sei
            ldy     entries
            beq     _empty
            lda     entry.next,y
            sta     entries
            plp
            pla
            clc
            rts
_empty      plp
            pla
            sec
            rts

free
    ; Y = token to free
    ; Thread safe
            pha
            php
            sei
            lda     entries
            sta     entry.next,y
            sty     entries
            plp
            pla
            clc
            rts

            .send
            .endn
            .endn

