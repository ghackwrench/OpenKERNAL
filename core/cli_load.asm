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
        jsr     find_arg
        bcc     _quote
        rts

_quote         
        jsr     set_fname
        bcs     _out

        lda     fname_len
        cmp     #5          ; has an extension?
        bcc     _prg        ; No, default to prg.

      ; Y = start of extension (starting with the '.').
        lda     fname+0
        clc
        adc     fname_len
        sec
        sbc     #4      ; should be start of ext
        tay
        
      ; Does it start with a '.'?
        lda     (fname),y
        cmp     #'.'
        bne     _prg    ; No, default to prg.     

        iny     
        jmp     load_by_extension
_prg    jmp     load_prg
_out    rts

extensions
        .text   "PRG", load_prg
        .byte   0

load_by_extension
        ldx     #0
_loop   lda     extensions,x
        beq     _failed
        jsr     _cmp
        bcc     _found
        txa
        adc     #4  ; 5 with the carry
        tax
        bra     _loop
_found  jmp     (extensions+2,x)
_failed sec
        rts
_cmp
        phy
        sec

        lda     (fname),y
        bit     extensions+0,x
        bne     _out
        
        iny
        lda     (fname),y
        bit     extensions+1,x
        bne     _out
        
        iny
        lda     (fname),y
        bit     extensions+2,x
        bne     _out
        
        clc
_out
        ply
        rts        


load_prg
        lda #2
        sta $1

        ldy #0
_loop
        lda (fname),y
        sta $c001,y
        iny
        cpy fname_len
        bne _loop
          

          ; Set Y=0 for fname == "$", Y=1 (binary) otherwise.
            ldy     #1
            lda     fname_len
            cmp     #1
            bne     _setlfs
            lda     (fname)
            cmp     #'$'
            bne     _setlfs
            ldy     #0      ; Directory requested, override load address.

_setlfs     
        tya
        ora #'0'
        sta $c000

            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            jsr     SETLFS
            
          ; Load the data
            lda     #0      ; load, not verify
            ldx     #<$801  ; in case of directory
            ldy     #>$801  ; in case of directory
            jmp     LOAD

set_fname
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
            
