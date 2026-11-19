; TECL.ASM - Lectura de un scancode del 8042 por polling
; Compila: nasm -f bin TECL.ASM -o TECL.COM
; Desviacion de la guia: el sondeo corre con IF = 0 (CLI). Con interrupciones
; habilitadas el manejador de IRQ1 del BIOS lee el puerto 60h antes que el bucle
; y el programa no llega a ver OBF = 1. Se ignoran los break codes (bit 7 = 1):
; el primero que llega es el de la tecla Enter que lanzo el programa (9Ch).
; Al final se vacia el buffer del BIOS.

[BITS 16]
[ORG 0x100]

PUERTO_DATOS  EQU 60h
PUERTO_ESTADO EQU 64h
BIT_OBF       EQU 01h
BIT_BREAK     EQU 80h

start:
    CLI                         ; el BIOS no debe consumir el byte
.poll:
    IN   AL, PUERTO_ESTADO      ; registro de estado del 8042
    TEST AL, BIT_OBF            ; bit 0: Output Buffer Full
    JZ   .poll                  ; OBF = 0: no hay dato
    IN   AL, PUERTO_DATOS       ; scancode de la tecla
    TEST AL, BIT_BREAK
    JNZ  .poll                  ; codigo de liberacion (break): se ignora
    STI
    MOV  BL, AL

    MOV  AH, 09h
    MOV  DX, msg
    INT  21h
    MOV  AL, BL
    CALL hex8
    MOV  AH, 09h
    MOV  DX, crlf
    INT  21h

    CALL vaciar
    MOV  AX, 4C00h
    INT  21h

; hex8: imprime AL en dos digitos hexadecimales
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

; vaciar: descarta las teclas que el BIOS haya guardado
vaciar:
    MOV  AH, 01h
    INT  16h
    JZ   .fin
    MOV  AH, 00h
    INT  16h
    JMP  vaciar
.fin:
    RET

msg  DB 'Scancode leido del puerto 60h: $'
crlf DB 0Dh, 0Ah, '$'
