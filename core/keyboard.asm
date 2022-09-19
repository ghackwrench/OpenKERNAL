; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
keyboard    .namespace

            .section    kmem
head        .byte       ?
tail        .byte       ?
ctrl_c      .byte       ?
            .send
            
BUF_SIZE = 16

            .section    kbuf
buf         .fill       BUF_SIZE
            .send
            
            .section    kernel

init
            stz     head
            stz     tail
            stz     ctrl_c
            rts
stop
          ; See if a ctrl_c has been queued.
            lda     ctrl_c
            bne     _stop

          ; No stop detected.
            lda     #$ff
            clc
            rts

_stop
          ; Nominally reset the I/O paths.
            jsr     CLRCHN

          ; Flush the keyboard queue.
            sei
            stz     head
            stz     tail
            cli

          ; Clear the ctrl_c condition.
            stz     ctrl_c

          ; Return 'stopped' status.
            lda #0
            sec
            rts

enque
    ; A = character to enqueue.
    ; Carry set if the queue is full.
    ; Code is thread-safe to support multiple event sources.

            cmp     #3      ; ctrl_c
            bne     _enque
            sta     ctrl_c
_enque
            phx
            sec     ; Pre-emptively set carry
            php     ; Carry is on the stack.
            sei
            ldx     head
            sta     buf,x
            dex
            bpl     _ok
            ldx     #BUF_SIZE-1
_ok         cpx     tail            
            beq     _out
            stx     head
            tsx
            dec     Stack+1,x   ; Clear carry     
_out        plp
            plx
            rts

            
deque
    ; A <- character, or carry set on empty.
    ; Not thread safe, as the KERNAL calls are not thread safe.
            phx
            ldx     tail
            cpx     head
            sec
            beq     _out
            lda     buf,x
            dex
            bpl     _ok
            ldx     #BUF_SIZE-1
_ok         stx     tail
            clc
_out        plx
            rts                        
            
            .send
            .endn
            .endn
