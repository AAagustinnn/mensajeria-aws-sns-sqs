package com.example.mensajeriaaws;

import io.awspring.cloud.sqs.annotation.SqsListener;
import io.awspring.cloud.sqs.operations.SqsTemplate;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class OrdenListener {

    /** Id del contenedor del listener. ColaAdminService lo usa para pausar/reanudar (ERROR 4). */
    public static final String LISTENER_ID = "procesador-ordenes";

    private static final Logger log = LoggerFactory.getLogger(OrdenListener.class);

    private final ProcesadorOrden procesador;
    private final SqsTemplate sqsTemplate;
    private final MensajeriaProperties props;
    private final Set<String> procesadas = ConcurrentHashMap.newKeySet();

    public OrdenListener(ProcesadorOrden procesador, SqsTemplate sqsTemplate, MensajeriaProperties props) {
        this.procesador = procesador;
        this.sqsTemplate = sqsTemplate;
        this.props = props;
    }

    @SqsListener(id = LISTENER_ID, value = "${mensajeria.cola-ordenes}")
    public void escuchar(Orden orden) throws InterruptedException {
        log.info("Recibida orden {} de {}", orden.id(), orden.cliente());

        if (procesadas.contains(orden.id())) {
            log.warn("Orden {} duplicada, se ignora", orden.id());
            return;
        }
        try {
            procesador.procesar(orden);
            // ERROR 2 corregido: la orden se marca como procesada SOLO cuando terminó bien.
            // Antes se marcaba antes de procesar, y el reintento de un ErrorTransitorio
            // se descartaba como "duplicado" (el mensaje se confirmaba y se perdía).
            procesadas.add(orden.id());
        } catch (ErrorDefinitivo e) {
            log.error("Orden {} descartada: {}", orden.id(), e.getMessage());
            sqsTemplate.send(props.dlqOrdenes(), orden);   // directo a la DLQ; el mensaje se confirma
        }
        // ErrorTransitorio no se captura: el mensaje no se confirma y se reintenta
    }
}
