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
far_count   .fill       4
addr_len    .byte       ?
            .send            

            .section    kernel

extensions
        .text   "PRG", load_prg
        .text   "prg", load_prg
        .text   "PGX", load_pgx
        .text   "pgx", load_pgx
        .text   "PGZ", load_pgz
        .text   "pgz", load_pgz
        .byte   0

load
        stz     far_addr+0
        stz     far_addr+1

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
            jmp     dir

_setlfs     
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            ldy     #1      ; Use native load address
            jsr     SETLFS
            
          ; Load the data
            lda     #0      ; load, not verify
            jsr     LOAD
            bcs     _out

            jmp     find_sys
            
_out        rts

find_sys

          ; Copy the embedded load address to far_addr
            lda     src+0
            sta     far_addr+0
            lda     src+1
            sta     far_addr+1

          ; If the embedded address is not $801, it is the start addr.
            lda     src+0
            cmp     #<$801
            bne     _done

            lda     src+1
            cmp     #>$801
            bne     _done

          ; BASIC header; get far_addr from a SYS call.
            stz     far_addr+0
            stz     far_addr+1

          ; BASIC parser
            ldy     #0
_line       
          ; File ends when the would-be next address is zero.
            jsr     _fetch
            sta     tos_l       ; tmp
            jsr     _fetch
            ora     tos_l
            beq     _done

          ; Skip the line number
            jsr     _fetch
            jsr     _fetch          
            
          ; Scan the rest of the line
_loop       
            jsr     _fetch
            beq     _line
            bpl     _loop            
            cmp     #$9e    ; SYS
            bne     _loop
            
          ; SYS token found; skip any following spaces.
_spaces     jsr     _fetch
            ;beq     _done
            ;cmp     #' '
            ;beq     _spaces          

          ; atoi the following digits.
_digits     cmp     #'0'
            bcc     _done
            cmp     #'9'+1
            bcs     _done
            sec
            sbc     #'0'
            jsr     mul_add
            jsr     _fetch
            bra     _digits
                        
_fetch
            lda     (src),y
            iny
            bne     _fetched
            inc     src+1
_fetched
            ora     #0
            rts  
            
_done       
            clc
            rts

mul_add
          ; Multiply far_addr by 10.
            pha
            jsr     _copy
            jsr     _x2
            jsr     _x2
            jsr     _add
            jsr     _x2
            pla

          ; Add the decimal digit in A.
            sta     far_addr+2
            stz     far_addr+3
            jsr     _add

          ; Zero the upper bits
            stz     far_addr+2
            stz     far_addr+3
            rts            

_copy       
            lda     far_addr+0
            sta     far_addr+2
            lda     far_addr+1
            sta     far_addr+3
            rts
_x2
            lda     far_addr+0
            asl     a
            sta     far_addr+0
            lda     far_addr+1
            rol     a
            sta     far_addr+1
            rts            
_add        
            clc
            lda     far_addr+0
            adc     far_addr+2
            sta     far_addr+0
            lda     far_addr+1
            adc     far_addr+3
            sta     far_addr+1
            rts


load_pgx

    ; IN:   File name set using SETNAM
    ;
    ; OUT:  X/Y = end address, or carry set and A = iec error.

            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            ldy     #0      ; Not used
            jsr     SETLFS

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
            jsr     read_pgx_data
            bcc     _close
            
          ; Try to close the file while preserving the original error.
            pha
            jsr     kernel.iec.close_file
            pla
            sec
            bra     _error            
_close
            jsr     kernel.iec.close_file
            bcs     _error
            
_out        rts
_error      
            jsr     error
            clc
            bra     _out
    

read_pgx_data

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


load_pgz    ; TODO: share this code with pgx

    ; IN:   File name set using SETNAM
    ;
    ; OUT:  X/Y = end address, or carry set and A = iec error.

            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            ldy     #0      ; Not used
            jsr     SETLFS

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
            jsr     read_pgz_data
            bcc     _close
            
          ; Try to close the file while preserving the original error.
            pha
            jsr     kernel.iec.close_file
            pla
            sec
            bra     _error            
_close
            jsr     kernel.iec.close_file
            bcs     _error
            
_out        rts
_error      
            jsr     error
            clc
            bra     _out
    

read_pgz_data

  lda #2
  sta $1

    ; Internal funciton.
    ; Implements load-body for .pgz files.
    ;
    ; IN:   SETNAM and SETLFS have been called.
    ;
    ; Out:  X:Y = end address, far_addr = exec address
    ;       On error, Carry set, and A = IEC error (READST value)

            jsr     IECIN
            bcs     _error
            cmp     #'Z'
            beq    _pgz24
            cmp     #'z'
            beq     _pgz32
_mismatch   lda     #kernel.iec.MISMATCH
            sec            
            jmp     _error
            
_pgz24      lda     #3
            sta     addr_len
            bra     _read
            
_pgz32      lda     #4
            sta     addr_len
            bra     _read

_read
            ldx     #0
_zero       
            stz     far_addr,x
            stz     far_dest,x
            stz     far_count,x
            inx
            cpx     #4
            bne     _zero

_block
          ; Read the dest address.
            ldx     #0
            jsr     IECIN
            bcs     _end
            bra     _next
_dest       jsr     IECIN
            bcs     _error
_next       sta     far_dest,x
            inx
            cpx     addr_len
            bne     _dest

          ; Read the byte count into far_count
            ldx     #0
_count      jsr     IECIN
            bcs     _error
            sta     far_count,x
            inx
            cpx     addr_len
            bne     _count
         
          ; See if this is an empty block (start addr)
            jsr     test_far_count
            bne     _loop       ; Nope, read in the data
            
          ; Empty block implies the block address is the start address
            ldx     #0
_copy       lda     far_dest,x
            sta     far_addr,x
            inx
            cpx     addr_len
            bne     _copy            
            
            bra     _block

_loop       
            jsr     IECIN
            bcc     _found
            eor     #kernel.iec.EOI
            beq     _mismatch
_error      jmp     error   ; Forward the IEC error status.

_found
  ;ldx far_dest
  ;sta $c000,x
  sta $c000+79
            jsr     platform.far_store
            ldx     #far_dest
            jsr     far_inc
            jsr     dec_far_count
            jsr     test_far_count
            bne     _loop
            bra     _block
            
_end
            eor     #kernel.iec.EOI
            bne     _error
            clc
            rts


dec_far_count
            clc     ; Subtracting one.
            ldx     #0                        
_loop       lda     far_count,x
            sbc     #0
            sta     far_count,x
            bcs     _done
            inx
            cpx     #4
            bne     _loop
_done       clc
            rts            

test_far_count
            lda     far_count+0
            ora     far_count+1
            ora     far_count+2
            ora     far_count+3
            rts

            .send
            .endn
            .endn
            
