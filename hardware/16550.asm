            .cpu    "65816"  ; for testing, should be 65c02

            .namespace  hardware
           
        
u16550      .macro  MINOR=0, BASE=$10000, DIVISORS=0, IRQ=0, THREE=0

dev         .struct

; Common
open        .word   ?
close       .word   ?

; Lower interface
rx_en       .word   ?
tx_en       .word   ?

; Upper interface
irq         .word   ?

data:
lower       .byte   ?   ; Device offset of lower handler
modem       .byte   ?   ; Modem line status bits
lines       .byte   ?   ; ORed in line status bits
fifo        .byte   ?   ; # of remaining tx fifo slots

size        .ends

        .virtual    Drivers
Dev     .dstruct    dev
        .endv

        .section    kernel

init    ; should be first, so the dev handle is the init address.

        lda     #dev.size
        jsr     kernel.driver_alloc
        bcs     _out

        jsr     get_flow
        sta     Dev.lines,x

        phx
        ldy     #0
_loop   lda     _table,y
        sta     Drivers,x
        inx
        iny
        cpy     #dev.data
        bne     _loop
        
        clc
_out    rts


_table  
      ; Common
        .word   uart_open
        .word   uart_close

      ; Lower
        .word   uart_rx_en
        .word   uart_tx_en

      ; Upper
        .word   uart_irq

get_flow
        lda     #\THREE
        beq     _done
        lda     #MSR_CD | MSR_DSR | MSR_CTS
_done   sta     Dev.lines
        rts

uart_open:
    ; should param lower handler
    ; X->UART, a->lower, y->bps

        sta     Dev.lower,x

        jsr     \DIVISORS
        bcs     _out
        
      ; Open the divisor latch.
        lda     #LCR_8N1 | LCR_DLB
        sta     \BASE + UART_LCR
        
      ; Set the BPS
        lda     0,y
        sta     \BASE + UART_DLL
        lda     1,y
        sta     \BASE + UART_DLH
        
      ; Clear DLB bit; 8N1.
        lda     #LCR_8N1
        sta     \BASE + UART_LCR
        
      ; Initialize the FIFOs.
        lda     #FCR_FIFO_ENABLE | FCR_CLEAR_RX | FCR_CLEAR_TX | FCR_RX_FIFO_8
        sta     \BASE + UART_FCR

        ; Make sure the EIR is exposed.
        lda     #LCR_8N1
        sta     \BASE + UART_LCR
        
        ; Raise DTR and RTR, enable interrupts.
        lda     #MCR_DTR | MCR_RTS | MCR_OUT2
        sta     \BASE + UART_MCR

        ; Grab and forward a modem-status baseline.
        txa
        tay
        jsr     send_status

        ; Initialize interrupts (and clean up UART state).
        lda     #UINT_DATA_AVAIL | UINT_MODEM_STATUS | UINT_LINE_STATUS
        sta     \BASE + UART_IER

.if false
    ; Enable the hardware interrupt.
        lda     #uart_irq
        ldy     #\IRQ
        sta     0,b,y
        tya
    	jsr     irq.enable
.endif

_out    rts

send_status:
        lda     \BASE + UART_MSR
        ora     Dev.lines,y
        sta     Dev.modem,y

        ldx     Dev.lower,y
        jmp     (hardware.driver.upper.serial.status,x)


uart_close
        
uart_rx_en:
        php
        sei
        lda     \BASE + UART_MCR
        ora     #MCR_RTS
        sta     \BASE + UART_MCR
        plp
        rts

uart_tx_en:
        php
        sei
        lda     \BASE + UART_IER
        ora     #UINT_THR_EMPTY
        sta     \BASE + UART_IER
        plp
        rts

uart_irq
        txa
        tay
uart_loop
        lda     \BASE + UART_IIR
        bit     #1
        bne     _done   ; Spurious interrupt.
        and     #6
        tax
        jmp     (_table,x)
_done   lda     \BASE + UART_LSR    ; May also need to dispatch the LSR itself.
        bit     #1
        bne     uart_rx
        rts

_table  .word   uart_lines
        .word   uart_tx
        .word   uart_rx
        .word   uart_err


uart_lines
        jsr     send_status
        bra     uart_loop

uart_rx     
        lda     \BASE + UART_TRHB
        ldx     Dev.lower,y
        jsr     (hardware.driver.upper.serial.rx,x)
        bcc     uart_loop

      ; Lower layer has requested a pause
      
        lda     \BASE + UART_MCR
        and     #+~MCR_RTS
        sta     \BASE + UART_MCR
        bra     uart_loop

uart_err
        lda     \BASE + UART_LSR    ; Clears the uart error state.
        ldx     Dev.lower,y
        jsr     (hardware.driver.upper.serial.error,x)
        bra     uart_irq
        
uart_tx
        lda     #16             ; FIFO length
        sta     Dev.fifo,y
_cont   ldx     Dev.lower,y
        jsr     (hardware.driver.upper.serial.tx,x)
        bcs     _tx_off
        sta     \BASE + UART_TRHB
        lda     Dev.fifo,y
        dec     a
        sta     Dev.fifo,y
        bne     _cont
        jmp     uart_loop

