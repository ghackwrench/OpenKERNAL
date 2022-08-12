            .cpu    "w65c02"

*           = $fffa ; Hardware vectors.
            .word   platform.hw_nmi
            .word   platform.hw_reset
            .word   platform.hw_irq

platform    .namespace

            .section    kmem
shadow0     .byte       ?
shadow1     .byte       ?
nmi_flag    .byte       ?
            .send

spin    .macro   OFFSET
.if false
        pha
        php
        sei
        lda  #2
        sta  $1
        inc  $c000+\1
        stz  $1
        plp
        pla
.endif        
        .endm

            .section    kernel

booted      .byte       0

hw_reset:

        sei

      ; Initialize the stack pointer
        ldx     #$ff
        txs        

        lda     #1
        sta     nmi_flag

        lda     booted
        beq     _init

      ; Reset pressed again ... prepare for a fresh load
        jsr     console.init
        jmp     error         

      ; Initialize the hardware
_init   inc     booted
        jsr     init

      ; Map the I/O space
        stz     shadow1
        stz     $1
        
      ; Chain to the kernel
        jmp     kernel.start

init
        jsr     _init
        bcs     error
     rts    ; to basic
        
        lda     #'*'
        jsr     platform.console.putc
        jsr     platform.console.putc
        jsr     platform.console.putc
        jsr     platform.console.putc

        ldx     #0
        ldy     #3
        jsr     platform.console.gotoxy

_loop
        jsr     kernel.keyboard.deque
        bcs     _loop
        jsr     platform.console.putc
        bra     _loop

        rts

_init
        jsr     kernel.keyboard.init
        jsr     console.init 
        bcs     _out
        stz     shadow1
        stz     $1
        jsr     kernel.token.init
        jsr     kernel.device.init
        jsr     irq.init
        jsr     frame_init
        bcs     _out
        jsr     ps2_init
        bcs     _out

_out    rts        

error   jmp     kernel.error
        

frame_init

        lda     #<frame_irq
        sta     frame+0
        lda     #>frame_irq
        sta     frame+1

        lda     #<frame
        ldy     #irq.frame
        jsr     irq.install

        lda     #irq.frame
        jsr     irq.enable
        
        rts

frame_irq

_ticks
        inc     kernel.ticks
        bne     _end
        inc     kernel.ticks+1
_end
        
        #spin   0
        ;jsr platform.kbd_irq
        rts


hw_nmi: 
        stz     nmi_flag
   pha
   lda #2
   sta $1
   lda $c002
   inc a
   sta $c002
   lda shadow1
   sta $1
   pla
        rti

hw_irq:
        pha
        phx
        phy
        
        jsr     irq.dispatch
       
_resume
        lda     shadow1
        sta     $1
        
        ply
        plx
        pla
        rti

ps2_init
   stz shadow1
   stz $1
        jsr     i8042.init
        bcs     _out
        jsr     kernel.device.open
        bcs     _out

        phx
        txa
        ldy     #irq.ps2_0
        jsr     hardware.ps2.init
        bcs     _e1
        jsr     kernel.device.open
_e1     plx
        bcs     _out

       
        phx
        txa
        ldy     #irq.ps2_1
        jsr     hardware.ps2.init
        bcs     _e2
        jsr     kernel.device.open
_e2     plx
        bcs     _out
        
        clc
_out    rts


        .send
        .endn


