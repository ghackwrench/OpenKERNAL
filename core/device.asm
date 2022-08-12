            .cpu        "w65c02"
            
            .namespace  kernel

dev         .namespace
            .virtual    Devices

          ; External functions
data        .word       ?       ; Data ready
status      .word       ?       ; Status change
fetch       .word       ?       ; Device requests data to send

          ; Internal functions
open        .word       ?       ; Call to open device
get         .word       ?       ; Call to get device data
set         .word       ?       ; Call to set device data
send        .word       ?       ; Call to send data
close       .word       ?       ; Call to close device
size        .endv
            .endn

device      .namespace

mkdev       .macro  PREFIX
            .word   \1_data
            .word   \1_status
            .word   \1_fetch
            .word   \1_open
            .word   \1_get
            .word   \1_set
            .word   \1_send
            .word   \1_close
            .endm

            .section    kmem
entries     .byte       ?       ; List of free device entries
            .send
            
            .section    kernel

data        jmp     (kernel.dev.data,x)
status      jmp     (kernel.dev.status,x)
fetch       jmp     (kernel.dev.fetch,x)
open        jmp     (kernel.dev.open,x)
get         jmp     (kernel.dev.get,x)
set         jmp     (kernel.dev.set,x)
send        jmp     (kernel.dev.send,x)
close       jmp     (kernel.dev.close,x)

init
            stz     entries
            lda     #0
            bra     _next   ; Reserve the first one.
_loop       tax
            jsr     free
_next       clc
            adc     #<dev.size
            bne     _loop
            
            clc
            rts

alloc
            sec
            ldx     entries
            beq     _out
            pha 
            lda     Devices,x
            sta     entries
            pla
            clc
_out        rts


free
            pha
            lda     entries
            sta     Devices,x
            stx     entries
            pla
            clc
            rts

install
    ; kernel.src function table.
            pha
            phx
            phy
            ldy     #0
_loop       lda     (src),y
            sta     Devices,x
            inx
            iny
            cpy     #<dev.size
            bne     _loop
            ply
            plx
            pla
            clc
            rts            

queue       .namespace
            .virtual    DevState
head        .byte       ?
tail        .byte       ?
            .endv

init
            stz     head,x
            stz     tail,x
            rts

enque
    ; X = queue, Y = token

            pha
            php
            sei
            lda     tail,x
            sta     kernel.token.entry.next,y
            tya
            sta     tail,x
            plp
            pla
            clc
            rts                        

deque
    ; OUT:  Y = dequed token; carry set on empty

            pha    

            ldy     head,x
            bne     _found

            sec
            ldy     tail,x
            beq     _out
            
          ; Safely take the tail (into y)
            php
            sei
            ldy     tail,x
            stz     tail,x
            plp

          ; Reverse into head
_loop       lda     kernel.token.entry.next,y   ; next in A
            pha                                 ; next on stack
            lda     head,x
            sta     kernel.token.entry.next,y
            tya
            sta     head,x
            ply                                 ; next in Y
            bne     _loop

          ; "Find" the head (just where we left it)
            ldy      head,x

_found      
            lda     kernel.token.entry.next,y
            sta     head,x
            clc
            
_out        pla
            rts
            
            .endn
            .send
            .endn
            .endn