_tx_off lda     \BASE + UART_IER
        and     #~UINT_THR_EMPTY
        sta     \BASE + UART_IER
        jmp     uart_loop


; Register Offsets
UART_TRHB   = $00           ; Transmit/Receive Hold Buffer
UART_DLL    = $00           ; Divisor Latch Low Byte
UART_DLH    = $01           ; Divisor Latch High Byte
UART_IER    = $01           ; Interupt Enable Register
UART_FCR    = $02           ; FIFO Control Register
UART_IIR    = $02           ; Interupt Indentification Register
UART_LCR    = $03           ; Line Control Register
UART_MCR    = $04           ; Modem Control REgister
UART_LSR    = $05           ; Line Status Register
UART_MSR    = $06           ; Modem Status Register
UART_SR     = $07           ; Scratch Register

; Interupt Enable Flags
UINT_LOW_POWER = $20        ; Enable Low Power Mode (16750)
UINT_SLEEP_MODE = $10       ; Enable Sleep Mode (16750)
UINT_MODEM_STATUS = $08     ; Enable Modem Status Interrupt
UINT_LINE_STATUS = $04      ; Enable Receiver Line Status Interupt
UINT_THR_EMPTY = $02        ; Enable Transmit Holding Register Empty interrupt
UINT_DATA_AVAIL = $01       ; Enable Recieve Data Available interupt   

; Interrupt Identification Register Codes
IIR_FIFO_ENABLED = $80      ; FIFO is enabled
IIR_FIFO_NONFUNC = $40      ; FIFO is not functioning
IIR_FIFO_64BYTE = $20       ; 64 byte FIFO enabled (16750)
IIR_MODEM_STATUS = $00      ; Modem Status Interrupt
IIR_THR_EMPTY = $02         ; Transmit Holding Register Empty Interrupt
IIR_DATA_AVAIL = $04        ; Data Available Interrupt
IIR_LINE_STATUS = $06       ; Line Status Interrupt
IIR_TIMEOUT = $0C           ; Time-out Interrupt (16550 and later)
IIR_INTERRUPT_PENDING = $01 ; Interrupt Pending Flag

; Line Control Register Codes
LCR_DLB = $80               ; Divisor Latch Access Bit
LCR_SBE = $60               ; Set Break Enable

LCR_PARITY_NONE = $00       ; Parity: None
LCR_PARITY_ODD = $08        ; Parity: Odd
LCR_PARITY_EVEN = $18       ; Parity: Even
LCR_PARITY_MARK = $28       ; Parity: Mark
LCR_PARITY_SPACE = $38      ; Parity: Space

LCR_STOPBIT_1 = $00         ; One Stop Bit
LCR_STOPBIT_2 = $04         ; 1.5 or 2 Stop Bits

LCR_DATABITS_5 = $00        ; Data Bits: 5
LCR_DATABITS_6 = $01        ; Data Bits: 6
LCR_DATABITS_7 = $02        ; Data Bits: 7
LCR_DATABITS_8 = $03        ; Data Bits: 8

LCR_8N1 = LCR_DATABITS_8 | LCR_PARITY_NONE | LCR_STOPBIT_1

LSR_ERR_RECIEVE = $80       ; Error in Received FIFO
LSR_XMIT_DONE = $40         ; All data has been transmitted
LSR_XMIT_EMPTY = $20        ; Empty transmit holding register
LSR_BREAK_INT = $10         ; Break interrupt
LSR_ERR_FRAME = $08         ; Framing error
LSR_ERR_PARITY = $04        ; Parity error
LSR_ERR_OVERRUN = $02       ; Overrun error
LSR_DATA_AVAIL = $01        ; Data is ready in the receive buffer

MCR_DTR =   1
MCR_RTS =   2
MCR_OUT1 =  4
MCR_OUT2 =  8
MCR_TEST = 16

FCR_FIFO_ENABLE = 1
FCR_CLEAR_RX    = 2
FCR_CLEAR_TX    = 4
FCR_RX_FIFO_1   = 0
FCR_RX_FIFO_4   = 64
FCR_RX_FIFO_8   = 128
FCR_RX_FIFO_14  = 192  ; Total is 16, so this is pushing things.

MSR_DCTS    =   1
MSR_DDSR    =   2
MSR_NRI     =   4
MSR_DCD     =   8
MSR_CTS     =  16
MSR_DSR     =  32
MSR_RI      =  64
MSR_CD      = 128

UART_300 = 384              ; Code for 300 bps
UART_1200 = 96              ; Code for 1200 bps
UART_2400 = 48              ; Code for 2400 bps
UART_4800 = 24              ; Code for 4800 bps
UART_9600 = 12              ; Code for 9600 bps
UART_19200 = 6              ; Code for 19200 bps
UART_38400 = 3              ; Code for 28400 bps
UART_57600 = 2              ; Code for 57600 bps
UART_115200 = 1             ; Code for 115200 bps

UART_DCTS   =   1
UART_DDSR   =   2
UART_TERI   =   4
UART_DDCD   =   8
UART_CTS    =  16
UART_DSR    =  32
UART_RI     =  64
UART_DCD    = 128

        .send
        .endm
        .endn
