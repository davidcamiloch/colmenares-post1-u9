; ISR_KB.ASM - ISR propio para IRQ1 (teclado)
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
; Desviaciones de la guia:
; - Cada tecla genera dos IRQ1: una al presionar (make) y otra al soltar (break,
;   bit 7 = 1). El ISR solo cuenta los make codes para que 5 teclas sean 5 avisos.
; - LDS DX,[old_isr] cambia DS; se guarda y restaura DS para que el mensaje final
;   se lea del segmento del programa y no del segmento del BIOS.

[BITS 16]
[ORG 0x100]

MAX_KEYS EQU 5
EOI      EQU 20h
PIC_CMD  EQU 20h
BIT_BREAK EQU 80h

start:
    MOV  AX, 3509h              ; vector actual de INT 09h -> ES:BX
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    MOV  DX, mi_isr             ; DS:DX = nuevo manejador (DS = CS en .COM)
    MOV  AX, 2509h
    INT  21h
    STI

.esperar:
    CMP  WORD [contador], MAX_KEYS
    JB   .esperar               ; el programa principal solo espera

    CLI
    PUSH DS
    LDS  DX, [old_isr]          ; DS:DX = manejador original
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AX, 4C00h
    INT  21h

; ---- ISR propio ----
mi_isr:
    PUSH AX
    PUSH DX
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX

    IN   AL, 60h                ; leer scancode (libera el 8042)
    TEST AL, BIT_BREAK
    JNZ  .eoi                   ; tecla soltada: no se cuenta

    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h
    INC  WORD [contador]

.eoi:
    MOV  AL, EOI
    OUT  PIC_CMD, AL            ; fin de interrupcion al PIC maestro
    POP  DS
    POP  DX
    POP  AX
    IRET

contador  DW 0
old_isr   DD 0
msg_tecla DB 0Dh, 0Ah, "Tecla detectada por ISR propio$"
msg_fin   DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.", 0Dh, 0Ah, "$"
