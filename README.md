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

### Checkpoint 2: polling con timeout

`POLL_T.ASM` carga CX con `MAX_RETRY` y usa `LOOP .poll`, que decrementa CX y salta mientras no sea cero. Con `MAX_RETRY = 0005h` el bucle hace cinco lecturas del puerto 64h; ninguna encuentra OBF = 1 y el programa imprime el mensaje de timeout sin que el usuario pulse nada. El desensamblado muestra `LOOP 0103` (E2F8h), un salto relativo de −8 bytes hacia `IN AL,64`.

### Checkpoint 3: escritura al puerto paralelo

`LPTSEND.ASM` espera BUSY# = 1 (bit 7 de 0379h), escribe 41h (A) en 0378h, baja el bit 0 de 037Ah (STROBE activo en bajo), espera 15 iteraciones de `LOOP` y lo sube de nuevo. DOSBox 0.74 no emula una impresora, así que el registro de estado devuelve 87h antes y después del pulso: bit 7 = 1 (no ocupada), bits 0 a 2 = 1 (reservados) y bits 3 a 6 = 0. El programa termina sin quedarse en `.wait_ready`.

### Checkpoint 4: polling combinado con OR

`MULTI_ST.ASM` normaliza las dos banderas a 0 o 1: OBF del teclado con `AND AL, 01h` en BL, y BUSY# de LPT1 con `AND AL, 80h` y `SHR AL, CL` (CL = 7) en BH. `OR AL, BH` con AL = BL sale del bucle si alguno vale 1; después el programa examina BL y BH por separado e imprime cuál de los dos dispositivos disparó la condición. En DOSBox el resultado es siempre `LPT1 listo (BUSY#=1).`, por la razón que analiza la Decisión técnica 2.

### Desviaciones respecto a la guía

- `LPT1.ASM` se llama `LPTSEND.ASM`. LPT1 es un nombre de dispositivo reservado en DOS y en Windows; un archivo `LPT1.ASM` no puede crearse en la carpeta de Windows que monta DOSBox.
- Los puertos 0378h a 037Ah se direccionan por DX (`IN AL, DX` y `OUT DX, AL`). La forma con inmediato solo admite puertos de 00h a FFh; con `IN AL, 0379h` NASM trunca el operando y lee el puerto 79h.
- `TECL.ASM` sondea con IF = 0 (`CLI`). Con las interrupciones habilitadas el ISR del BIOS para IRQ1 lee el puerto 60h antes que el bucle y el programa nunca ve OBF = 1. Además ignora los break codes (bit 7 = 1): el primero que llega es 9Ch, la liberación de la tecla Enter que lanzó el programa. Al final vacía el búfer del BIOS con INT 16h para que la tecla no aparezca en el prompt.
- `POLL_T.ASM` usa `MAX_RETRY = 0005h` en lugar de 0FFFFh para mostrar el timeout sin tener que medir la ventana exacta.
- `MULTI_ST.ASM` desplaza con `SHR AL, CL` y CL = 7. El 8086 solo acepta desplazamientos inmediatos de 1; la forma `SHR AL, 7` exige un 80186 o posterior.

### Decisión técnica 1: polling sin límite o polling con timeout configurable

El bucle sin límite de `TECL.ASM` solo es aceptable cuando el dispositivo tiene garantizado responder y nada más depende del programa: en este laboratorio el propio estudiante va a pulsar la tecla y el programa no tiene otra tarea, así que esperar indefinidamente no daña a nadie. En cuanto el dispositivo puede fallar o no estar conectado, como un puerto LPT sin impresora, un controlador que dejó de responder o un periférico que el usuario olvidó encender, el bucle cuelga la máquina y solo un reinicio lo saca. Ahí conviene el timeout de `POLL_T.ASM`, que convierte la espera en una cota y deja al programa decidir qué hacer. El riesgo de reducir `MAX_RETRY` a 5h es el falso timeout: cinco vueltas duran unos pocos microsegundos y el programa declara muerto a un dispositivo que iba a responder un instante después. Además el contador mide iteraciones y no tiempo. Cada vuelta de `IN`, `TEST`, `JNZ` y `LOOP` dura un número fijo de ciclos, pero los ciclos por segundo cambian con la CPU: en este DOSBox basta cambiar `cycles` de 20 000 a 1 000 para que el mismo `MAX_RETRY` espere veinte veces más. El contador de 0040h:006Ch, en cambio, lo incrementa el IRQ0 del PIT 8253 a 18,2 Hz (un tick cada 54,9 ms) sin importar la velocidad de la CPU. La regla es acotar toda espera de hardware y medir la cota en ticks cuando importa el tiempo real.

### Decisión técnica 2: combinar banderas con OR o verificarlas por separado

En DOSBox el bit BUSY# de 0379h vale 1 de forma permanente porque no hay impresora; por eso BH = 1 en cada lectura y `OR AL, BH` nunca da cero. El bucle `.poll` de `MULTI_ST.ASM` termina en la primera iteración sin importar el estado del teclado, y la ejecución lo confirma: el programa imprime `LPT1 listo` de inmediato y nunca espera una tecla. La consecuencia práctica es que la espera combinada deja de esperar: un dispositivo siempre listo anula al otro, y el programa trataría como evento algo que no ocurrió. Por la misma razón el OR solo sirve para salir del bucle; después hay que examinar BL y BH por separado, porque el resultado de la OR dice que alguno está listo pero no cuál, y leer el puerto 60h cuando quien respondió fue LPT1 entregaría un scancode viejo o basura. Si las dos banderas se combinaran con AND (`AND AL, BH` y `JZ .poll`), el programa esperaría a que ambos dispositivos estuvieran listos a la vez. Esa es la condición correcta para enviar a la impresora la tecla que el usuario acaba de pulsar: hace falta que haya un dato en el 8042 y que LPT1 pueda recibirlo. La regla es usar OR para esperar el primero de varios eventos, AND para exigir que coincidan y examinar siempre cada bandera antes de actuar.

## Referencias

- Brown, R. (s.f.). *Ralf Brown's Interrupt List: INT 21h, INT 16h, INT 1Ah*. http://www.ctyme.com/rbrown.htm
- Intel 8259. (s.f.). En *Wikipedia*. https://en.wikipedia.org/wiki/Intel_8259
- Intel Corporation. (1988). *8259A Programmable Interrupt Controller*. Hoja de datos.
- Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual*. https://www.intel.com/sdm
- NASM Development Team. (s.f.). *NASM: The Netwide Assembler*. https://www.nasm.us/doc/
- Rey Castillo, J. R. (s.f.). *Entrada y salida avanzados: puertos, polling e interrupciones en NASM sobre DOSBox*. Material del curso Arquitectura de Computadores, UFPS.
