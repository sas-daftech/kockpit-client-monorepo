package org.kockpit.audit.stream.opensearch;

import lombok.Builder;
import lombok.Getter;
import lombok.ToString;
import org.kockpit.audit.stream.api.model.AuditReport;

import java.util.Objects;

@Getter
@Builder
@ToString
public class IndexMetadata {

    private String domain;

    private String env;

    private Integer ttl;

    public static IndexMetadata of(AuditReport auditReport) {
        return IndexMetadata.builder()
                .domain(auditReport.getDomain())
                .env(auditReport.getEnv())
                .ttl(auditReport.getTtl())
                .build();
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        IndexMetadata that = (IndexMetadata) o;
        return Objects.equals(domain, that.domain) &&
                Objects.equals(env, that.env) &&
                Objects.equals(ttl, that.ttl);
    }

    @Override
    public int hashCode() {
        return Objects.hash(domain, env, ttl);
    }
}
