; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Use 64tass to stitch binaries together without
; relying on additional shell tools (eg cat and cut).

*           = $a000     ; CBM BASIC starts here 
            .binary     basic, $0, $2000

*           = $e000     ; CBM BASIC continues here
            .binary     basic, $2000, $0500 ; CBM Basic eats into the kernel.
            .binary     kernel, $0500       ; Kernel from $e500 to end.
