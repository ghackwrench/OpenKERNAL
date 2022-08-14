; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

            .namespace  kernel
shell       .namespace            
            .section    shell

start
            lda     #<_msg
            sta     src
            lda     #>_msg
            sta     src+1
            ldy     #0
_loop       lda     (src),y
            beq     _done
            jsr     platform.console.putc
            iny
            bne     _loop
            inc     src+1
            bra     _loop
_done       
            jsr     keyboard.deque
            bcc     _report
            wai
            bra     _done
_report     jsr     platform.console.putc
            bra     _done            
            

_msg        .text   "OpenKERNAL - a clean-room implementation of the C64 KERNAL ABI",13
            .text   "Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.",13
            .text   "Released under the GPL3 license with the kernel exception:",13
            .text   "applications which simply use the ABI are not 'derived works'.", 13
            .text   13
            .text   "There will be a simple shell here soon.", 13
            .byte   0

            .send 
            .endn
            .endn
                     

