package com.example.mensajeriaaws;

import io.awspring.cloud.sqs.listener.MessageListenerContainer;
import io.awspring.cloud.sqs.listener.MessageListenerContainerRegistry;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sqs.SqsAsyncClient;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.QueueAttributeName;

@Service
public class ColaAdminService {

    private static final Logger log = LoggerFactory.getLogger(ColaAdminService.class);

    // ERROR 4 corregido: el id debe ser EXACTAMENTE el del @SqsListener ("procesador-ordenes").
    // Antes decía "procesador-orden", no se encontraba el contenedor y pausar/reanudar no hacían nada.
    private static final String LISTENER_ORDENES = OrdenListener.LISTENER_ID;

    private final SqsAsyncClient sqs;
    private final MessageListenerContainerRegistry registry;

    public ColaAdminService(SqsAsyncClient sqs, MessageListenerContainerRegistry registry) {
        this.sqs = sqs;
        this.registry = registry;
    }

    private String url(String cola) {
        return sqs.getQueueUrl(r -> r.queueName(cola)).join().queueUrl();
    }

    public Map<String, Long> estado(String cola) {
        String url = url(cola);
        var attrs = sqs.getQueueAttributes(r -> r.queueUrl(url).attributeNames(
                QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES,
                QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES_NOT_VISIBLE)).join().attributes();
        return Map.of(
            "disponibles", Long.parseLong(attrs.get(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES)),
            "enProceso",   Long.parseLong(attrs.get(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES_NOT_VISIBLE)));
    }

    public String crear(String cola) {
        return sqs.createQueue(r -> r.queueName(cola)).join().queueUrl();
    }

    public void eliminar(String cola) {
        String url = url(cola);
        sqs.deleteQueue(r -> r.queueUrl(url)).join();
    }

    /**
     * getContainerById devuelve el contenedor o null (no un Optional), por eso el
     * ".ifPresent(...)" del enunciado no compila. Además, si el id no existe se lanza
     * un error claro en vez de "no hacer nada" en silencio.
     */
    private MessageListenerContainer<?> contenedorOrdenes() {
        MessageListenerContainer<?> c = registry.getContainerById(LISTENER_ORDENES);
        if (c == null) {
            throw new IllegalStateException("No existe un listener con id '" + LISTENER_ORDENES + "'");
        }
        return c;
    }

    public void pausar() {
        contenedorOrdenes().stop();
        log.info("Listener {} pausado", LISTENER_ORDENES);
    }

    public void reanudar() {
        contenedorOrdenes().start();
        log.info("Listener {} reanudado", LISTENER_ORDENES);
    }

    /** Mueve los mensajes de la DLQ a la cola de destino. Devuelve cuántos movió. */
    public int reprocesar(String dlq, String destino) {
        String dlqUrl = url(dlq);
        String destinoUrl = url(destino);
        // Se mueven solo los mensajes que había al empezar: si una orden vuelve a fallar
        // y regresa a la DLQ mientras corre el ciclo, no se reenvía en bucle.
        long pendientes = estado(dlq).get("disponibles");
        int movidos = 0;
        while (movidos < pendientes) {
            var mensajes = sqs.receiveMessage(r -> r.queueUrl(dlqUrl)
                    .maxNumberOfMessages(10).waitTimeSeconds(1)).join().messages();
            if (mensajes.isEmpty()) break;
            for (Message m : mensajes) {
                sqs.sendMessage(r -> r.queueUrl(destinoUrl).messageBody(m.body())).join();
                // ERROR 5 corregido: el mensaje se borra de la DLQ (de donde se recibió),
                // no de la cola de destino. El receipt handle solo es válido en la cola de origen.
                sqs.deleteMessage(r -> r.queueUrl(dlqUrl).receiptHandle(m.receiptHandle())).join();
                movidos++;
            }
        }
        log.info("Reprocesados {} mensajes de {} a {}", movidos, dlq, destino);
        return movidos;
    }
}
