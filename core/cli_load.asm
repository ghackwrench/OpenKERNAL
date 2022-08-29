; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  shell
            
            .section    dp
quote       .byte       ?   ; Offset to start of quoted string.
            .send            
            
            .section    kernel

load
    ; IN: cmd[] starts with "LOAD"
    
        ldy     #4  ; next character after "LOAD"
_loop   lda     cmd,y
        cmp     #$22    ; quote
        beq     _quote
        cmp     #' '
        bne     _error
        iny
        bra     _loop
_error
        sec
_out    
        rts
_quote         
        jsr     get_quoted
        bcs     _out

          ; Request operation on 0,8,0
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     #8      ; Hard-coded for the moment
            ldy     #0      ; No sub-device / "command" -> use $0801
            jsr     SETLFS

          ; Load the data
            lda     #0      ; load, not verify
            ldx     #<$801
            ldy     #>$801
            jsr     LOAD
            bcs     _out    ; TODO: print the error
            
        rts

get_quoted
        iny
        phy
_loop   lda     cmd,y
        cmp     #$22    ; Quote
        beq     _setnam
        cmp     #13
        beq     _error
        iny
        bne     _loop
_error
        sec
_done
        ply
        rts

_setnam
      ; A = length of string
        tya
        tsx
        sec
        sbc     $101,x  ; Start of string (on stack)
        beq     _error
        
      ; X = LSB of string
        plx
        
      ; Y = MSB of string
        ldy     #>cmd
                        
        jsr     SETNAM
        clc
        rts
        

            .send
            .endn
            .endn
            
