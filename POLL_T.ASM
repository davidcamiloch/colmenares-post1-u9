; POLL_T.ASM - Polling con timeout sobre el puerto de estado del 8042
; Compila: nasm -f bin POLL_T.ASM -o POLL_T.COM
; MAX_RETRY se fija en 0005h para forzar el timeout sin pulsar teclas.

[BITS 16]
[ORG 0x100]

MAX_RETRY EQU 0005h             ; 0FFFFh en la version normal

start:
    MOV  CX, MAX_RETRY
.poll:
    IN   AL, 64h
    TEST AL, 01h
    JNZ  .dato_listo
    LOOP .poll                  ; CX - 1 y repite si CX != 0

    MOV  AH, 09h                ; CX llego a 0 sin dato
    MOV  DX, msg_timeout
    INT  21h
    JMP  .fin

.dato_listo:
    IN   AL, 60h
    MOV  BL, AL
    MOV  AH, 09h
    MOV  DX, msg_dato
    INT  21h
    MOV  DL, BL                 ; byte leido impreso como caracter
    MOV  AH, 02h
    INT  21h

.fin:
    MOV  AX, 4C00h
    INT  21h

msg_timeout DB 'Timeout: sin respuesta del dispositivo', 0Dh, 0Ah, '$'
msg_dato    DB 'Dato recibido: $'
