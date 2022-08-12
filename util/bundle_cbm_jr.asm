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

; Use 64tass to stitch binaries together without
; relying on additional shell tools (eg cat and cut).

*           = $a000     ; CBM BASIC starts here 
            .binary     basic, $0, $2000

*           = $e000     ; CBM BASIC continues here
            .binary     basic, $2000, $0500 ; CBM Basic eats into the kernel.
            .binary     kernel, $0500       ; Kernel from $e500 to end.
