; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
iec         .namespace            

            .section    dp
queue       .byte       ?   ; queue to detect when to signal end-of-data
queued      .byte       ?   ; negative if a byte is in the queue
status      .byte       ?   ; IEC status
            .send
            
            .section    kernel
            
TIMEOUT_WRITE   =     1
TIMEOUT_READ    =     2
MISMATCH        =    16
EOI             =    64
NO_DEVICE       =   128

readst
            lda     status
            rts

error

    ; Internal function.  
    ; Updates io.status with the bits set in A.  
    ; Does not change the state of the carry.
    
            ora     status
            sta     status
            rts                  

iecin
            jsr     platform.iec.read_byte
            bcs     error
            rts

iecout
queue_data

    ; Delays writes of data bytes to the IEC bus by one character.
    ; This enables the stack to automatically determine when to
    ; signal that this is the last data byte in its sequence.
    ; On error, sets carry and returns the READST value in A.
    
            bit     queued
            bmi     _swap
            sta     queue
            dec     queued
            rts
_swap
            pha
            lda     queue
            jsr     platform.iec.write_byte
            pla
            bcs     error
            sta     queue
_out        rts


flush_queue

    ; Internal function
    ; If there is a byte remaining in the queue, send it
    ; using the IEC "last byte" protocol.
    ; On error, sets carry and returns the READST value in A.

            bit     queued
            bpl     _done
            lda     queue
            jsr     platform.iec.write_last_byte
            bcs     error
            stz     queued
_done       rts            


reset

    ; Internal function.
    ; Clears the write queue and the READST value.
    
            stz     status
            stz     queued
            rts

check_dev

    ; Internal function.  
    ; Ensures that the device number in A is valid for the IEC
    ; bus.  Sets the carry and returns A=#NO_DEVICE on error.
    
            cmp     #16
            bcc     _out
            lda     #NO_DEVICE
_out        rts

settmo      
    ; Implemented by platform; repeated here for consistency.
    
            jmp     platform.iec.settmo

talk

    ; IN: A = device (8..15)
    ; NOTE: The iec routines don't appear to return any status;
    ;       instead, users are expected to call READST after
    ;       each invocation.  In this particular implementation,
    ;       carry will be set, and A will contain the value to
    ;       be returned by READST.
    
            jsr     check_dev
            bcs     _error
            ora     #$40
            jsr     platform.iec.send_atn_byte
            bcs     _error
            rts
_error      jmp     error

            
untalk

    ; NOTE: The iec routines don't appear to return any status;
    ;       instead, users are expected to call READST after
    ;       each invocation.  In this particular implementation,
    ;       carry will be set, and A will contain the value to
    ;       be returned by READST.
    
            jsr     flush_queue
            bcs     _error
            lda     #$5f
            jsr     platform.iec.send_atn_last_byte
            bcs     _error
            rts
_error      jmp     error

listen

    ; IN: A = device (8..15)
    ; NOTE: The iec routines don't appear to return any status;
    ;       instead, users are expected to call READST after
    ;       each invocation.  In this particular implementation,
    ;       carry will be set, and A will contain the value to
    ;       be returned by READST.
    
            jsr     check_dev
            bcs     _error
            ora     #$20
            jsr     platform.iec.send_atn_byte
            bcs     _error
            rts
_error      jmp     error


unlstn

    ; NOTE: The iec routines don't appear to return any status;
    ;       instead, users are expected to call READST after
    ;       each invocation.  In this particular implementation,
    ;       carry will be set, and A will contain the value to
    ;       be returned by READST.
    
            jsr     flush_queue
            bcs     _error
            lda     #$3f
            jsr     platform.iec.send_atn_last_byte
            bcs     _error
            rts
_error      jmp     error

talksa
lstnsa

    ; IN: A = device (8..15)
    ; NOTE: The iec routines don't appear to return any status;
    ;       instead, users are expected to call READST after
    ;       each invocation.  In this particular implementation,
    ;       carry will be set, and A will contain the value to
    ;       be returned by READST.
    ;
    ; These two routines are nominally separate to hint the kernel
    ; about what the bus is expected to do.  On the C256 Jr., the
    ; state machine in the FPGA automatically handles both cases.

            jsr     check_dev
            bcs     _error
            ora     #$60
            jsr     platform.iec.send_atn_byte
            bcs     _error
            rts
