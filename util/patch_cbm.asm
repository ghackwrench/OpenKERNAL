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

; Use 64tass to patch C64 BASIC's floating point bug,
; see https://www.c64-wiki.com/wiki/Multiply_bug

    .binary basic, $0, $1a40
    .byte   $5e, $ba, $a5, $65, $20, $59, $ba, $a5
    .byte   $64, $20, $59, $ba, $a5, $63, $20, $5e
    .binary basic, $1a50
