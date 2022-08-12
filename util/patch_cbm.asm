; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Use 64tass to patch C64 BASIC's floating point bug,
; see https://www.c64-wiki.com/wiki/Multiply_bug

    .binary basic, $0, $1a40
    .byte   $5e, $ba, $a5, $65, $20, $59, $ba, $a5
    .byte   $64, $20, $59, $ba, $a5, $63, $20, $5e
    .binary basic, $1a50
