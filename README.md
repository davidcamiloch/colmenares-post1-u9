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

## Parte 2: Interrupciones de hardware

| Programa | Recurso | Técnica | Salida verificada en DOSBox |
|----------|---------|---------|-----------------------------|
| `ISR_KB.ASM` | INT 09h, puerto 20h | ISR propio con EOI y restauración del vector | `Tecla detectada por ISR propio` ×5 y `ISR restaurado` |
| `MASK_KB.ASM` | IMR en 21h | Bit 1 del IMR en 1 durante 55 ticks | `IMR = FA` enmascarado y `IMR = F8` restaurado |
| `ISR_CHN.ASM` | INT 09h | ISR encadenado con `PUSHF` y `CALL FAR` | Eco `holas` y `Teclas contadas por el ISR propio: 5` |
| `ISR_TIME.ASM` | INT 09h, 0040h:006Ch | Intervalo en ticks entre make codes | 19, 20, 37, 56 y 1 ticks |

### Checkpoint 1: ISR propio para IRQ1

`ISR_KB.ASM` obtiene el vector actual con INT 21h AH = 35h (ES:BX), lo guarda en `old_isr` e instala `mi_isr` con AH = 25h. El ISR guarda AX, DX y DS, carga DS con CS, lee el scancode en 60h (esa lectura libera el 8042), imprime el aviso si es un make code, envía EOI (20h al puerto 20h), restaura los registros y ejecuta `IRET`. El programa principal solo espera a que `contador` llegue a 5 y luego reinstala el vector original. El ISR ocupa 32 bytes (0136h a 0155h).

### Checkpoint 2: enmascaramiento con el IMR

`MASK_KB.ASM` lee el IMR del puerto 21h (F8h: IRQ0, IRQ1 e IRQ2 habilitadas), pone en 1 el bit 1 con `OR AL, 02h` y lo escribe. El IMR queda en FAh y el PIC deja de entregar IRQ1. Durante 55 ticks (3 s × 18,2) se pulsaron x, y y z sin que aparecieran; al restaurar F8h el 8042 entregó las teclas retenidas y se vieron en el prompt (`D:\>xyz`). Eso confirma que el IMR bloquea la entrega al CPU pero no la captura en el controlador.

### Checkpoint 3: encadenamiento de ISR

`mi_isr_chain` cuenta el make code y después llama al manejador original con `PUSHF` y `CALL FAR [cs:old_isr]`. `PUSHF` deja en la pila FLAGS y `CALL FAR` deja CS:IP, que es el mismo marco que crea `INT`; por eso el `IRET` del BIOS regresa a `mi_isr_chain`, y el `IRET` propio regresa al programa interrumpido. El ISR encadenado no envía EOI, porque ya lo hace el BIOS. Como el BIOS sigue guardando las teclas, INT 21h AH = 01h las lee con eco y el contador propio llega a 5 en paralelo.

### Checkpoint 4: medición de intervalo con el contador de ticks

`ISR_TIME.ASM` lee la palabra baja de 0040h:006Ch dentro del ISR, envía EOI y resta el valor guardado en `ticks_prev`. Las cinco teclas pulsadas con pausas de aproximadamente 1, 1, 2 y 3 s y una inmediata dieron 19, 20, 37, 56 y 1 ticks. La conversión de los primeros valores queda así.

```
19 / 18,2 = 1,04 s     37 / 18,2 = 2,03 s     56 / 18,2 = 3,08 s
```

La resta en 16 bits sigue siendo correcta cuando la palabra baja pasa de FFFFh a 0000h, porque el resultado se toma módulo 65 536.

### Desviaciones respecto a la guía

- `ISR_CHAIN.ASM` se llama `ISR_CHN.ASM`. DOS solo admite nombres de 8 caracteres; `ISR_CHAIN` se truncaría a `ISR_CH~1` al montar la carpeta.
- Cada tecla genera dos IRQ1: una al presionar (make) y otra al soltar (break, bit 7 = 1). La guía contaba ambas y cinco avisos correspondían a dos teclas y media. `ISR_KB`, `ISR_CHN` e `ISR_TIME` solo cuentan los make codes.
- `LDS DX, [old_isr]` cambia DS al segmento del BIOS. Si DS no se guarda y se restaura, el mensaje final se lee de ese segmento y se imprime basura. Los tres programas usan `PUSH DS` / `LDS` / `INT 21h` / `POP DS`.
- `MASK_KB.ASM` tenía los mensajes antes del código. En un `.COM` la ejecución empieza en 0100h y la CPU habría ejecutado el texto como instrucciones; los datos se movieron al final. La espera compara con `JB` (sin signo) en lugar de `JL`, porque los ticks son un contador sin signo.
- `ISR_CHN.ASM` lee las teclas con INT 21h AH = 01h para demostrar que el BIOS sigue recibiéndolas a través de la cadena.
- Todos los programas terminan con `MOV AX, 4C00h` para devolver código de salida 0.

### Decisión técnica 3: en qué punto del ISR debe ir el EOI

