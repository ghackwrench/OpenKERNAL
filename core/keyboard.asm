            .cpu    "w65c02"

            .namespace  kernel
keyboard    .namespace

            .section    kmem
head        .byte       ?
tail        .byte       ?
hold        .byte       ?
            .send
            
BUF_SIZE = 16

            .section    kbuf
buf         .fill       BUF_SIZE
            .send
            
            .section    kernel

init
            stz     head
            stz     tail
            stz     hold
            rts

enque
    ; A = character to enqueue.
    ; Carry set if the queue is full.
    ; Code is thread-safe to support multiple event sources.
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
