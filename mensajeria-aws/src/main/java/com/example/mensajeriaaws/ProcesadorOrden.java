package com.example.mensajeriaaws;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class ProcesadorOrden {

    private static final Logger log = LoggerFactory.getLogger(ProcesadorOrden.class);
    private final boolean simularFallo;

    public ProcesadorOrden(@Value("${mensajeria.simular-fallo:true}") boolean simularFallo) {
        this.simularFallo = simularFallo;
    }

    public void procesar(Orden orden) throws InterruptedException {
        if (orden.monto() <= 0) {
            throw new ErrorDefinitivo("Monto inválido en orden " + orden.id());
        }
        if (simularFallo && "Cliente 1".equals(orden.cliente())) {
            throw new ErrorTransitorio("Servicio externo no disponible");
        }
        Thread.sleep(2000);
        log.info("Orden {} procesada", orden.id());
    }
}
