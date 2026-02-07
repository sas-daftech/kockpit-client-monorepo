package org.kockpit.audit.stream.opensearch;

import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.opensearch.action.admin.indices.alias.IndicesAliasesRequest;
import org.opensearch.client.Request;
import org.opensearch.client.RequestOptions;
import org.opensearch.client.Response;
import org.opensearch.client.RestHighLevelClient;
import org.opensearch.client.indices.CreateIndexRequest;
import org.opensearch.client.indices.GetIndexRequest;

@RequiredArgsConstructor
@Slf4j
public class OpensearchV3IndexManager {

    private final RestHighLevelClient client;

    @SneakyThrows
    public void ensureIndexExists(String indexName, String aliasWrite, String aliasRead, String indexPrefix, Integer ttl) {
        // create policy
        String policyId = "audit_ism_policy_" + indexPrefix;
        createISMPolicy(ttl, policyId);
        // create template
        createIndexTemplate(indexPrefix, policyId);
        // create index
        if (!client.indices().exists(new GetIndexRequest(indexName), RequestOptions.DEFAULT)) {
            log.info("Creating index name: {}", indexName);

            CreateIndexRequest request = new CreateIndexRequest(indexName);
            client.indices().create(request, RequestOptions.DEFAULT);

            // Attach write alias (only current index)
            attachWriteAlias(indexName, aliasWrite, indexPrefix);

            // Attach read alias (all logs-* indices)
            attachReadAlias(indexName, aliasRead);
        }
    }

    @SneakyThrows
    void createISMPolicy(Integer ttl, String policyId) {
        // First, test ISM plugin availability
        if (!isISMAvailable()) {
            log.warn("⚠️ ISM plugin not available - skipping ISM policy creation. Indices will need manual lifecycle management.");
            return;
        }

        // Check if policy already exists
        try {
            Request getRequest = new Request("GET", "_plugins/_ism/policies/"+policyId);
            Response getResponse = client.getLowLevelClient().performRequest(getRequest);
            log.trace("Policy {} already exists, skipping policy creation, status {}", policyId, getResponse.getStatusLine());

            // Policy exists, update it with seq_no and primary_term
            /* fixme -> response misses data
            log.trace("Policy {} already exists, updating it", policyId);
            Request updateRequest = new Request("PUT", "_plugins/_ism/policies/"+policyId+"?if_seq_no="+getSeqNo(getResponse)+"&if_primary_term="+getPrimaryTerm(getResponse));
            updateRequest.setJsonEntity(policyJson);
            Response updateResponse = client.getLowLevelClient().performRequest(updateRequest);
            log.info("Updated policy {} -> response = {}", policyId, updateResponse.getStatusLine());
             */
        } catch (Exception e) {
            String policyJson = new String(this.getClass().getResourceAsStream("/opensearch/audit_ism_policy.json").readAllBytes())
                    .replace("${delete_min_index_age}", ttl+"d");

            // Policy doesn't exist, create it
            doCreatePolicy(policyId, ttl, policyJson);
        }
    }

    @SneakyThrows
    private boolean isISMAvailable() {
        log.info("🔍 Testing OpenSearch ISM plugin availability...");

        try {
            // Test basic cluster connectivity first
            Request clusterRequest = new Request("GET", "/");
            Response clusterResponse = client.getLowLevelClient().performRequest(clusterRequest);
            log.info("✅ OpenSearch cluster reachable: {}", clusterResponse.getStatusLine());
        } catch (Exception e) {
            log.error("❌ OpenSearch cluster unreachable: {}", e.getMessage());
            throw new RuntimeException("OpenSearch cluster unreachable", e);
        }

        // Test ISM plugin - try both new and legacy paths
        try {
            Request ismRequest = new Request("GET", "_plugins/_ism");
            Response ismResponse = client.getLowLevelClient().performRequest(ismRequest);
            log.info("✅ ISM plugin available at /_plugins/_ism: {}", ismResponse.getStatusLine());
            return true;
        } catch (Exception e) {
            log.warn("⚠️ ISM not available at /_plugins/_ism, trying legacy path...");
            try {
                Request legacyRequest = new Request("GET", "_opendistro/_ism");
                Response legacyResponse = client.getLowLevelClient().performRequest(legacyRequest);
                log.info("✅ ISM plugin available at /_opendistro/_ism: {}", legacyResponse.getStatusLine());
                return true;
            } catch (Exception e2) {
                log.warn("⚠️ ISM plugin not available at either path - continuing without lifecycle management");
                return false;
            }
        }
    }

