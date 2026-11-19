; MULTI_ST.ASM - Polling combinado de dos puertos de estado (teclado + LPT1)
; Compila: nasm -f bin MULTI_ST.ASM -o MULTI_ST.COM

[BITS 16]
[ORG 0x100]

STATUS_PORT EQU 0379h

start:
.poll:
    IN   AL, 64h                ; bandera de teclado: bit 0 (OBF)
    AND  AL, 01h
    MOV  BL, AL                 ; BL = 0 o 1

    MOV  DX, STATUS_PORT        ; bandera de LPT1: bit 7 (BUSY#)
    IN   AL, DX
    AND  AL, 80h
    MOV  CL, 7
    SHR  AL, CL                 ; normaliza a 0 o 1
    MOV  BH, AL                 ; BH = 0 o 1

    MOV  AL, BL
    OR   AL, BH                 ; alguno listo?
    JZ   .poll

    TEST BL, BL                 ; examinar cada bandera por separado
    JZ   .lpt
    MOV  AH, 09h
    MOV  DX, msg_tecl
    INT  21h
.lpt:
    TEST BH, BH
    JZ   .fin
    MOV  AH, 09h
    MOV  DX, msg_lpt1
    INT  21h
.fin:
    MOV  AX, 4C00h
    INT  21h

msg_tecl DB "Teclado listo (OBF=1).", 0Dh, 0Ah, "$"
msg_lpt1 DB "LPT1 listo (BUSY#=1).", 0Dh, 0Ah, "$"
