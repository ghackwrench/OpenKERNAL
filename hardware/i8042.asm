            .cpu        "w65c02"

            .namespace  hardware

i8042       .macro      BASE = $D640

BASE = \BASE

self        .namespace
            .virtual    DevState
queue       .word       ?       ; write queue, must be first
qstate      .word       ?       ; atomic queue count for irq management
lower       .byte       ?       ; Lower handler
config      .byte       ?       ; Current i8042 config
last        .byte       ?       ; tick at time of last data write
mask        .byte       ?       ; bit to check for ready status
mark        .byte       ?       ; ticks at start of status wait loop
pending     .byte       ?       ; true if 'data' contains pending data.
data        .byte       ?       ; delayed write while waiting for the i8042.
            .endv
            .endn            

CMD     =   4
DATA    =   0
STATUS  =   4

vectors     .kernel.device.mkdev    ps2

init
            jsr     kernel.device.alloc
            bcs     _out
            jsr     ps2_init
            bcc     _out
            jsr     kernel.device.free
            sec
_out        rts            

ps2_init 
        ; 0. Disable IRQs
            lda     #irq.ps2_0
            jsr     irq.disable
            lda     #irq.ps2_1
            jsr     irq.disable
            
        ; 1. Init the USB controllers (N/A)
        ; 2. Determine if the i8042 exists (N/A)
          
        ; 3. Disable the ports

          ; Dispable the first port 
            lda     #$ac
            jsr     send_cmd

          ; Disable the second port
            lda     #$a7
            jsr     send_cmd

        ; 4. Flush the recv queueu
            jsr     flush
            bcs     _out

        ; 5. Configure the controller
            jsr     _configure
            bcs     _out        


        ; 6. Test the controller
            lda     #$aa
            jsr     txrx
            bcs     _out
            cmp     #$55
            sec
            bne     _out
            jsr     _configure
            bcs     _out

        ; 7. Enable port 2 and recheck bit 5 (N/A)
        
        ; 8. Test the ports (meh)
        
        ; 9. Set the post bit
            lda     self.config,x
            ora     #4
            jsr     send_conf
            bcs     _out
_vectors
            lda     #<vectors
            sta     kernel.src
            lda     #>vectors
            sta     kernel.src+1
            jsr     kernel.device.install

_out        rts

_configure
            lda     #$20        ; CmdGetConfig
            jsr     txrx
            bcs     _out
            and     #255-1-2-64
            and     #$0f
            jmp     send_conf

send_conf  
            pha
            lda     #$60        ; CmdSetConfig
            jsr     send_cmd
            pla
            bcs     _end
            jsr     send_data
            bcs     _end
            sta     self.config,b,x
_end        rts


send_cmd:
            jsr     tx_wait
            bcs     _out
            sta     BASE+CMD
_out        rts

send_data:
            jsr     tx_wait
            bcs     _out
            sta     BASE+DATA
_out        rts

flush       ldy     #100            ; Max bytes to eat.
_flush      jsr     recv_data
            bcs     _flushed
            dey
            bne     _flush
            sec
            rts
_flushed    clc
            rts

txrx:
            jsr     send_cmd
            bcc     recv_data
            rts

recv_data:
            jsr     rx_wait
            bcs     _out
            lda     BASE+DATA
_out        rts
            
rx_wait:
            lda     #1
            bra     wait

tx_wait:
            pha
            lda     #2
            jsr     wait
            pla
            rts

wait:
    ; IN:   A = bit to wait on
    ; OUT:  Carry set on timeout
    
            sta     self.mask,x
            lda     kernel.ticks
            sta     self.mark,x
            
            clc
_loop       lda     BASE+STATUS
            eor     #2              ; normalize
            and     self.mask,x
            beq     _wait
_out        rts
            
_wait       lda     kernel.ticks
            sec
            sbc     self.mark,x
            cmp     #30
            bcs     _out
            jsr     kernel.thread.yield
            bra     _loop            
          
hang
        #spin 82
        bra hang  

