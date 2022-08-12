;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
;
; This file is part of OpenKERNAL -- a clean-room implementation of the
; KERNAL interface documented in the Commodore 64 Programmer's Reference.
; 
; OpenKERNAL is free software: you may redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation, either version 3 of the License, or (at your option)
; any later version.
; 
; OpenKERNAL is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
; for more details.
; 
; You should have received a copy of the GNU Lesser General Public License
; along with OpenKERNAL. If not, see <https://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
        
