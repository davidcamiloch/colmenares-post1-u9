# colmenares-post1-u9

Laboratorio del Post-contenido de la Unidad 9 (Entrada y Salida Avanzados: Puertos, Polling e Interrupciones) de Arquitectura de Computadores, UFPS. Autor: David Camilo Colmenares Hernández.

La Parte 1 accede directamente a los puertos del controlador de teclado 8042 (60h y 64h) y del puerto paralelo LPT1 (0378h a 037Ah) con IN y OUT, y sincroniza por polling: sin límite, con timeout y combinando dos banderas con OR. La Parte 2 reemplaza el polling por interrupciones: instala un ISR propio en INT 09h (IRQ1), programa el IMR del PIC 8259A en el puerto 21h, encadena un ISR con el manejador original del BIOS y mide el intervalo entre teclas con el contador de ticks de 0040h:006Ch.

## Entorno

- DOSBox 0.74-3 con la carpeta del laboratorio montada como unidad D: y 20 000 ciclos.
- NASM 3.02 para DOS con CWSDPMI como servidor DPMI.
- DEBUG 2.51 (proyecto DOS-debug), porque DOSBox 0.74 no incluye DEBUG.

Todos los programas son `.COM` (`ORG 100h`), de modo que CS = DS = ES = SS al iniciar y no hace falta cargar segmentos.

```
D:\> nasm -f bin TECL.ASM -o TECL.COM
D:\> tecl
```

`COMPILA.BAT` ensambla los ocho programas y lista los `.COM` en una sola orden. Tamaños obtenidos: TECL 122 bytes, POLL_T 99, LPTSEND 178, MULTI_ST 100, ISR_KB 163, MASK_KB 177, ISR_CHN 187 e ISR_TIME 260.

## Parte 1: Acceso directo a puertos de E/S

| Programa | Puertos | Técnica | Salida verificada en DOSBox |
|----------|---------|---------|-----------------------------|
| `TECL.ASM` | 64h estado, 60h datos | Polling sin límite sobre OBF (bit 0) | `Scancode leido del puerto 60h: 1E` al pulsar A |
| `POLL_T.ASM` | 64h, 60h | Polling con `MAX_RETRY` y `LOOP` | `Timeout: sin respuesta del dispositivo` |
| `LPTSEND.ASM` | 0378h datos, 0379h estado, 037Ah control | Protocolo Centronics: BUSY#, dato y pulso STROBE | `Estado 0379h antes: 87h  despues: 87h` sin bloqueo |
| `MULTI_ST.ASM` | 64h y 0379h | Dos banderas normalizadas a 0 o 1 y combinadas con OR | `LPT1 listo (BUSY#=1).` |

### Checkpoint 1: lectura de scancode por polling

`TECL.ASM` lee el registro de estado en 64h, aísla OBF con `TEST AL, 01h` y repite mientras valga 0. Cuando OBF = 1 lee el scancode en 60h. El bucle completo ocupa 12 bytes (0101h a 010Ch en el listado de DEBUG: `IN AL,64`; `TEST AL,01`; `JZ 0101`; `IN AL,60`; `TEST AL,80`; `JNZ 0101`). Al pulsar la tecla A el programa imprime 1Eh, que es el make code de A en el conjunto de scancodes 1.

## Referencias

- Brown, R. (s.f.). *Ralf Brown's Interrupt List: INT 21h, INT 16h, INT 1Ah*. http://www.ctyme.com/rbrown.htm
- Intel 8259. (s.f.). En *Wikipedia*. https://en.wikipedia.org/wiki/Intel_8259
- Intel Corporation. (1988). *8259A Programmable Interrupt Controller*. Hoja de datos.
- Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual*. https://www.intel.com/sdm
- NASM Development Team. (s.f.). *NASM: The Netwide Assembler*. https://www.nasm.us/doc/
- Rey Castillo, J. R. (s.f.). *Entrada y salida avanzados: puertos, polling e interrupciones en NASM sobre DOSBox*. Material del curso Arquitectura de Computadores, UFPS.
