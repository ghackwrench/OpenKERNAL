; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Instantiate an i8042 PS2 stack.

            .cpu    "w65c02"

            .namespace  platform
ps2         .namespace

            .section    kernel

i8042       .hardware.i8042 $D640

init
        stz     $1  ; The i8042 registers are in General I/O.
        
      ; Init and open the i8042 device.
        jsr     i8042.init
        bcs     _out
        jsr     kernel.device.open
        bcs     _out

      ; Init and open the first PS2 device.
        phx
        txa
        ldy     #irq.ps2_0
        jsr     hardware.ps2.init
        bcs     _e1
        jsr     kernel.device.open
_e1     plx
        bcs     _out
       
      ; Init and open the second PS2 device.
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
        .endn
        
