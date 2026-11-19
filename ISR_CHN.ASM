; ISR_CHN.ASM - ISR encadenado para IRQ1: cuenta teclas y llama al manejador original
; Compila: nasm -f bin ISR_CHN.ASM -o ISR_CHN.COM
; Desviacion de la guia: el archivo se llama ISR_CHN porque DOS solo admite
; nombres de 8 caracteres (ISR_CHAIN se truncaria a ISR_CH~1). El programa lee
; 5 teclas con INT 21h/01h (eco de DOS) mientras el ISR propio las cuenta.

[BITS 16]
[ORG 0x100]

MAX_KEYS  EQU 5
BIT_BREAK EQU 80h

start:
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES
    MOV  DX, mi_isr_chain
    MOV  AX, 2509h
    INT  21h

    MOV  AH, 09h
    MOV  DX, msg_ini
    INT  21h
    MOV  CX, MAX_KEYS
.leer:
    MOV  AH, 01h                ; DOS lee la tecla y hace eco
    INT  21h
    LOOP .leer

    PUSH DS
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    POP  DS

    MOV  AH, 09h
    MOV  DX, msg_cnt
    INT  21h
    MOV  AX, [contador]
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h
    MOV  AH, 09h
    MOV  DX, crlf
    INT  21h
    MOV  AX, 4C00h
    INT  21h

; ---- ISR encadenado: no envia EOI; eso lo hace el manejador original ----
mi_isr_chain:
    PUSH AX
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    IN   AL, 60h                ; solo observa el scancode
    TEST AL, BIT_BREAK
    JNZ  .seguir
    INC  WORD [contador]
.seguir:
    POP  DS
    POP  AX
    PUSHF                       ; simula INT: FLAGS + CS:IP en la pila
    CALL FAR [cs:old_isr]       ; el BIOS lee 60h, guarda la tecla y envia EOI
    IRET

contador DW 0
old_isr  DD 0
msg_ini  DB "Escriba 5 teclas (DOS hace el eco): $"
msg_cnt  DB 0Dh, 0Ah, "Teclas contadas por el ISR propio: $"
crlf     DB 0Dh, 0Ah, "$"
