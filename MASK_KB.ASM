; MASK_KB.ASM - Enmascarar y desenmascarar IRQ1 en el IMR del PIC 8259A
; Compila: nasm -f bin MASK_KB.ASM -o MASK_KB.COM
; Desviaciones de la guia:
; - Los mensajes estaban antes del codigo: en un .COM la ejecucion empieza en
;   0100h y la CPU habria ejecutado el texto como instrucciones. Se movieron al final.
; - La espera compara con JB (sin signo) en lugar de JL.

[BITS 16]
[ORG 0x100]

PIC_IMR  EQU 21h
BIT_IRQ1 EQU 02h
TICKS_3S EQU 55                 ; 3 s x 18.2 ticks/s

start:
    IN   AL, PIC_IMR
    MOV  [imr_orig], AL
    OR   AL, BIT_IRQ1           ; bit 1 = 1: IRQ1 enmascarada
    OUT  PIC_IMR, AL

    MOV  AH, 09h
    MOV  DX, msg_mask
    INT  21h
    IN   AL, PIC_IMR            ; mostrar el IMR con IRQ1 enmascarada
    CALL hex8

    MOV  AH, 00h                ; ticks actuales en CX:DX
    INT  1Ah
    MOV  BX, DX
    ADD  BX, TICKS_3S
.wait:
    MOV  AH, 00h
    INT  1Ah
    CMP  DX, BX
    JB   .wait

    MOV  AL, [imr_orig]         ; restaurar el IMR original
    OUT  PIC_IMR, AL

    MOV  AH, 09h
    MOV  DX, msg_unmask
    INT  21h
    IN   AL, PIC_IMR
    CALL hex8
    MOV  AH, 09h
    MOV  DX, crlf
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

imr_orig   DB 0
msg_mask   DB "IRQ1 enmascarado (teclado deshabilitado). IMR = $"
msg_unmask DB 0Dh, 0Ah, "IRQ1 restaurado. IMR = $"
crlf       DB 0Dh, 0Ah, "$"
