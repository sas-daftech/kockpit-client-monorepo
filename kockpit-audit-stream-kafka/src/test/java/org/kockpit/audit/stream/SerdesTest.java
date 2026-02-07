package org.kockpit.audit.stream;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.kockpit.audit.stream.api.model.AuditReport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.io.IOException;

@SpringBootTest
@ActiveProfiles("test")
@Disabled
public class SerdesTest {

    @Autowired
    ObjectMapper objectMapper;

    @Test
    void on_audit_json() throws IOException {
        AuditReport auditReport = objectMapper.readValue(this.getClass().getResourceAsStream("/audit.json"), AuditReport.class);
        Assertions.assertThat(auditReport).isNotNull();
        Assertions.assertThat(auditReport.getId()).isEqualTo("f945150f-dd07-42df-aa69-6696f75c395e");
        Assertions.assertThat(auditReport.getIndexedKeyValues()).hasSize(6);
        Assertions.assertThat(auditReport.getAudits()).hasSize(1);
        Assertions.assertThat(auditReport.getAudits().iterator().next().getType()).isEqualTo("builtin.web");
    }

}
