; LPTSEND.ASM - Envio de un caracter al puerto paralelo LPT1 (protocolo Centronics)
; Compila: nasm -f bin LPTSEND.ASM -o LPTSEND.COM
; Desviaciones de la guia: LPT1 es un nombre de dispositivo reservado en DOS y en
; Windows, asi que LPT1.ASM no puede existir como archivo; se llama LPTSEND.ASM.
; Los puertos 0378h a 037Ah pasan por DX porque IN AL, imm8 solo llega a 0FFh;
; con IN AL, 0379h NASM trunca el operando y lee el puerto 79h. El programa imprime el estado leido de 0379h antes y
; despues del pulso STROBE para documentar el comportamiento de DOSBox.

[BITS 16]
[ORG 0x100]

DATA_PORT   EQU 0378h
STATUS_PORT EQU 0379h
CTRL_PORT   EQU 037Ah
BIT_BUSY_N  EQU 80h             ; bit 7: BUSY# (0 = ocupada)
CARACTER    EQU 41h             ; 'A'

start:
    MOV  DX, STATUS_PORT
    IN   AL, DX
    MOV  [estado1], AL
.wait_ready:
    IN   AL, DX
    TEST AL, BIT_BUSY_N
    JZ   .wait_ready            ; impresora ocupada

    MOV  DX, DATA_PORT
    MOV  AL, CARACTER
    OUT  DX, AL                 ; dato en D0-D7

    MOV  DX, CTRL_PORT
    IN   AL, DX
    AND  AL, 0FEh               ; STROBE activo (bit 0 en 0)
    OUT  DX, AL
    MOV  CX, 0Fh
.delay:
    LOOP .delay
    OR   AL, 01h                ; STROBE inactivo
    OUT  DX, AL

    MOV  DX, STATUS_PORT
    IN   AL, DX
    MOV  [estado2], AL

    MOV  AH, 09h
    MOV  DX, msg1
    INT  21h
    MOV  AL, [estado1]
    CALL hex8
    MOV  AH, 09h
    MOV  DX, msg2
    INT  21h
    MOV  AL, [estado2]
    CALL hex8
    MOV  AH, 09h
    MOV  DX, msg3
    INT  21h

    MOV  AX, 4C00h
    INT  21h

hex8:
    PUSH AX
    MOV  DL, AL
    SHR  DL, 4
    CALL nibble
    POP  AX
    MOV  DL, AL
    AND  DL, 0Fh
nibble:
    ADD  DL, '0'
    CMP  DL, '9'
    JBE  .ok
    ADD  DL, 7
.ok:
    MOV  AH, 02h
    INT  21h
    RET

estado1 DB 0
estado2 DB 0
msg1 DB "Caracter 'A' enviado a LPT1. Estado 0379h antes: $"
msg2 DB "h  despues: $"
msg3 DB "h", 0Dh, 0Ah, "$"
