        .cpu    "6502"

boot    .namespace

ORG     = $2000

*       =   ORG - 8*2 - 1 ; start, minus 2 blocks, minus signature byte.

; Siganture
        .text   "z"     ; 32-bit

; Start block
        .word   start, 0    ; address
        .word   0,0         ; length
        
; Code block
        .word   ORG, 0      ; address
        .word   end-ORG,0   ; length

        .dsection   code
end        

        .endn        
        
