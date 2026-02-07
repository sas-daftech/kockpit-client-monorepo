package org.kockpit.audit.stream.kafka.config;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.kockpit.audit.stream.kafka.KafkaStreamListener;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

/**
 * Local override configuration for Kafka stream processing.
 * This configuration fixes the Jackson deserialization issue with Java 8 date/time types
 * by registering the JSR-310 module and configuring the ObjectMapper properly.
 *
 * This class overrides the KafkaStreamAutoConfiguration from the kockpit-audit-stream-starter-kafka library.
 */
@Configuration
public class LocalKafkaStreamConfiguration {

    @Bean
    @Primary
    public KafkaStreamListener kafkaStreamListener(
            ApplicationEventPublisher applicationEventPublisher
    ) {
        return new KafkaStreamListener(
                new ObjectMapper()
                        .findAndRegisterModules()  // Auto-register JSR-310 module for Instant, LocalDateTime, etc.
                        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false),
                applicationEventPublisher
        );
    }
}