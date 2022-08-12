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
            lda     #0
            bra     _next   ; Reserve the first one.
_loop       tay
            jsr     free
_next       clc
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

.if false
free2        
            pha
            lda     entries
            sta     entry.next,y
            sty     entries
            pla
            clc
            rts
.endif
            
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

