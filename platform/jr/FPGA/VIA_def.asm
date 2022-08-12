;;;
;;; Register Address Definitions for the W65C22S
;;;
VIA_ORB_IRB     = $DC00 ;Output/Input Register Port B
VIA_ORA_IRA     = $DC01 ;Output/Input Register Port B
VIA_DDRB        = $DC02 ;Data Direction Port B
VIA_DDRA        = $DC03 ;Data Direction Port A
VIA_T1CL        = $DC04 ;T1C-L
VIA_T1CH        = $DC05 ;T1C-H
VIA_T1LL        = $DC06 ;T1L-L
VIA_T1LH        = $DC07 ;T1L-H
VIA_T2CL        = $DC08 ;T2C-L
VIA_T2CH        = $DC09 ;T2C-H
VIA_SR          = $DC0A ;SR
VIA_ACR         = $DC0B ;ACR
VIA_PCR         = $DC0C ;PCR
VIA_IFR         = $DC0D ;IFR
VIA_IER         = $DC0E ;IER
VIA_ORA_IRA_AUX = $DC0F ;ORA/IRA
; Definition for where the Joystick Ports are
; Port A (Joystick Port 1)
JOYA_UP         = $01
JOYA_DWN        = $02
JOYA_LFT        = $04
JOTA_RGT        = $08
JOTA_BUT0       = $10
JOYA_BUT1       = $20
JOYA_BUT2       = $40
; Port B (Joystick Port 0)
JOYB_UP         = $01
JOYB_DWN        = $02
JOYB_LFT        = $04
JOTB_RGT        = $08
JOTB_BUT0       = $10
JOYB_BUT1       = $20
JOYB_BUT2       = $40