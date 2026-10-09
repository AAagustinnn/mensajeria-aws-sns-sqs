# Entrega — Actividades 2 y 3

## Errores encontrados (síntoma, causa, corrección)

Los 5 errores intencionales del enunciado, más un problema de compilación.

### Error 1 — La tarjeta DLQ del panel muestra lo mismo que la cola principal
- **Actividad:** 2 (`EstadoController`)
- **Síntoma:** en `/estado`, `dlq` siempre vale lo mismo que `principal`. La tarjeta "En DLQ" se pone roja cuando hay órdenes normales en cola y queda en 0 aunque `ordenes-dlq` tenga mensajes (se ve en la consola de SQS).
- **Causa:** el atributo `dlq` consultaba `props.colaOrdenes()` en vez de `props.dlqOrdenes()`.
- **Corrección:** consultar `props.dlqOrdenes()`. En la Actividad 3 el controller se reescribió con `admin.estado(props.dlqOrdenes())`.

### Error 2 — Las órdenes con error transitorio se pierden y nunca llegan a la DLQ
- **Actividad:** 2 (`OrdenListener`)
- **Síntoma:** la orden 3 (Cliente 1) aparece una vez con el error y, en el segundo intento, el log dice `Orden 3 duplicada, se ignora`. No hay 3 intentos y la orden no aparece en `ordenes-dlq`.
- **Causa:** `procesadas.add(orden.id())` se ejecutaba **antes** de `procesador.procesar(orden)`. El primer intento fallaba, pero el id ya quedaba marcado. El reintento se trataba como duplicado y el listener retornaba sin error, así que el mensaje se **confirmaba** y se borraba.
- **Corrección:** marcar la orden como procesada **después** de procesarla bien. Ahora la orden 3 se recibe 3 veces (~10 s entre intentos, por el visibility timeout) y SQS la mueve a la DLQ por `maxReceiveCount = 3`.

### Error 3 — La app no arranca con `max-concurrent-messages=1`
- **Actividad:** 2 §7 y 3 §1 (`application.properties`)
- **Síntoma:** al arrancar falla con `IllegalArgumentException: messagesPerPoll should be less than or equal to maxConcurrentMessages. Values provided: 10 and 1 respectively`.
- **Causa:** Spring Cloud AWS exige `max-messages-per-poll <= max-concurrent-messages` (lo verifica `AbstractContainerOptions`). `max-messages-per-poll` vale 10 por defecto.
- **Corrección:** agregar `spring.cloud.aws.sqs.listener.max-messages-per-poll=1`. Para la comparación con 10, poner ambos en 10.

### Error 4 — "Pausar listener" responde OK pero las órdenes se siguen procesando
- **Actividad:** 3 (`ColaAdminService`)
- **Síntoma:** `POST /admin/listener/pausar` devuelve "Listener pausado", pero las 5 órdenes se procesan igual y el panel no las muestra acumuladas.
- **Causa:** el servicio buscaba el contenedor `"procesador-orden"`, pero el `@SqsListener` tiene `id = "procesador-ordenes"`. Al no encontrarlo, no hacía nada y no avisaba.
- **Corrección:** se usa una sola constante `OrdenListener.LISTENER_ID` en ambos lados. Si el contenedor no existe, ahora se lanza un error explícito en vez de ignorarlo.

### Error 5 — Reprocesar la DLQ falla y los mensajes no salen de la DLQ
- **Actividad:** 3 (`ColaAdminService.reprocesar`)
- **Síntoma:** `POST /admin/dlq/reprocesar` responde 500 (`ReceiptHandleIsInvalid`). Las órdenes quedan en la DLQ y además se duplican en `ordenes-q`.
- **Causa:** `deleteMessage` usaba `destinoUrl`. Un receipt handle solo es válido en la cola donde se recibió el mensaje, que es la DLQ.
- **Corrección:** `deleteMessage(r -> r.queueUrl(dlqUrl)...)`. Además, se mueven solo los mensajes que había al empezar. Así, una orden que vuelve a fallar y regresa a la DLQ no se reenvía en bucle.

### Extra — `ColaAdminService` del enunciado no compila
- **Síntoma:** `cannot find symbol: method ifPresent(...)`.
- **Causa:** en Spring Cloud AWS 3.1.1, `MessageListenerContainerRegistry.getContainerById` devuelve `MessageListenerContainer<?>` (o `null`), no un `Optional`.
- **Corrección:** se comprueba si es `null` (método `contenedorOrdenes()`).

### Cómo se comprobó que cada error quedó corregido

