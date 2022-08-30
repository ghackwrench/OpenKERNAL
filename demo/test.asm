            .cpu    "65c02"
                
            .virtual    $fb     ; A tiny slice of DP
            .dsection   dp
            .endv

            .section    dp
src         .word       ?
            .send      

CHROUT = $ffd2

            .section    code
start
            lda     #<_text
            sta     src+0
            lda     #>_text
            sta     src+1
            ldy     #0
_loop       lda     (src),y
            beq     _done
            jsr     CHROUT
            iny
            bra     _loop
_done       rts
_text       .text   "Hello World!", 13, 0

            .send
            

