        .cpu    "6502"

boot    .namespace
ADDR    = $2000

*   = ADDR - 8
        .text   "PGX", 0    ; Signature
        .word   ADDR, $0    ; Load address (start it where BASIC would start it :).
        jmp    start

        .dsection   code

        .endn        
        