| Error | Con el bug habría pasado… | Lo que pasó en nuestras pruebas (evidencia) |
|---|---|---|
| 1. DLQ leía la cola principal | "En cola" y "En DLQ" mostrarían siempre el mismo número | Durante la pausa el panel mostró **5 en cola y 2 en DLQ** (`a3-06-panel-5-en-cola-pausado.png`) |
| 2. Duplicado marcado antes de procesar | La orden 3 se intentaría 1 vez, luego "duplicada" y se perdería | La orden 3 se intentó **3 veces** y llegó a la DLQ (`a2-08-log-intentos-orden-3-y-5.txt`, `a2-13-dlq-cuerpo-orden-3.png`) |
| 3. Faltaba `max-messages-per-poll` | La app no arrancaría con `max-concurrent-messages=1` | La app arrancó y procesó de a una (`a2-09-log-concurrencia-1-vs-10.txt`) |
| 4. Id del listener mal escrito | "Pausar" respondería OK pero las órdenes se procesarían igual | Las 5 órdenes quedaron en cola hasta reanudar (`a3-06-…png`, `a3-07-log-pausa-reanudar.txt`) |
| 5. Borraba de la cola equivocada | `/admin/dlq/reprocesar` daría 500 y la DLQ no se vaciaría | Respondió `{"movidos":4}` y la DLQ bajó de 4 a 2 (`a3-10-…png`, `a3-11-…png`) |
| Extra: `.ifPresent` no compilaba | `mvnw package` fallaría | Compiló sin errores (BUILD SUCCESS) |

---

## Actividad 2 — Resultados esperados

| Prueba | Resultado |
|---|---|
| `/ordenes` (id 1) | Responde al instante (~0,05–0,3 s): "Orden 1 recibida" |
| `/ordenes/sync` (id 2) | Tarda **≥ 2 s** (el `Thread.sleep(2000)` ocurre dentro de la petición) |
| Orden 3, Cliente 1 por `/ordenes` | El usuario recibe "recibida" al instante. En el log aparece `Recibida orden 3` **3 veces**, ~10 s entre cada una. Luego va a `ordenes-dlq` (redrive) |
| Orden 4, Cliente 1 por `/ordenes/sync` | El usuario recibe **HTTP 500** (`ErrorTransitorio`) y la orden no queda registrada en ninguna cola |
| Orden 5, monto -5 | **1 solo intento**: `Orden 5 descartada: Monto inválido`. Va directo a la DLQ y el mensaje se confirma |
| Duplicado (id 1) | `Orden 1 duplicada, se ignora` |
| `ordenes-dlq` | Mensajes de las órdenes 3 y 5 (*Poll for messages*) |
| `prueba-ttl-q` | A los 2–3 min el mensaje desaparece y **no** llega a la DLQ |

## Respuestas — Actividad 2

1. **Visibility timeout vs. retention period.** El *visibility timeout* (10 s) es el tiempo que un mensaje ya entregado queda oculto para otros consumidores mientras se procesa. Si no se borra en ese plazo, vuelve a quedar visible y se reintenta. El *retention period* es cuánto vive un mensaje en la cola en total, se lea o no (60 s a 14 días; `ordenes-dlq` usa 14 días). Al cumplirse, SQS lo elimina.
2. **No bloquear el flujo del pedido.** En `/ordenes/sync` el usuario espera los 2 s del procesamiento. Si el servicio externo falla, recibe un 500 y su pedido se pierde aunque ya estaba "guardado". Con `/ordenes` la respuesta es inmediata, y el fallo se maneja en segundo plano con reintentos y DLQ. Así, el pedido no depende de la disponibilidad ni de la latencia del servicio externo.
3. **Transitorio vs. definitivo.** El **transitorio** no se captura: el mensaje no se confirma, reaparece tras el visibility timeout y se reintenta. A la 3.ª recepción SQS lo mueve a la DLQ. El **definitivo** se captura, se envía directo a la DLQ y se confirma en el primer intento. Conviene distinguirlos porque reintentar un dato inválido nunca funciona: solo gasta recursos y retrasa la alerta. Un fallo temporal, en cambio, puede resolverse solo.
4. **¿El mensaje expirado de `prueba-ttl-q` fue a la DLQ?** **No.** La DLQ solo recibe mensajes que superan `maxReceiveCount`, es decir, que se recibieron y no se borraron. Un mensaje que expira por retención se elimina sin pasar por la DLQ.
5. **Centralizar nombres en `application.properties`.** Se cambian en un solo lugar y sin recompilar. Permiten usar otros valores por entorno (perfiles, variables de entorno) y evitan errores de tipeo repartidos por el código, como el Error 4.
6. **Efecto de `max-concurrent-messages`.** Medido en nuestra prueba (10 órdenes de 2 s cada una):
   - Con **1**: se procesan de a una (c1 → c2 → c9 → c3 …, cada ~2,2 s) → **~23 s** en total.
   - Con **10**: varias en paralelo (d4, d5 y d7 terminaron en el mismo milisegundo) → **~13,4 s** en total.
   No llegó al ideal (~2 s) porque las órdenes llegan escalonadas y cada poll de SQS devuelve solo los mensajes ya disponibles, así que el paralelismo real fue de 2–3 a la vez. Más concurrencia = más throughput, a costa de más carga simultánea sobre el servicio que procesa.