Mientras el PIC 8259A no recibe el EOI, el bit de IRQ1 sigue activo en su registro ISR (In-Service Register) y el PIC no despacha ninguna IRQ de igual o menor prioridad; solo IRQ0 (el temporizador) tiene más prioridad que IRQ1. Si `ISR_KB.ASM` envía el EOI después de imprimir por INT 21h, toda la impresión transcurre con el teclado, IRQ3 a IRQ7 y las IRQ del PIC esclavo retenidas; un puerto serie o una tarjeta de sonido que pidan servicio en ese lapso esperan, y si llegan dos peticiones de la misma línea antes del EOI una se pierde, porque el IRR solo guarda un bit por línea. Como el ISR no ejecuta `STI`, IF sigue en 0 hasta el `IRET`; por eso un EOI temprano no permite que IRQ1 reentre en el ISR ni que otra interrupción corte la impresión. Lo que sí permite es que el PIC registre y priorice las IRQ pendientes y las presente apenas el `IRET` restaure IF = 1, en lugar de esperar a un EOI que todavía no llegó. Permitir que el PIC despache otras IRQ es seguro; permitir que la misma IRQ1 reentre exigiría `STI` y un ISR reentrante, que este laboratorio no tiene. `ISR_TIME.ASM` envía el EOI justo después de leer el puerto 60h y el contador de ticks porque ahí termina el trabajo que depende del hardware; la impresión ya no lo necesita. Esa es la práctica recomendada en general. La regla es enviar el EOI apenas termina el diálogo con el dispositivo y dejar para después el trabajo lento.

### Decisión técnica 4: polling o interrupción para el mismo dispositivo

El polling de `TECL.ASM` es inaceptable en cualquier programa que deba hacer trabajo útil mientras espera: un juego que anima la pantalla, un programa que recibe datos por el puerto serie o un esquema multitarea cooperativo. El bucle de 12 bytes repite `IN`, `TEST` y `JZ` sin descanso y ocupa el 100 % de la CPU sin avanzar nada. Con `ISR_KB.ASM` el programa principal queda libre y el hardware lo interrumpe solo cuando hay una tecla. En latencia el ISR también gana: el 8042 activa IRQ1, el PIC la presenta y la CPU la atiende al terminar la instrucción en curso; el polling en cambio solo detecta el dato cuando la ejecución vuelve a pasar por `IN AL, 64h`, y si el programa estuviera haciendo otra cosa entre sondeos la demora sería todo ese trabajo. En `TECL.ASM` el bucle es tan corto que la diferencia es mínima, pero el programa no hace nada más. Para un dispositivo lento y esporádico como el teclado, que puede pasar minutos sin eventos, el polling consume millones de ciclos que no producen nada, impide que la CPU haga otra tarea y además obliga a deshabilitar interrupciones para que el BIOS no le gane el dato, como mostró `TECL.ASM`. Ambos métodos funcionan en el laboratorio, pero solo la interrupción escala a un programa real. La regla es usar polling para esperas cortas y garantizadas, y una interrupción para eventos esporádicos.

## Capturas

| Archivo | Contenido |
|---------|-----------|
| `capturas/p1-cp0-compilacion.png` | `COMPILA.BAT` ensamblando los ocho programas sin errores |
| `capturas/p1-cp0-tamanos-com.png` | Listado de los ocho `.COM` con sus tamaños |
| `capturas/p1-cp1-tecl-ejecucion.png` | Checkpoint 1: scancode 1E leído por polling |
| `capturas/p1-cp1-tecl-debug.png` | Checkpoint 1: bucle de polling desensamblado con `u 100 12f` |
| `capturas/p1-cp2-cp4-poll-lpt-multi-ejecucion.png` | Checkpoints 2 a 4: timeout, envío a LPT1 y polling combinado |
| `capturas/p1-cp2-poll-t-debug.png` | Checkpoint 2: `LOOP` con CX = 5 desensamblado |
| `capturas/p1-cp3-lptsend-debug.png` | Checkpoint 3: protocolo Centronics por DX |
| `capturas/p1-cp4-multi-st-debug.png` | Checkpoint 4: normalización y OR de las banderas |
| `capturas/p2-cp1-isr-kb-ejecucion.png` | Checkpoint 1: cinco avisos del ISR propio y restauración |
| `capturas/p2-cp1-isr-kb-debug.png` | Checkpoint 1: instalación del vector con AH = 35h y 25h |
| `capturas/p2-cp2-mask-kb-ejecucion.png` | Checkpoint 2: IMR = FA enmascarado y F8 restaurado |
| `capturas/p2-cp2-mask-kb-debug.png` | Checkpoint 2: lectura y escritura del puerto 21h |
| `capturas/p2-cp3-isr-chain-ejecucion.png` | Checkpoint 3: eco del BIOS y conteo propio de 5 teclas |
| `capturas/p2-cp3-isr-chain-debug.png` | Checkpoint 3: instalación del ISR encadenado |
| `capturas/p2-cp4-isr-time-ejecucion.png` | Checkpoint 4: intervalos de 19, 20, 37, 56 y 1 ticks |
| `capturas/p2-cp4-isr-time-debug.png` | Checkpoint 4: lectura inicial de 0040h:006Ch |

## Referencias

- Brown, R. (s.f.). *Ralf Brown's Interrupt List: INT 21h, INT 16h, INT 1Ah*. http://www.ctyme.com/rbrown.htm
- Intel 8259. (s.f.). En *Wikipedia*. https://en.wikipedia.org/wiki/Intel_8259
- Intel Corporation. (1988). *8259A Programmable Interrupt Controller*. Hoja de datos.
- Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual*. https://www.intel.com/sdm
- NASM Development Team. (s.f.). *NASM: The Netwide Assembler*. https://www.nasm.us/doc/
- Rey Castillo, J. R. (s.f.). *Entrada y salida avanzados: puertos, polling e interrupciones en NASM sobre DOSBox*. Material del curso Arquitectura de Computadores, UFPS.
