package org.kockpit.audit.stream;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.kockpit.audit.stream.api.AuditConsumer;
import org.kockpit.audit.stream.api.AuditConsumerEvent;
import org.kockpit.audit.stream.api.model.AuditReport;
import org.kockpit.audit.stream.console.ConsoleLogger;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ApplicationListener;
import org.springframework.context.annotation.Bean;
import org.springframework.util.CollectionUtils;

import java.util.List;

@SpringBootApplication
@RequiredArgsConstructor
@Slf4j
public class KockpitStreamApplication implements ApplicationListener<AuditConsumerEvent> {

    private final List<AuditConsumer> consumerList;

    public static void main(String[] args) {
        SpringApplication.run(KockpitStreamApplication.class, args);
    }

    @PostConstruct
    void init() {
        if (CollectionUtils.isEmpty(consumerList)) {
            log.error("No AuditConsumer registered!");
            throw new RuntimeException("No AuditConsumer registered!");
        } else {
            consumerList.forEach(consumer -> log.info("➡️ Starting consumer {}", consumer.getClass().getSimpleName()));
        }
    }

    @Override
    public void onApplicationEvent(AuditConsumerEvent event) {
        consumerList.forEach(consumer -> consumer.accept((AuditReport) event.getSource()));
    }

    @Override
    public boolean supportsAsyncExecution() {
        return false;
    }

    @ConditionalOnProperty(
            value = "kockpit.audit.stream.trace",
            havingValue = "true"
    )
    @Bean
    ConsoleLogger consoleLogger() {
        return new ConsoleLogger();
    }
}
