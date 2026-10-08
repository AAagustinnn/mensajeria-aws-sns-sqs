# Mensajería con Amazon SNS y SQS — Actividades 2 y 3

**Cloud Native I (DSY1107)** — Procesador de órdenes con SQS, DLQ, reintentos, alarma CloudWatch y servicio de administración de colas.

```
.
├── mensajeria-aws/     Backend Spring Boot 3.3 + Spring Cloud AWS 3.1.1 (Java 17)
├── panel-ordenes/      Panel React + Vite (TypeScript)
├── infra/              Scripts AWS CLI: crear / limpiar colas, tópico y alarma
├── pruebas/            Scripts con los curl de las actividades (bash y PowerShell)
└── ENTREGA.md          Errores encontrados (síntoma, causa, corrección) + respuestas
```

## 1. Infraestructura en AWS (Learner Lab, us-east-1)

**Opción A — script (recomendado).** Abre la terminal del Learner Lab o **CloudShell** en la consola (ya traen AWS CLI), sube `infra/crear-infra.sh` y ejecuta:

```bash
bash crear-infra.sh tu_correo@ejemplo.com
```

Crea, en orden:

| Recurso | Configuración |
|---|---|
| `ordenes-dlq` | Retención 14 días |
| `ordenes-q` | Visibility timeout 10 s · DLQ `ordenes-dlq` · Maximum receives 3 |
| `prueba-ttl-q` | Retención 60 s · DLQ `ordenes-dlq` · se le envía 1 mensaje |
| SNS `alertas-dlq` | Suscripción email (**confirma el correo**) |
| Alarma `dlq-ordenes-con-mensajes` | `ApproximateNumberOfMessagesVisible` de `ordenes-dlq`, Maximum, 1 min, > 0 → `alertas-dlq` |

En Windows con AWS CLI instalado: `.\infra\crear-infra.ps1 -Email tu_correo@ejemplo.com`.

**Opción B — consola.** Sigue los pasos de la sección 1 y 5 de la Actividad 2 con los mismos valores de la tabla.

Al terminar el bloque: `bash infra/limpiar-infra.sh`.

## 2. Backend

Copia las credenciales (**AWS Details → AWS CLI → Show**) en la **misma terminal** donde levantas la app:

```powershell
# PowerShell
$env:AWS_ACCESS_KEY_ID="..."
$env:AWS_SECRET_ACCESS_KEY="..."
$env:AWS_SESSION_TOKEN="..."
$env:AWS_REGION="us-east-1"
cd mensajeria-aws
.\mvnw.cmd spring-boot:run
# segunda instancia (Act. 3):  .\mvnw.cmd spring-boot:run "-Dspring-boot.run.arguments=--server.port=8082"
```

```bash
# bash / Git Bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=... AWS_REGION=us-east-1
cd mensajeria-aws && ./mvnw spring-boot:run
```

Configuración en `src/main/resources/application.properties` (nombres de colas, `mensajeria.simular-fallo`, concurrencia).

### Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/ordenes` | Encola la orden (asíncrono) |
| POST | `/ordenes/sync` | Procesa dentro de la petición |
| GET | `/estado` | `{principal, enVuelo, dlq}` para el panel |
| GET / POST / DELETE | `/admin/colas/{cola}` | Estado / crear / eliminar cola |
| POST | `/admin/listener/pausar` · `/admin/listener/reanudar` | Detiene / reanuda el consumidor |
| POST | `/admin/dlq/reprocesar` | Mueve la DLQ a `ordenes-q` → `{movidos: n}` |

## 3. Panel

```bash
cd panel-ordenes
npm install
npm run dev     # http://localhost:5173
```

Botones para crear órdenes de Cliente 1/2/3, tarjetas *En cola / En proceso / En DLQ* (roja si hay fallidas) y, para la Actividad 3, botones de pausar, reanudar y reprocesar DLQ.

## 4. Pruebas

| Paso | bash | PowerShell |
|---|---|---|
| Act. 2 §4 | `bash pruebas/act2-pruebas.sh` | `.\pruebas\pruebas.ps1 act2` |
| Act. 2 §7 / Act. 3 §1 | `bash pruebas/concurrencia.sh c 10` | `.\pruebas\pruebas.ps1 concurrencia c 10` |
| Act. 3 colas | `bash pruebas/act3-pruebas.sh colas` | `.\pruebas\pruebas.ps1 colas` |
| Act. 3 pausa | `... pausa` y luego `... reanudar` | igual |
| Act. 3 DLQ | `... dlq-llenar` → `simular-fallo=false` + reiniciar → `... dlq-reprocesar` | igual |

Los resultados esperados y las respuestas están en [ENTREGA.md](ENTREGA.md).