## Respuestas — Actividad 3

1. **¿Se perdió alguna orden al detener una instancia?** **No.** En nuestra prueba la 8082 recibió la orden `r6` (21:14:02) y se cerró antes de terminarla; 10 s después (visibility timeout) la 8080 la recibió y la procesó (21:14:13 → 21:14:15). Resultado: 8080 procesó 13, 8082 procesó 7 → 20/20. Los mensajes que la instancia detenida tenía en proceso nunca se confirmaron (borraron). Cuando vence su visibility timeout (10 s), vuelven a quedar visibles y la otra instancia los procesa. SQS garantiza entrega *at-least-once*. Por eso una orden podría procesarse dos veces, y el control de duplicados en memoria es por instancia.
2. **¿Por qué no hace falta un cluster?** SQS es un servicio administrado (serverless): AWS se encarga del almacenamiento, la replicación, la alta disponibilidad y el escalado de la cola. Nosotros solo escalamos los consumidores, levantando más instancias de la app.
3. **Mensajes con el listener pausado.** Quedan en la cola como *disponibles* ("En cola" en el panel), sin procesarse. Se conservan hasta el retention period de `ordenes-q` (por defecto 4 días). Si se reanuda antes, se procesan con normalidad.
4. **¿Por qué un servicio y no varios controllers?** La lógica de SQS queda en un solo lugar. `EstadoController` y `AdminController` la reutilizan, los controllers solo exponen HTTP y no dependen del SDK, y es más fácil de probar (se puede simular el servicio). Un cambio, como el nombre del listener o el SDK, se hace una sola vez.
5. **¿Por qué una orden reprocesada volvió a la DLQ?** (Resultado real: `{"movidos":4}` → órdenes 3 y x1 procesadas; 5 y x2 de vuelta en la DLQ, que quedó con 2.) Con `simular-fallo=false`, la orden de **Cliente 1** se procesa bien, porque su fallo era transitorio. La de **monto -5** vuelve a la DLQ: su error es **definitivo**, el dato es inválido y reprocesarlo no lo arregla. Por eso se lanza de nuevo `ErrorDefinitivo`.

---

## Evidencias (carpeta `evidencias/`)

**Actividad 2**
| Entregable | Archivo |
|---|---|
| Infraestructura creada | `a2-01-infra-creada.png`, `a2-12-ordenes-q-dlq-max-receives-3.png` |
| Experimento TTL (expira y no va a la DLQ) | `a2-02-ttl-expirado-no-va-a-dlq.png` |
| 1. Tiempos `/ordenes` vs `/ordenes/sync` y 500 al fallar | `a2-03-tiempos-ordenes-vs-sync.png` |
| 2. Log de intentos órdenes 3 y 5 | `a2-08-log-intentos-orden-3-y-5.txt` |
| 3. `ordenes-dlq` con ambos mensajes | `a2-05-dlq-mensajes.png`, `a2-13-dlq-cuerpo-orden-3.png` |
| 4. Alarma *In alarm* y correo | `a2-00-suscripcion-confirmada.png`, `a2-06-alarma-en-alarma.png`, `a2-07-correo-alarma.png` |
| 5. Panel con DLQ en rojo | `a2-04-panel-dlq-rojo.png` |
| Concurrencia 1 vs 10 | `a2-09-log-concurrencia-1-vs-10.txt`, `a2-10-…`, `a2-11-…` |

**Actividad 3**
| Entregable | Archivo |
|---|---|
| 1. Dos instancias, reparto y caída de una | `a3-01-log-dos-instancias-y-caida.txt` |
| 2. Cola creada y eliminada desde la API | `a3-02-cola-cliente-101-creada.png`, `a3-03-api-crear-eliminar-cola.png`, `a3-04-cola-cliente-101-eliminada.png` |
| 3. Panel con órdenes acumuladas en pausa | `a3-05-pausar-y-enviar-5.png`, `a3-06-panel-5-en-cola-pausado.png`, `a3-07-log-pausa-reanudar.txt` |
| 4. Resultado del reprocesamiento | `a3-09-llenar-dlq-x1-x2.png`, `a3-10-reprocesar-movidos-4.png`, `a3-11-panel-dlq-2-tras-reprocesar.png`, `a3-08-log-reprocesar-dlq.txt` |
| 5. Errores encontrados | Sección "Errores encontrados" de este documento |