TIMER0_CTRL_REG = $d650+$0
TIMER0_CHARGE_L = $d650+$1
TIMER0_CHARGE_M = $d650+$2
TIMER0_CHARGE_H = $d650+$3
TIMER0_CMP_REG  = $d650+$4
TIMER0_CMP_L    = $d650+$5
TIMER0_CMP_M    = $d650+$6
TIMER0_CMP_H    = $d650+$7

TMR0_EN     = $01
TMR0_SCLR   = $02
TMR0_SLOAD  = $04 ; Use SLOAD is
TMR0_UPDWN  = $08
      
TMR0_CMP_RECLR     = $01 ; set to one for it to cycle when Counting up
TMR0_CMP_RELOAD    = $02 ; Set to one for it to reload when Counting Down
  
            .virtual Tokens
port        .byte   ?
data        .byte   ?
            .endv


ps2_open

        jsr     kernel.device.queue.init
        stz     self.pending,x

        lda     #$ff
        sta     self.qstate,x   ; qstate == 0 when count is 1.

        txa
        ldy     #irq.timer0
        jsr     irq.install

        lda     #$a8
        sta     TIMER0_CMP_L
        lda     #$61
        sta     TIMER0_CMP_M
        lda     #$0
        sta     TIMER0_CMP_H

        stz     TIMER0_CHARGE_L
        stz     TIMER0_CHARGE_M
        stz     TIMER0_CHARGE_H

        lda     #TMR0_CMP_RELOAD
        sta     TIMER0_CMP_REG
        
        lda     #100
        sta     VKY_LINE_CMP_VALUE_LO
        stz     VKY_LINE_CMP_VALUE_HI
        lda     #1
        sta     VKY_LINE_IRQ_CTRL_REG

        lda     #irq.timer0
        jsr     irq.enable

        clc
        rts


ps2_send
    ; Asynchronously send the byte in A to the device at port Y.
    ; A = byte, Y = port
    ; Carry set on error (no free tokens)
            phy

            jsr     kernel.token.alloc
            bcc     _queue
            ply
            rts

_queue 
            sta     data,y
            pla
            sta     port,y
                   
            jsr     kernel.device.queue.enque
            inc     self.qstate,x
            bne     _ack
            jsr     timer_resume

_ack
            #spin   $10
            clc
            rts


timer_resume
        lda     #TMR0_EN | TMR0_SLOAD | TMR0_UPDWN
        sta     TIMER0_CTRL_REG
        #spin   81
        rts

ps2_data
    ; IRQ handler for asynchronously sending bytes to PS2 devices.

      ; Verify that the i8042 can accept writes
        lda     BASE+STATUS
        bit     #2
        bne     _wait

      ; If we have pending data, send it now.
        lda     self.data,x
        ldy     self.pending,x
        bne     _send

        jsr     kernel.device.queue.deque
        bcs     _done
        dec     self.qstate,x

        lda     port,y
        bne     _prefix

        lda     data,y
        jsr     kernel.token.free 

_send   sta     BASE+DATA
        stz     self.pending,x
        #spin   $11

_wait   jsr     timer_resume
_done   rts

_prefix
        
      ; Send the prefix command for a write to the second port
        lda     #$d4
        sta     BASE+CMD
        
      ; Flag pending
        sta     self.pending,x  ; force pending to non-zero (ie #$d4)

      ; Queue the data byte
        lda     data,y
        sta     self.data,x
        jsr     kernel.token.free

        bra     _wait           ; The i8042 core lies...
        bra     ps2_data        ; Try to send straight away (queuing i8042)
        
ps2_close
        lda     #irq.timer0
        jsr     irq.disable
        rts

ps2_get
        lda     BASE+DATA
        clc
        rts

ps2_set
    ; Enable (/disable) the port
    ; Y = port #

      ; Enable the interrupt on the i8042
        lda     _irq,y
        ora     self.config,x
        jsr     send_conf
        bcs     _out
        
      ; Enable the port
        lda     _port,y
        jsr     send_cmd
        bcs     _out

_out    rts

_irq    .byte   $01, $02
_port   .byte   $ae, $a8
        

ps2_status
ps2_fetch
            clc
            rts

            .endm
            .endn

