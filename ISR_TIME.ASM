; ISR_TIME.ASM - Mide el intervalo entre teclas con el contador de ticks 0040h:006Ch
; Compila: nasm -f bin ISR_TIME.ASM -o ISR_TIME.COM
; Desviaciones de la guia: solo se miden los make codes (el break de cada tecla
; daria un intervalo extra) y DS se conserva alrededor de LDS.

[BITS 16]
[ORG 0x100]

MAX_KEYS  EQU 5
BIT_BREAK EQU 80h
SEG_BIOS  EQU 40h
OFS_TICKS EQU 6Ch

start:
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    PUSH ES
    MOV  AX, SEG_BIOS
    MOV  ES, AX
    MOV  AX, [ES:OFS_TICKS]     ; palabra baja del contador
    MOV  [ticks_prev], AX
    POP  ES

    MOV  DX, mi_isr
    MOV  AX, 2509h
    INT  21h
    STI

.esperar:
    CMP  WORD [contador], MAX_KEYS
    JB   .esperar

    CLI
    PUSH DS
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AX, 4C00h
    INT  21h

mi_isr:
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH DS
    PUSH ES
    MOV  AX, CS
    MOV  DS, AX

    IN   AL, 60h
    MOV  DL, AL                 ; conservar el scancode

    MOV  AX, SEG_BIOS
    MOV  ES, AX
    MOV  AX, [ES:OFS_TICKS]

    MOV  BL, AL                 ; EOI tan pronto termina el trabajo de hardware
    MOV  AL, 20h
    OUT  20h, AL
    MOV  AL, BL

    TEST DL, BIT_BREAK
    JNZ  .salir                 ; tecla soltada: no se mide
    MOV  BX, AX
    SUB  BX, [ticks_prev]       ; ticks desde la tecla anterior
    MOV  [ticks_prev], AX

    MOV  AH, 09h
    MOV  DX, msg_ticks
    INT  21h
    MOV  AX, BX
    CALL imprimir_decimal
    INC  WORD [contador]

.salir:
    POP  ES
    POP  DS
    POP  DX
    POP  BX
    POP  AX
    IRET

imprimir_decimal:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    XOR  CX, CX
.divide:
    XOR  DX, DX
    DIV  BX
    PUSH DX
    INC  CX
    TEST AX, AX
    JNZ  .divide
.imprimir:
    POP  DX
    ADD  DL, '0'
    MOV  AH, 02h
    INT  21h
    LOOP .imprimir
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

old_isr    DD 0
ticks_prev DW 0
contador   DW 0
msg_ticks  DB 0Dh, 0Ah, "Ticks desde la interrupcion anterior: $"
msg_fin    DB 0Dh, 0Ah, "ISR_TIME restaurado. Fin del programa.", 0Dh, 0Ah, "$"
