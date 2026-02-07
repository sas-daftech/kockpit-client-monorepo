package org.kockpit.audit.stream.opensearch;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.kockpit.audit.api.AuditorEventService;
import org.kockpit.audit.api.AuditorKeyValueService;
import org.kockpit.audit.api.AuditorService;
import org.kockpit.audit.api.IndexedKeyValue;
import org.kockpit.audit.module.web.WebAuditEvent;
import org.kockpit.audit.module.web.WebAuditReportData;
import org.kockpit.audit.module.web.request.HttpAuditedRequest;
import org.kockpit.audit.module.web.response.HttpAuditedResponse;
import org.kockpit.audit.stream.api.AuditConsumer;
import org.kockpit.audit.stream.api.model.AuditReport;
import org.kockpit.sdk.SdkApplicationProperties;
import org.opensearch.action.bulk.BulkItemResponse;
import org.opensearch.action.bulk.BulkRequest;
import org.opensearch.action.bulk.BulkResponse;
import org.opensearch.action.index.IndexRequest;
import org.opensearch.client.RequestOptions;
import org.opensearch.client.RestHighLevelClient;
import org.opensearch.common.xcontent.XContentType;
import org.springframework.scheduling.annotation.Scheduled;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static java.util.Objects.isNull;
import static org.kockpit.audit.stream.opensearch.OpensearchHelper.*;

@Slf4j
@RequiredArgsConstructor
public class AuditConsumerForOpensearch implements AuditConsumer {

    // local cache for batch indexing
    private final List<AuditReport> auditReports = new ArrayList<>();

    private final RestHighLevelClient restHighLevelClient;

    private final OpensearchV3IndexManager opensearchV3IndexManager;

    private final AuditorService auditorService;

    private final AuditorKeyValueService auditorKeyValueService;

    private final AuditorEventService auditorEvents;

    private final SdkApplicationProperties sdkApplicationProperties;

    private final ObjectMapper objectMapper;

    private final String indexSuffix;

    private final Integer ttlDefaultInDays;

    @PostConstruct
    public void start() {
        log.info("OpenSearch Audit consumer started!");
        Runtime.getRuntime().addShutdownHook(new Thread(this::index));
    }

    @Override
    public void accept(AuditReport auditReport) {
        auditReports.add(auditReport);
    }

    @Scheduled(
            fixedDelayString = "${kockpit.audit.stream.opensearch.scheduler_ms:5000}",
            timeUnit = TimeUnit.MILLISECONDS)
    void index() {
        if (auditReports.isEmpty()) {
            return;
        }
        // defensive copy
        AuditReport[] copy = Arrays.copyOf(auditReports.toArray(), auditReports.size(), AuditReport[].class);
        auditReports.clear();

        this.indexAudits(copy);
    }

    private void indexAudits(AuditReport[] auditReports) {
        Arrays.stream(auditReports)
                .peek(auditReport -> {
                    if (isNull(auditReport.getTtl())) {
                        auditReport.setTtl(ttlDefaultInDays);
                    }
                })
                .collect(Collectors.groupingBy(IndexMetadata::of))
                .forEach((indexMetadata, auditIndexRequestsGrouped) -> {

                    boolean auditStarter = startAudit(auditIndexRequestsGrouped);

                    log.debug("Start indexing {} reports, for Index {}", auditIndexRequestsGrouped.size(), indexMetadata);
                    long now = System.currentTimeMillis();

                    String indexPrefix = getIndexPrefix(indexMetadata.getDomain(), indexSuffix, indexMetadata.getEnv(), indexMetadata.getTtl());
                    String aliasWrite = getAliasWrite(indexMetadata.getDomain(), indexSuffix, indexMetadata.getEnv(), indexMetadata.getTtl());
                    String aliasRead = getAliasRead(indexMetadata.getDomain(), indexSuffix, indexMetadata.getEnv());

                    String indexName = "<" + indexPrefix + "-{now/d}-00001>";
                    // ensure the index exists (template, policy and aliases)
                    opensearchV3IndexManager.ensureIndexExists(indexName, aliasWrite, aliasRead, indexPrefix, indexMetadata.getTtl());

                    // index requests
                    BulkRequest bulkRequest = auditIndexRequestsGrouped.stream()
                            .map(auditIndexRequest -> toIndexRequest(auditIndexRequest, aliasWrite))
                            .collect(BulkRequest::new, BulkRequest::add, (left, right) -> left.add(right.requests()));

                    try {
                        BulkResponse bulkResponse = bulkRequest(bulkRequest);
                        log.debug("indexing {} for {} took {} ms", auditIndexRequestsGrouped.size(), indexMetadata, System.currentTimeMillis() - now);
                        if (auditStarter) {
                            auditResponseOk(bulkResponse);
                        }

                    } catch (Exception e) {
                        log.error("Error indexing for index {}", indexMetadata, e);
                        if (auditStarter) {
                            auditResponseFailed(e);
                        }
                    } finally {
                        if (auditStarter) {
                            auditorService.stopAuditAndNotify();
                        }
                    }
                });
    }