    private void doCreatePolicy(String policyId, Integer ttl, String policyJson) {
        try {
            log.info("➡️ Creating ISM policy with ID: {} and TTL: {}d", policyId, ttl);
            log.trace("ISM Policy JSON being sent:\n{}", policyJson);

            Request createRequest = new Request("PUT", "_plugins/_ism/policies/" + policyId);
            createRequest.setJsonEntity(policyJson);

            RequestOptions.Builder optionsBuilder = RequestOptions.DEFAULT.toBuilder();
            optionsBuilder.addHeader("Content-Type", "application/json");
            RequestOptions requestOptions = optionsBuilder.build();

            // Log AWS signing details
            log.trace("Request URI: {}", createRequest.getEndpoint());
            log.trace("Request method: {}", createRequest.getMethod());
            log.trace("Request entity: {}", createRequest.getEntity() != null ? "present" : "null");
            log.trace("Request options: {}", createRequest.getOptions());

            // Log headers if available
            if (requestOptions.getHeaders() != null) {
                requestOptions.getHeaders().forEach(header ->
                    log.trace("Request header: {} = {}", header.getName(),
                        header.getName().toLowerCase().contains("auth") ? "[REDACTED]" : header.getValue())
                );
            } else {
                log.trace("No custom headers set on request");
            }

            createRequest.setOptions(requestOptions);
            Response createResponse = client.getLowLevelClient().performRequest(createRequest);
            log.info("✅ Created policy {} -> response = {}", policyId, createResponse.getStatusLine());
        } catch (Exception e) {
            log.error("❌ Failed to create ISM policy {} with TTL {}d: {}", policyId, ttl, e.getMessage(), e);

            // Log response body if it's a ResponseException to see the actual error
            if (e instanceof org.opensearch.client.ResponseException responseException) {
                try {
                    String responseBody = new String(responseException.getResponse().getEntity().getContent().readAllBytes());
                    log.error("❌ OpenSearch response body: {}", responseBody);
                } catch (Exception bodyException) {
                    log.error("❌ Could not read response body: {}", bodyException.getMessage());
                }
            }
        }
    }

    @SneakyThrows
    private long getSeqNo(Response response) {
        String responseBody = new String(response.getEntity().getContent().readAllBytes());
        return Long.parseLong(responseBody.split("\"_seq_no\":")[1].split(",")[0]);
    }

    @SneakyThrows
    private long getPrimaryTerm(Response response) {
        String responseBody = new String(response.getEntity().getContent().readAllBytes());
        return Long.parseLong(responseBody.split("\"_primary_term\":")[1].split(",")[0]);
    }

    @SneakyThrows
    public void createIndexTemplate(String indexPrefix, String policyId) {
        String templateJson = new String(this.getClass().getResourceAsStream("/opensearch/audit_index_template.json").readAllBytes())
                .replace("${index_pattern}", indexPrefix+"*")
                .replace("${policy_id}", policyId);

        Request request = new Request("PUT", "_index_template/"+indexPrefix+"_template");
        request.setJsonEntity(templateJson);

        Response response = client.getLowLevelClient().performRequest(request);
        log.debug("Created template {} -> response = {}", indexPrefix, response.getStatusLine());
    }

    @SneakyThrows
    private void attachWriteAlias(String indexName, String aliasWrite, String indexPrefix) {
        // First try to remove the alias from previous indices (ignore if it doesn't exist)
        try {
            IndicesAliasesRequest removeRequest = new IndicesAliasesRequest();
            removeRequest.addAliasAction(new IndicesAliasesRequest.AliasActions(IndicesAliasesRequest.AliasActions.Type.REMOVE)
                    .index(indexPrefix + "-*")
                    .alias(aliasWrite));
            client.indices().updateAliases(removeRequest, RequestOptions.DEFAULT);
        } catch (Exception e) {
            log.debug("No previous alias to remove for {}: {}", aliasWrite, e.getMessage());
        }

        // Always add write alias to the current index as the write index
        IndicesAliasesRequest addRequest = new IndicesAliasesRequest();
        addRequest.addAliasAction(new IndicesAliasesRequest.AliasActions(IndicesAliasesRequest.AliasActions.Type.ADD)
                .index(indexName)
                .alias(aliasWrite)
                .writeIndex(true));
        client.indices().updateAliases(addRequest, RequestOptions.DEFAULT);
    }

    @SneakyThrows
    private void attachReadAlias(String indexName, String aliasRead) {
        IndicesAliasesRequest request = new IndicesAliasesRequest();
        request.addAliasAction(new IndicesAliasesRequest.AliasActions(IndicesAliasesRequest.AliasActions.Type.ADD)
                .index(indexName)
                .alias(aliasRead));
        client.indices().updateAliases(request, RequestOptions.DEFAULT);
    }
}
