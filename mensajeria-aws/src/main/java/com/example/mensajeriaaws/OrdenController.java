package com.example.mensajeriaaws;

import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(origins = "http://localhost:5173")
public class OrdenController {

    private static final Logger log = LoggerFactory.getLogger(OrdenController.class);

    private final SqsTemplate sqsTemplate;
    private final ProcesadorOrden procesador;
    private final MensajeriaProperties props;

    public OrdenController(SqsTemplate sqsTemplate, ProcesadorOrden procesador, MensajeriaProperties props) {
        this.sqsTemplate = sqsTemplate;
        this.procesador = procesador;
        this.props = props;
    }

    @PostMapping("/ordenes")
    public String crear(@RequestBody Orden orden) {
        log.info("Orden {} guardada", orden.id());          // simula la transacción
        sqsTemplate.send(props.colaOrdenes(), orden);       // el procesamiento queda en segundo plano
        return "Orden " + orden.id() + " recibida";
    }

    @PostMapping("/ordenes/sync")
    public String crearSync(@RequestBody Orden orden) throws InterruptedException {
        log.info("Orden {} guardada", orden.id());
        procesador.procesar(orden);                         // procesamiento dentro de la petición
        return "Orden " + orden.id() + " procesada";
    }
}
