; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  shell

            .section    dp
far_addr    .fill       4
far_dest    .fill       4
            .send            

            .section    kernel

extensions
        .text   "PGX", load_pgx
        .text   "PRG", load_prg
        .text   "prg", load_prg
        .text   "pgx", load_pgx
        .byte   0

load
  lda #2
  sta $1

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
        lda     fname_len
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
_found  jmp     (extensions+3,x)
_failed 
        lda     #4  ; TODO
        sec
        rts
_cmp
        phy
        sec

        lda     (fname),y
        eor     extensions+0,x
        bne     _out
        
        iny
        lda     (fname),y
        eor     extensions+1,x
        bne     _out
        
        iny
        lda     (fname),y
        eor     extensions+2,x
        bne     _out
        
        clc
_out
        ply
        rts        


load_prg

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
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            jsr     SETLFS
            
          ; Load the data
            lda     #0      ; load, not verify
            ldx     #<$801  ; in case of directory
            ldy     #>$801  ; in case of directory
            jmp     LOAD


load_pgx
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     #8; device
            ldy     #1      ; load at x/y below
            jsr     SETLFS

            ldx     #<$801
            ldy     #>$801
            lda     #0      ; read
            

    ; IN:   Device and sub set using SETLFS
    ;       File name set using SETNAM
    ;       A= 0->read, 1..255->verify
    ;       X/Y = dest address (if secondary != 0)
    ;
    ; OUT:  X/Y = end address, or carry set and A = error.
    ;
    ; NOTE: On error, A is a KERNAL error, NOT a READST vlaue!

          ; initialize dest; may be overriden later 
            stx     dest+0
            sty     dest+1

          ; X = read/verify
            tax

          ; Y = flag to use address in file over dest address above.
            ldy     cur_addr
            
          ; Reset the iec queue and status
            jsr     kernel.iec.reset

          ; Open the file for read.  
          ; NOTE: returns a KERNAL error; must check READST as well!
            jsr     kernel.iec.open_file_for_read
            bcs     _out
            jsr     READST
            ora     #0
            bne     _error
            
          ; Read the file, sets X/Y to last address.
            jsr     read_verify_pgm_data
            bcs     _error
            
            jsr     kernel.iec.close_file
            bcs     _error
            
_out        rts
_error      
            jsr     error
            clc
            bra     _out
    

read_verify_pgm_data

    ; Internal funciton.
    ; Implements load-body for .pgx files.
    ;
    ; IN:   SETNAM and SETLFS have been called.
    ;
    ; Out:  X:Y = end address, far_addr = exec address
    ;       On error, Carry set, and A = IEC error (READST value)

          ; Make sure it's a PGX file.
            ldx     #0
_signature  jsr     IECIN
            bcs     _error
            cmp     _ident,x
            bne     _mismatch
            inx
            cpx     #4
            bne     _signature

          ; Read the dest and exec addresses.
            ldx     #0
_addr       jsr     IECIN
            bcs     _error
            sta     far_dest,x
            sta     far_addr,x
            inx
            cpx     #4
            bne     _addr

_loop       
            jsr     IECIN
            bcc     _found
            eor     #kernel.iec.EOI
            beq     _done
_error      jmp     error   ; Forward the IEC error status.

_found
            jsr     platform.far_store
            ldx     #far_dest
            jsr     far_inc

            bcc     _loop
_done       clc
_out            
            ldx     far_dest+0
            ldy     far_dest+1
            rts          

_ident      .text   "PGX",0 ; 6502 family
_mismatch   lda     #kernel.iec.MISMATCH
            sec
            bra     _error


far_inc
    ; IN:   X->32 bit long in DP
            inc     0,x
            bne     _done
            inc     1,x
            bne     _done
            inc     2,x
            bne     _done
            inc     3,x
_done       rts            

            .send
            .endn
            .endn
            
