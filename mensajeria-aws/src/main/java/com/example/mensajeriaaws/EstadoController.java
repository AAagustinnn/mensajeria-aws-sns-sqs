package com.example.mensajeriaaws;

import java.util.Map;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Actividad 3 (refactor): ya no habla con el SDK, usa ColaAdminService.
 * ERROR 1 corregido: la tarjeta "dlq" ahora lee la cola DLQ (antes leía la cola principal).
 */
@RestController
@CrossOrigin(origins = "http://localhost:5173")
public class EstadoController {

    private final ColaAdminService admin;
    private final MensajeriaProperties props;

    public EstadoController(ColaAdminService admin, MensajeriaProperties props) {
        this.admin = admin;
        this.props = props;
    }

    @GetMapping("/estado")
    public Map<String, Long> estado() {
        var principal = admin.estado(props.colaOrdenes());
        var dlq = admin.estado(props.dlqOrdenes());
        return Map.of(
            "principal", principal.get("disponibles"),
            "enVuelo",   principal.get("enProceso"),
            "dlq",       dlq.get("disponibles"));
    }
}
