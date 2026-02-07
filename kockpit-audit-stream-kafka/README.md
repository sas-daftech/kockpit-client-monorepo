# Kockpit Audit Stream - Kafka Consumer

Kafka consumer application that reads audit events from Kafka topic and indexes them to OpenSearch.

## Overview

This module is part of the kockpit-client-monorepo and provides the Kafka → OpenSearch streaming pipeline for audit events.

**Flow**:
```
kockpit-demo-app → Kafka topic "audit" → THIS APPLICATION → OpenSearch
```

## Configuration

The application is pre-configured for local development in `application-local.yml`:

- **Server Port**: 9080
- **Management Port**: 9081
- **Kafka Topic**: `audit` (matches kockpit-demo-app)
- **Kafka Bootstrap Servers**: `localhost:9092`
- **OpenSearch**: `http://localhost:9200`
- **Consumer Group**: `kockpit-audit-stream`
- **Batch Size**: 50 messages max
- **Index Interval**: Every 5 seconds
- **Domain**: `demo`
- **Environment**: `local`
- **TTL**: 5 days

## Prerequisites

1. **Kockpit platform installed** in local Maven repository:
   ```bash
   cd /home/gbonaventure/sources/kiss/kockpit
   mvn clean install -DskipTests
   ```

2. **Infrastructure running**:
   ```bash
   cd ../os-kafka
   docker compose -f docker-compose-dev.yml up -d
   ```

## Running

### From Command Line

```bash
# Navigate to this directory
cd kockpit-audit-stream-kafka

# Run with local profile
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Wait for startup message
# "Started KockpitStreamApplication in X.XXX seconds"
```

### From IntelliJ IDEA

1. Open `KockpitStreamApplication.java`
2. Right-click → Run
3. Edit Run Configuration:
   - Add VM options: `-Dspring.profiles.active=local`
   - Or set environment variable: `SPRING_PROFILES_ACTIVE=local`

## Verifying

### Health Check

```bash
curl http://localhost:9080/actuator/health
```

Expected response:
```json
{"status":"UP"}
```

### Metrics

```bash
curl http://localhost:9080/actuator/metrics
```

### Logs

Watch the console for messages like:
```
INFO  o.k.a.s.o.AuditConsumerForOpensearch - indexing took 123 ms
```

This confirms audits are being consumed from Kafka and indexed to OpenSearch.

## How It Works

1. **Kafka Consumer** listens to topic `audit`
2. **Batch Processing**: Collects up to 50 messages per poll
3. **Transformation**: Maps Kafka messages to OpenSearch documents
4. **Buffering**: Accumulates documents in memory
5. **Scheduled Indexing**: Every 5 seconds, bulk-indexes to OpenSearch
6. **Index Management**: Creates daily indices with pattern:
   ```
   {domain}-audit-data-{env}-ttl{X}d-{date}
   Example: demo-audit-data-local-ttl5d-2026-02-07-1
   ```

## Troubleshooting

### Application won't start - "Cannot find kockpit dependencies"

**Solution**: Install Kockpit platform to local Maven repository:
```bash
cd /home/gbonaventure/sources/kiss/kockpit
mvn clean install -DskipTests
```

### No messages consumed from Kafka

**Check**:
1. Kafka is running: `docker ps | grep kafka`
2. Topic exists:
   ```bash
   docker exec -it os-kafka-kafka-1 kafka-topics --list --bootstrap-server localhost:9092
   ```
3. Demo app is running and sending audits
4. Topic name matches in both applications (should be `audit`)

### OpenSearch connection refused

**Check**:
1. OpenSearch is running: `curl http://localhost:9200`
2. Endpoint URL is correct in `application-local.yml`

### Port 9080 already in use

**Solution**: Change port in `application-local.yml`:
```yaml
server:
  port: 9090  # Or any available port
```

## Configuration Reference

### Environment Variables (Optional)

You can override configuration with environment variables:

```bash
export BOOTSTRAP_SERVERS=localhost:9092
export OPENSEARCH_ENDPOINTS=http://localhost:9200
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

### Application Properties

See `src/main/resources/application-local.yml` for all configuration options.

Key properties:
- `kockpit.audit.stream.kafka.topics` - Kafka topic to consume
- `kockpit.audit.stream.opensearch.endpoints` - OpenSearch URL
- `kockpit.audit.stream.opensearch.scheduler_ms` - Index interval
- `spring.kafka.consumer.max-poll-records` - Batch size

## Development

### Building

```bash
mvn clean package
```

### Running Tests

```bash
mvn test
```

### Building Docker Image (Future)

```bash
mvn clean package
docker build -t kockpit-audit-stream-kafka:latest .
```

## Dependencies

This module depends on the following Kockpit libraries (from local Maven repository):
- `kockpit-audit-stream-api`
- `kockpit-audit-stream-starter-kafka`
- `kockpit-features-audit-starters-kafka`

Make sure these are installed via `mvn install` in the main kockpit project.

## Integration with Demo App

The demo app (`kockpit-demo-app`) is configured to send audits to Kafka topic `audit`.
This application consumes from that topic and indexes to OpenSearch.

**Complete flow**:
1. User calls demo app API endpoint (annotated with `@Audited`)
2. Demo app sends audit event to Kafka topic `audit`
3. **This application** consumes from topic `audit`
4. **This application** batches and indexes to OpenSearch
5. View results in OpenSearch Dashboards or Backend API

## Monitoring

### Key Metrics to Watch

- **Kafka Consumer Lag**: How far behind the consumer is
- **Indexing Rate**: Documents indexed per second
- **OpenSearch Health**: Cluster status
- **Error Rate**: Failed indexing attempts

### Log Levels

Adjust in `application-local.yml`:
```yaml
logging:
  level:
    org.kockpit.audit.stream: DEBUG  # Detailed streaming logs
    org.apache.kafka: INFO           # Kafka client logs
    org.opensearch: WARN             # OpenSearch client logs
```

## See Also

- Main monorepo README: `../README.md`
- Demo application: `../kockpit-demo-app/`
- Kafka quick start: `../kockpit-demo-app/kockpit-doc/KAFKA-QUICK-START.txt`