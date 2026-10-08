package com.example.mensajeriaaws;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class MensajeriaAwsApplication {

    public static void main(String[] args) {
        SpringApplication.run(MensajeriaAwsApplication.class, args);
    }
}
