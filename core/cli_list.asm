; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  shell

            .section    kernel
list
            jsr     cr

            phx
            phy

            ldx     #0  ; count MSB
            ldy     #0  ; count LSB

            lda     #<$801
            sta     src+0
            lda     #>$801
            sta     src+1

_line       
          ; File ends when the would-be next address is zero.
            jsr     _fetch
            sta     tos_l       ; tmp
            jsr     _fetch
            ora     tos_l
            beq     _done

          ; Fetch the line number
            jsr     _fetch
            sta     tos_l
            jsr     _fetch          
            sta     tos_h
            
          ; Print the line number
            jsr     print_number          

          ; Print the rest of the line
_loop       
            jsr     _fetch
            beq     _eol
            
            cmp     #32
            bcc     _fill
            cmp     #128
            bcc     _putc
_fill       lda     #' '
          ; Check for a token...
_putc       jsr     platform.console.putc
            bra     _loop
            
_eol        jsr     cr
            bra     _line
                        
_fetch
            lda     (src),y
            iny
            bne     _fetched
            inc     src+1
_fetched
            ora     #0
            rts  
            
_done       
            ply
            plx
            clc
            rts

print_number
            phx
            phy

            stz     printing
            ldx     #0      ; Not yet printing
            ldy     #0
_loop       jsr     _cmp
            bcc     _print
            inc     printing
            inx
            jsr     _sub
            bra     _loop
_print      lda     printing
            beq     _next

            txa
            clc
            adc     #'0'
            jsr     platform.console.putc
            ldx     #0
_next
            iny
            iny
            cpy     #10
            bne     _loop

            lda     printing
            bne     _done
            lda     #'0'
            jsr     platform.console.putc
            
_done
            lda     #' '
            jsr     platform.console.putc
            ply
            plx
            clc
            rts            
_cmp
            lda     tos_h
            cmp     _table+1,y
            bcc     _out        ; MSB is lower
            bne     _out        ; MSB is higher
            lda     tos_l
            cmp     _table+0,y  ; Result is LSB compare
_out        rts            

_sub        
            sec
            lda     tos_l
            sbc     _table+0,y
            sta     tos_l
            lda     tos_h
            sbc     _table+1,y
            sta     tos_h
            rts
_table
            .word   10000, 1000, 100, 10, 1

            .send
            .endn
            .endn
            
