package com.example.mensajeriaaws;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "mensajeria")
public record MensajeriaProperties(String colaOrdenes, String dlqOrdenes, String topicoNotificaciones) {}
