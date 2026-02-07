# Architecture Guide - Kockpit Client Monorepo

This document provides a detailed technical architecture overview of the Kockpit audit trail system.

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [Storage Strategy](#storage-strategy)
5. [API Design](#api-design)
6. [Security Model](#security-model)
7. [Scalability & Performance](#scalability--performance)
8. [Deployment Patterns](#deployment-patterns)

---

## System Overview

The Kockpit client system is a distributed audit trail management platform consisting of:

- **Infrastructure Layer**: OpenSearch + Kafka (Docker containers)
- **Backend Layer**: REST API for audit storage and search
- **Application Layer**: Demo e-commerce app with automatic audit capture

### Technology Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Application** | Spring Boot | 3.4.3 | Business logic |
| **Language** | Java | 21 | Application development |
| **Build** | Maven | 3.8+ | Dependency management |
| **Search** | OpenSearch | 3.3.2 | Full-text search & analytics |
| **Streaming** | Apache Kafka | latest | Event streaming (optional) |
| **Containers** | Docker | latest | Infrastructure |
| **Security** | Spring Security | 6.4.3 | Authentication/Authorization |

---

## Component Architecture

### 1. Infrastructure Layer (os-kafka/)

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┐      ┌──────────────────────┐     │
│  │   OpenSearch        │      │  OpenSearch          │     │
│  │   localhost:9200    │◄─────┤  Dashboards          │     │
│  │                     │      │  localhost:5601      │     │
│  │  • Full-text search │      │  • Web UI            │     │
│  │  • Multi-tenant     │      │  • Visualizations    │     │
│  │  • TTL-based index  │      │  • Dashboard builder │     │
│  └─────────────────────┘      └──────────────────────┘     │
│                                                              │
│  ┌─────────────────────┐                                    │
│  │   Apache Kafka      │                                    │
│  │   localhost:9092    │                                    │
│  │                     │                                    │
│  │  • Event streaming  │                                    │
│  │  • Message buffer   │                                    │
│  │  • Topic: "audits"  │                                    │
│  └─────────────────────┘                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Features**:
- **OpenSearch**: Elasticsearch-compatible search engine
- **OpenSearch Dashboards**: Kibana-compatible visualization tool
- **Kafka**: Optional streaming layer for high-volume scenarios
- **Docker Compose**: Single-command infrastructure deployment

### 2. Backend Layer (kockpit-backend-application/)

```
┌─────────────────────────────────────────────────────────────┐
│           kockpit-backend-application (Port 8080)            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │               REST Controllers                      │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  • SearchApi     - /{domain}/{env}/audits         │     │
│  │  • DashboardApi  - /{domain}/{env}/dashboard      │     │
│  │  • Me            - /me (authentication)           │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │               Service Layer                         │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  • SearchService     - Query processing           │     │
│  │  • DashboardService  - Aggregations               │     │
│  │  • ConfigService     - Configuration management   │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │               Repository Layer                      │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  • OpensearchRepository  (Primary)                 │     │
│  │  • FileSystemRepository  (Config/Manifest)         │     │
│  │  • AzureRepository       (Optional, via profiles)  │     │
│  │  • S3Repository          (Optional, via profiles)  │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Hexagonal Architecture (Ports & Adapters)**:

- **Ports** (Interfaces): Define business contracts
  - `SearchService`
  - `StorageService`
  - `ConfigApiService`

- **Adapters** (Implementations): Infrastructure-specific
  - `OpensearchRepository` → OpenSearch
  - `FileSystemRepository` → Local disk
  - `AzureRepository` → Azure Storage
  - `S3Repository` → AWS S3

**Configuration Profiles**:

| Profile | Purpose | Dependencies |
|---------|---------|--------------|
| `opensearch` | Search & storage | `kockpit-backend-service-search-opensearch` |
| `filesystem` | Config/manifest | `kockpit-backend-service-storage-filesystem` |
| `azure` | Azure storage | `kockpit-backend-service-storage-azure` |
| `aws` | AWS S3 storage | `kockpit-backend-service-storage-s3` |

### 3. Application Layer (kockpit-demo-app/)

```
┌─────────────────────────────────────────────────────────────┐
│            kockpit-demo-app (Port 8091)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │        @Audited REST Controllers                    │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  ProductController  - /api/products                │     │
│  │  OrderController    - /api/orders                  │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          │ AOP Interception                  │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │          kockpit-audit-sdk (AOP)                    │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  • Intercepts @Audited methods                     │     │
│  │  • Captures request/response                       │     │
│  │  • Extracts @AuditAttribute parameters             │     │
│  │  • Builds AuditReport                              │     │
│  │  • Sends to backend (HTTP or Kafka)                │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │           Business Services                         │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  ProductService  - Product CRUD logic              │     │
│  │  OrderService    - Order lifecycle management      │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │           In-Memory Repositories                    │     │
│  ├────────────────────────────────────────────────────┤     │
│  │  ProductRepository - ConcurrentHashMap             │     │
│  │  OrderRepository   - ConcurrentHashMap             │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Audit Annotation Example**:

```java
@RestController
@RequestMapping("/api/products")
@Audited  // ← All methods auto-audited
public class ProductController {

    @PostMapping
    public ApiResponse<Product> createProduct(
        @RequestBody @AuditAttribute(key = "product") Product product
    ) {
        // Business logic
        // Audit automatically captured and sent
    }
}
```

---

## Data Flow

### Flow 1: Direct HTTP Mode (No Kafka)

```
┌──────────────┐
│   Client     │
│  (Browser/   │
│   Postman)   │
└──────┬───────┘
       │ 1. HTTP POST /api/products
       ▼
┌──────────────────────┐
│ Demo App (8091)      │
│ ProductController    │
│   @Audited           │
└──────┬───────────────┘
       │ 2. AOP intercepts
       ▼
┌──────────────────────┐
│ kockpit-audit-sdk    │
│ Builds AuditReport   │
└──────┬───────────────┘
       │ 3. HTTP POST
       │    /demo/local/audits
       ▼
┌──────────────────────┐
│ Backend API (8080)   │
│ SearchApi            │
└──────┬───────────────┘
       │ 4. Index document
       ▼
┌──────────────────────┐
│ OpenSearch (9200)    │
│ Index:               │
│ demo-audit-data-     │
│   local-ttl5d        │
└──────────────────────┘
```

**Sequence Diagram**:

```
Client → DemoApp: POST /api/products {data}
DemoApp → AuditSDK: @Audited intercepted
AuditSDK → Backend: POST /demo/local/audits {audit}
Backend → OpenSearch: BulkIndex {audit}
Backend → Client: 201 Created
DemoApp → Client: 200 OK {product}
```

### Flow 2: Kafka Streaming Mode

```
┌──────────────┐
│   Client     │
└──────┬───────┘
       │ 1. HTTP POST
       ▼
┌──────────────────────┐
│ Demo App (8091)      │
│   @Audited           │
└──────┬───────────────┘
       │ 2. AOP intercepts
       ▼
┌──────────────────────┐
│ kockpit-audit-sdk    │
│ KafkaProducer        │
└──────┬───────────────┘
       │ 3. Send to topic "audits"
       ▼
┌──────────────────────┐
│ Kafka Broker (9092)  │
│ Topic: audits        │
└──────┬───────────────┘
       │ 4. Consumer polls
       ▼
┌──────────────────────┐
│ Stream Consumer      │
│ (Not in this repo)   │
│ Batches events       │
└──────┬───────────────┘
       │ 5. Bulk index every 5s
       ▼
┌──────────────────────┐
│ OpenSearch (9200)    │
└──────────────────────┘
```

**Benefits of Kafka Mode**:
- ✅ **Decoupled**: App doesn't wait for indexing
- ✅ **Buffer**: Absorbs traffic spikes
- ✅ **Scalable**: Multiple consumers for load distribution
- ✅ **Reliable**: Kafka persistence prevents data loss

---

## Storage Strategy

### OpenSearch Index Design

**Index Naming Convention**:
```
{domain}-audit-data-{env}-ttl{X}d-{date}

Examples:
- demo-audit-data-local-ttl5d-2026-02-07
- prod-audit-data-prod-ttl30d-2026-02-07
- staging-audit-data-staging-ttl15d-2026-02-07
```

**Index Structure**:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "domain": "demo",
  "env": "local",
  "appId": "demo-app",
  "artifact": "kockpit-demo-app",
  "version": "1.0.0-SNAPSHOT",
  "hostname": "localhost",
  "start": "2026-02-07T19:00:00.000Z",
  "end": "2026-02-07T19:00:01.234Z",
  "ttl": 5,
  "request": {
    "method": "POST",
    "uri": "/api/products",
    "headers": {
      "Content-Type": "application/json",
      "User-Agent": "curl/7.68.0"
    },
    "body": "{\"name\":\"Laptop\",\"price\":999.99}"
  },
  "response": {
    "status": 201,
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "{\"id\":\"prod-123\",\"name\":\"Laptop\"...}"
  },
  "indexedKeyValues": [
    {
      "key": "product",
      "value": "{...}",
      "valueInteger": null,
      "valueBoolean": null,
      "valueDecimal": null
    },
    {
      "key": "duration",
      "value": null,
      "valueInteger": 1234,
      "valueBoolean": null,
      "valueDecimal": null
    }
  ],
  "events": [
    {
      "event": "PRODUCT_CREATED",
      "message": "Product 'Laptop' created",
      "timestamp": "2026-02-07T19:00:01.000Z"
    }
  ]
}
```

**Mapping (Elasticsearch/OpenSearch)**:

```json
{
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "domain": { "type": "keyword" },
      "env": { "type": "keyword" },
      "appId": { "type": "keyword" },
      "start": { "type": "date" },
      "end": { "type": "date" },
      "request.method": { "type": "keyword" },
      "request.uri": { "type": "text", "fields": {"keyword": {"type": "keyword"}} },
      "request.body": { "type": "text" },
      "response.status": { "type": "integer" },
      "indexedKeyValues": { "type": "nested" }
    }
  }
}
```

### TTL-Based Index Rotation

**Strategy**: Create daily indexes with TTL suffix

**Lifecycle**:
1. Daily index created: `demo-audit-data-local-ttl5d-2026-02-07`
2. Data written for 24 hours
3. After 5 days, index eligible for deletion
4. Background job (manual or ILM) deletes old indexes

**Benefits**:
- 📉 **Reduced storage**: Auto-cleanup old data
- ⚡ **Better performance**: Smaller indexes = faster queries
- 🔍 **Time-based search**: Easy to query specific date ranges

### Multi-Tenancy

**Isolation by Domain + Environment**:

```
URL:   /{domain}/{env}/audits
Index: {domain}-audit-data-{env}-ttl{X}d-{date}

Examples:
- /demo/local/audits     → demo-audit-data-local-*
- /prod/prod/audits      → prod-audit-data-prod-*
- /client1/dev/audits    → client1-audit-data-dev-*
```

**Benefits**:
- 🔒 **Data isolation**: Each tenant has separate indexes
- 🎯 **Fine-grained access**: Control per domain/env
- 📊 **Custom TTL**: Different retention per tenant

---

## API Design

### REST Principles

- **Resource-Oriented**: URLs represent resources (audits, dashboard)
- **HTTP Methods**: GET (read), POST (create), PUT (update), DELETE (delete)
- **Status Codes**: 200 (OK), 201 (Created), 400 (Bad Request), 401 (Unauthorized), 404 (Not Found)
- **Content-Type**: `application/json`

### URL Structure

```
Base: /backend/api

Pattern: /{domain}/{env}/{resource}

Examples:
- GET    /demo/local/audits/_search
- GET    /demo/local/audits/{id}
- POST   /demo/local/audits
- GET    /demo/local/dashboard
- GET    /me
```

### Authentication

**HTTP Basic Auth**:
```bash
curl -u user:password \
  "http://localhost:8080/backend/api/demo/local/audits/_search"
```

**Header Format**:
```
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

### Request/Response Examples

**Search Audits**:
```bash
GET /demo/local/audits/_search?start=0&size=10

Response 200 OK:
[
  {
    "id": "audit-123",
    "domain": "demo",
    "env": "local",
    "start": "2026-02-07T19:00:00Z",
    ...
  }
]
```

**Get Audit by ID**:
```bash
GET /demo/local/audits/audit-123

Response 200 OK:
{
  "id": "audit-123",
  "domain": "demo",
  "request": {...},
  "response": {...}
}
```

---

## Security Model

### Authentication

- **Method**: HTTP Basic Authentication
- **Default Credentials**: `user` / `password` (for demo)
- **Production**: Use strong passwords, consider OAuth2/JWT

### Authorization

Currently **role-based** via Spring Security:

```java
@Configuration
public class SecurityConfig {
    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .httpBasic();
    }
}
```

### Data Encryption

- **In-Transit**: HTTPS (recommended for production)
- **At-Rest**: OpenSearch encryption (via configuration)

### Audit Data Sensitivity

**Obfuscation Support** (via Kockpit library):
- PII fields can be obfuscated before storage
- Configurable obfuscation rules
- See: `kockpit-obfuscation` module

---

## Scalability & Performance

### Horizontal Scaling

**Backend API**:
- Run multiple instances behind load balancer
- Stateless design (no session affinity needed)
- Shared OpenSearch cluster

**Kafka Consumers** (if using Kafka):
- Consumer groups for parallel processing
- Partition-based load distribution
- Scale consumers based on lag

### Vertical Scaling

- Increase JVM heap: `-Xmx` / `-Xms`
- Optimize OpenSearch queries (filters, aggregations)
- Use connection pools for OpenSearch clients

### Performance Optimizations

**Backend**:
- Async audit sending (non-blocking)
- Bulk indexing (batch operations)
- Query result caching (optional)

**OpenSearch**:
- Shard optimization (number of shards per index)
- Replica count (read performance vs storage)
- Index refresh interval tuning

**Kafka** (if enabled):
- Batch producer settings (linger.ms, batch.size)
- Compression (snappy, gzip)
- Consumer fetch.min.bytes optimization

---

## Deployment Patterns

### Pattern 1: Single-Node Development

```
[Laptop/Desktop]
├── Docker (OpenSearch + Kafka)
├── Backend (IDE or mvn spring-boot:run)
└── Demo App (IDE or mvn spring-boot:run)
```

**Use Case**: Local development, testing

### Pattern 2: Docker Compose All-in-One

```yaml
version: '3.8'
services:
  opensearch:
    # ...
  kafka:
    # ...
  backend:
    build: ./kockpit-backend-application
    depends_on: [opensearch]
  demo-app:
    build: ./kockpit-demo-app
    depends_on: [backend]
```

**Use Case**: Integration testing, staging

### Pattern 3: Kubernetes Production

```
[Kubernetes Cluster]
├── OpenSearch (StatefulSet)
├── Kafka (StatefulSet)
├── Backend (Deployment, replicas: 3)
└── Demo App (Deployment, replicas: 2)
```

**Use Case**: Production, high availability

### Pattern 4: Cloud-Managed Services

```
├── AWS OpenSearch Service
├── AWS MSK (Managed Kafka)
├── Backend (ECS/EKS)
└── Demo App (ECS/EKS)
```

**Use Case**: Fully managed, enterprise production

---

## Conclusion

This architecture provides:

✅ **Flexibility**: Choose HTTP direct or Kafka streaming
✅ **Scalability**: Horizontal scaling at all layers
✅ **Multi-Tenancy**: Domain/environment isolation
✅ **Observability**: Comprehensive audit trail
✅ **Developer-Friendly**: Annotation-based, zero boilerplate

For implementation details, see:
- **Quick Start**: `README.md`
- **Troubleshooting**: `kockpit-demo-app/kockpit-doc/BUILD-TROUBLESHOOTING.txt`
- **Kafka Guide**: `kockpit-demo-app/kockpit-doc/KAFKA-QUICK-START.txt`
