; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
io          .namespace
            .section    kernel

mkdev       .macro      DEV
            .word       \1_open, \1_stat, \1_io, \1_close
            .endm

devices
            .mkdev      keyboard
            .mkdev      missing     ; dataset
            .mkdev      missing     ; rs232
            .mkdev      screen
            .mkdev      missing     ; printer0
            .mkdev      missing     ; printer1
            .mkdev      missing     ; plotter0
            .mkdev      missing     ; plotter1
            .mkdev      missing     ; disk

device      .namespace
            .virtual    devices
open        .word       ?
stat        .word       ?
io          .word       ?
close       .word       ?
            .endv
            .endn

open_x      jmp     (device.open,x)
read_x      clc
            jmp     (device.io,x)
write_x     sec
            jmp     (device.io,x)            
close_x     jmp     (device.close,x)

missing_open
missing_stat
missing_io
missing_close
            lda     #DEVICE_NOT_PRESENT
            jmp     error

simple_open
            lda     #1  ; open
            sta     file.state,y
            clc
            rts
            
simple_close
            lda     #0
            sta     file.state,y
            clc
            rts


            .send
            .endn
            .endn
            
