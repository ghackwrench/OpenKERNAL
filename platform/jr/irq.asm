; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file is from the w6502c TinyCore kernel by the same author.

            .cpu    "w65c02"

irq         .namespace

        ; Interrupt Sources
            .virtual    0
frame       .byte       ?
line        .byte       ?
ps2_0       .byte       ?
ps2_1       .byte       ?
timer0      .byte       ?
timer1      .byte       ?
dma         .byte       ?
            .byte       ?
serial      .byte       ?
col0        .byte       ?
col1        .byte       ?
col2        .byte       ?
rtc         .byte       ?
via         .byte       ?
iec         .byte       ?
sdc         .byte       ?
max         .endv
            
        ; Dispatch table
            .section kmem
irq0        .fill   8
irq1        .fill   8
            .send

        ; Interrupt priotity table
            .section    tables
first_bit: 	.byte	0, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
	    	.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
		.byte	5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
	    	.byte	6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
                .byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
	    	.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	7, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    		.byte	4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
            .send

            .section    kernel
 .align 256
init:
            pha

            stz     $1

          ; Begin with all interrupts masked.
          ; Begin with all interrupts on the falling edge.
            lda     #$ff
            sta     INT_MASK_REG0
            sta     INT_MASK_REG1
            sta     INT_EDGE_REG0
            sta     INT_EDGE_REG1
            lda     INT_PENDING_REG0
            sta     INT_PENDING_REG0
            lda     INT_PENDING_REG1
            sta     INT_PENDING_REG1

            ; Polarities aren't presently initialized in the
            ; official Foenix kernel; leaving them uninitialized
            ; here.
            ; lda   #0
            ; sta   INT_POL_REG0
            ; sta   INT_POL_REG2

            lda     #<dummy
            sta     Devices+2
            lda     #>dummy
            sta     Devices+3
            lda     #2
            ldy     #0
_loop       sta     irq0,y
            iny
            cpy     #16
            bne     _loop

            cli
            pla
            clc
dummy       rts

show
    ldy     #2
    sty     $1
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    tay
    lda _hex,y
    sta $c020
    pla
    and #$0f
    tay
    lda _hex,y
    sta $c021
    stz $1
    rts
_hex    .null   "0123456789abcdef"    
show2
    pha
    phy
    ldy     #2
    sty     $1
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    tay
    lda _hex,y
    sta $c022
    pla
    and #$0f
    tay
    lda _hex,y
    sta $c023
    stz $1
    ply
    pla
    rts
_hex    .null   "0123456789abcdef"    

dispatch:
            
_reg0       stz     $1
            ldx     INT_PENDING_REG0
            beq     _reg1
            ldy     first_bit,x     ; 0..7
            lda     bit,y           ; 1, 2, 4, ...
            sta     INT_PENDING_REG0
            ldx     irq0,y
            jsr     kernel.device.data
            bra     _reg0

_reg1       stz     $1
            ldx     INT_PENDING_REG1
            beq     _reg2
            ldy     first_bit,b,x
            lda     bit,b,y
            sta     INT_PENDING_REG1
            ldx     irq1,y
            jsr     kernel.device.data
            bra     _reg1

_reg2       rts

bit:        .byte   1,2,4,8,16,32,64,128

install:
    ; IN:   A -> lsb of a vector in Devices
    ;       Y -> requested IRQ ID
            
            cpy     #max
            bcs     _out
    
            sta     irq0,y
_out        rts            


enable:
    ; IN:   A -> requested IRQ ID to enable.
            
            cmp     #max
            bcs     _out

            phx
            jsr     map
            eor     #255    ; clear bit to enable source.
            and     INT_MASK_REG0,x
            sta     INT_MASK_REG0,x
            plx

_out        rts

map:            
    ; A = IRQ #
    ; X <- IRQth byte
    ; A <- IRQth bit set
    
          ; Offset X to the IRQth byte.
            ldx     #0
            bit     #8
            beq     _bit
            inx

_bit        and      #7
            phy
            tay
            lda     bit,y
            ply
            rts

disable:
    ; IN:   A -> requested IRQ ID to diable.
            
            cmp     #max
            bcs     _out

            phx
            jsr     map
            ora     INT_MASK_REG0,x
            sta     INT_MASK_REG0,x
            plx          
        
_out        rts


        .send
        .endn
