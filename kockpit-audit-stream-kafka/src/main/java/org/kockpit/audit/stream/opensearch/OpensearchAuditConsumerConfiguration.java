package org.kockpit.audit.stream.opensearch;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.apache.hc.client5.http.async.AsyncExecChainHandler;
import org.apache.hc.core5.http.HttpHost;
import org.kockpit.audit.api.AuditorEventService;
import org.kockpit.audit.api.AuditorKeyValueService;
import org.kockpit.audit.api.AuditorService;
import org.kockpit.audit.stream.api.AuditConsumer;
import org.kockpit.sdk.SdkApplicationProperties;
import org.opensearch.client.RestClient;
import org.opensearch.client.RestClientBuilder;
import org.opensearch.client.RestHighLevelClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.util.CollectionUtils;

import java.util.List;
import java.util.stream.Stream;

@AutoConfiguration
@EnableScheduling
@Slf4j
public class OpensearchAuditConsumerConfiguration {

    ObjectMapper opensearchObjectMapper() {
        return new ObjectMapper()
                .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
                .registerModule(new JavaTimeModule())
                .configure(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS, true)
                .configure(SerializationFeature.WRITE_DATE_TIMESTAMPS_AS_NANOSECONDS, false)
                .configure(JsonGenerator.Feature.WRITE_BIGDECIMAL_AS_PLAIN, true);
    }

    @Bean
    public OpensearchV3IndexManager opensearchV3IndexManager(
            RestHighLevelClient restHighLevelClient,
            @Value("${kockpit.audit.stream.opensearch.index_suffix}") String indexSuffix
            ) {
        log.info("➡️ OpenSearch index suffix: {}", indexSuffix);
        return new OpensearchV3IndexManager(restHighLevelClient);
    }

    @Bean("opensearch")
    public AuditConsumer auditConsumer(
            RestHighLevelClient restHighLevelClient,
            OpensearchV3IndexManager opensearchV3IndexManager,
            AuditorService auditorService, AuditorKeyValueService auditorKeyValueService, AuditorEventService auditorEventService,
            SdkApplicationProperties sdkApplicationProperties,
            @Value("${kockpit.audit.stream.opensearch.index_suffix}") String indexSuffix,
            @Value("${kockpit.audit.stream.opensearch.ttl_default_in_days}") Integer ttlDefaultInDays
    ) {
        return new AuditConsumerForOpensearch(
                restHighLevelClient,
                opensearchV3IndexManager,
                auditorService, auditorKeyValueService, auditorEventService,
                sdkApplicationProperties,
                opensearchObjectMapper(),
                indexSuffix,
                ttlDefaultInDays
        );
    }

    @Bean
    RestHighLevelClient openSearchIndexer(
            @Value("${kockpit.audit.stream.opensearch.endpoints}") String endpoints,
            List<AsyncExecChainHandler> handlers
    ) {
        log.info("Registering {} handlers on OpenSearch", handlers.size());
        HttpHost[] httpHosts = Stream.of(endpoints.split(","))
                .map(String::trim)
                .map(this::create)
                .toArray(HttpHost[]::new);

        RestClientBuilder builder = RestClient.builder(httpHosts);
        if (! CollectionUtils.isEmpty(handlers)) {
            builder.setHttpClientConfigCallback(httpClientBuilder -> {
                for (AsyncExecChainHandler handler : handlers) {
                    log.info("adding interceptor {}", handler.getClass().getName());
                    httpClientBuilder.addExecInterceptorLast(handler.getClass().getName(), handler);
                }
                return httpClientBuilder;
            });
        }

        log.info("➡️ OpenSearch endpoints: {}", endpoints);
        return new RestHighLevelClient(builder);
    }

    @SneakyThrows
    private HttpHost create(String endpoint) {
        return HttpHost.create(endpoint);
    }
}