    private boolean startAudit(List<AuditReport> auditReports) {
        if (! skipAudit(auditReports)) {
            auditorService.startAudit();
            auditorKeyValueService.addIndexedKeyValues(List.of(
                    IndexedKeyValue.builder().key("httpMethod").value("bulk_index").build(),
                    IndexedKeyValue.builder().key("requestUri").value("/opensearch").build()
            ));
            return true;
        } else {
            return false;
        }
    }

    private void auditResponseOk(BulkResponse bulkResponse) {
        int status = bulkResponse.status().getStatus();
        auditorKeyValueService.addIndexedKeyValues(List.of(
                IndexedKeyValue.builder().key("httpStatus").value(""+status).valueInteger(status).build(),
                IndexedKeyValue.builder().key("itemsSize").valueInteger(bulkResponse.getItems().length).build(),
                IndexedKeyValue.builder().key("indexDuration").value(""+bulkResponse.getTook().duration()).build(),
                IndexedKeyValue.builder().key("ingestDuration").value(""+bulkResponse.getIngestTookInMillis()).build(),
                IndexedKeyValue.builder().key("hasFailures").value(""+bulkResponse.hasFailures()).build()
        ));
        auditorEvents.addAuditEvents(WebAuditReportData.TYPE, List.of(
                WebAuditEvent.builder()
                        .httpAuditedRequest(HttpAuditedRequest.builder()
                                .body("{}")
                                .method("bulk_index")
                                .build())
                        .httpAuditedResponse(HttpAuditedResponse.builder()
                                .body(bulkResponse.buildFailureMessage())
                                .status(bulkResponse.status().getStatus())
                                .build())
                        .build()
        ));
    }

    private void auditResponseFailed(Exception e) {
        auditorKeyValueService.addIndexedKeyValues(List.of(
                IndexedKeyValue.builder().key("httpStatus").value("500").valueInteger(200).build()
        ));

        auditorEvents.addAuditEvents(WebAuditReportData.TYPE, List.of(
                WebAuditEvent.builder()
                        .httpAuditedRequest(HttpAuditedRequest.builder()
                                .body("{}")
                                .method("bulk_index")
                                .uri("opensearch_cluster")
                                .build())
                        .httpAuditedResponse(HttpAuditedResponse.builder()
                                .status(500)
                                .body(e.getMessage())
                                .build())
                        .build()
        ));
    }

    /**
     * Do not audit "sef" reports, i.e reports from this application
     * @param auditReports
     * @return
     */
    private boolean skipAudit(List<AuditReport> auditReports) {
        return auditReports.isEmpty() ||
                auditReports.iterator().next().getAppId().equals(sdkApplicationProperties.getAppId());
    }

    @SneakyThrows
    private BulkResponse bulkRequest(BulkRequest bulkRequest) {
        BulkResponse bulkResponse = restHighLevelClient.bulk(bulkRequest, RequestOptions.DEFAULT);
        if (bulkResponse.hasFailures()) {
            Stream.of(bulkResponse.getItems())
                    .filter(BulkItemResponse::isFailed)
                    .forEach(bulkItemResponse -> log.error("Bulk item in error {}", bulkItemResponse.getFailureMessage()));
        }
        return bulkResponse;
    }

    @SneakyThrows
    private IndexRequest toIndexRequest(AuditReport auditReport, String writeAlias) {
        return new IndexRequest(writeAlias)
                .id(isNull(auditReport.getId()) ? auditReport.getRequestId() : auditReport.getId())
                .source(objectMapper.writeValueAsBytes(auditReport), XContentType.JSON);
    }

}