_error      jmp     error



load

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
            jsr     reset

          ; Open the file for read.  
          ; NOTE: returns a KERNAL error; must check READST as well!
            jsr     open_file_for_read
            bcs     _out
            jsr     READST
            ora     #0
            bne     _error
            
          ; Read the file, sets X/Y to last address.
            jsr     read_verify_pgm_data
            bcs     _error
            
            jsr     close_file
            bcs     _error
            
_out        rts
_error      
            jsr     error
            clc
            bra     _out
    

save
    sec
    rts

open_file_for_read

    ; Internal function.
    ;
    ; IN:   Device and sub set using SETLFS
    ;       File name set using SETNAM
    ;
    ; OUT:  Carry set and A = a KERNEL error
    ;       (MISSING_FILE_NAME) on error.
    ;
    ; NOTE: On IEC error, Sets READST and CLEARS the carry.

            lda     fname_len
            bne     _open
            lda     #MISSING_FILE_NAME
            sec
            rts
            
_open
            lda     cur_device
            jsr     LISTEN
            bcs     _error
            
            lda     #$f0        ; Open channel 0
            jsr     platform.iec.send_atn_byte
            bcs     _error
            
            jsr     send_fname
            bcs     _error

            jsr     UNLSTN
            bcs     _error
            
            lda     cur_device
            jsr     TALK
            bcs     _error
            
            lda     #0          ; Channel 0; Channel 1 magic is internal.
            jsr     TALKSA      ; Reopen channel; tells drive to send.
            bcs     _error
            
            rts

_error      
          ; Not a KERNEL error; must call READST for more information.
            clc
            rts


send_fname

    ; Internal function
    ; Writes the filename (from SETFN) via the IECOUT.
    ; Returns the IEC error status.
    
            phy
            ldy     #0
_loop
            lda     (fname),y
            jsr     to_upper
            jsr     IECOUT
            bcs     _out
            iny
            cpy     fname_len
            bcc     _loop
            clc
_out
            ply
            rts

to_upper
        cmp     #'a'
        bcc     _okay
        cmp     #'z'+1
        bcs     _okay
        eor     #$20
_okay   clc
        rts        

close_file

    ; Internal function
    ; Closes the current reading or writing file.
    ; Returns the IEC error status.
    
            jsr     UNTALK
            bcs     _out
            
            lda     cur_device
            jsr     LISTEN
            bcs     _out
            
            lda     #$e0        ; Close channel 0
            jsr     platform.iec.send_atn_byte
            bcs     _out
                        
            jsr     UNLSTN
            bcs     _out
            
_out        rts
            

read_verify_pgm_data

    ; Internal funciton.
    ; Implements READ/VERIFY for PGM files.
    ;
    ; IN:   Y=0 (load to dest) or Y=1 (load to embedded address)
    ;       X=0 (read) or 1..255 (verify)
    ;
    ; Out:  X:Y = last address read/verified
    ;       On error, Carry set, and A = IEC error (READST value)

 
          ; X = 0/2 read/verify
            tax
            beq     _emode  ; read
            ldx     #2      ; verify
_emode      nop            

          ; Read the would-be load-address into src
            jsr     platform.iec.read_byte
            bcs     _error
            sta     src+0
            jsr     platform.iec.read_byte
            bcs     _error
            sta     src+1

          ; Update dest ptr if the sub-channel (Y) is 1
            tya
            beq     _edest
            lda     src+0
            sta     dest+0
            lda     src+1
            sta     dest+1
_edest      nop

_loop       
            jsr     platform.iec.read_byte
            bcc     _found
            cmp     #EOI
            beq     _done
_error      jmp     error   ; Forward the IEC error status.

_found      jmp     (_op,x)
_cont
            inc     dest
            bne     _next
            inc     dest+1
_next       
            bcc     _loop
_done       clc
_out            
            ldx     dest+0
            ldy     dest+1
            rts          
_op  
            .word   _load
            .word   _verify
_load
            sta     (dest)
            bra     _cont
_verify
            cmp     (dest)
            beq     _cont
            lda     #MISMATCH
            sec
            jsr     _error
            bra     _out    ; Mismatch still returns X/Y.

            .send
            .endn
            .endn
