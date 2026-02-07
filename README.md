# Kockpit Client Monorepo

> Full-stack audit trail management system with OpenSearch, Kafka streaming, and demo application

[![Java](https://img.shields.io/badge/Java-21-orange.svg)](https://openjdk.java.net/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.3-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![OpenSearch](https://img.shields.io/badge/OpenSearch-3.3.2-blue.svg)](https://opensearch.org/)
[![Kafka](https://img.shields.io/badge/Apache%20Kafka-latest-red.svg)](https://kafka.apache.org/)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## 🎯 Overview

This monorepo contains a complete audit trail management system based on the Kockpit platform. It demonstrates how to integrate, deploy, and use Kockpit's audit capabilities in a production-like environment.

### Components

| Component | Description | Port | Technology |
|-----------|-------------|------|------------|
| **os-kafka/** | Infrastructure (OpenSearch + Kafka) | 9200, 9092 | Docker Compose |
| **kockpit-backend-application/** | REST API for audit storage & search | 8080 | Spring Boot 3 |
| **kockpit-demo-app/** | Demo e-commerce application | 8091 | Spring Boot 3 |

### Key Features

- ✅ **Automatic Audit Capture**: Annotation-based (`@Audited`)
- 🔍 **Full-text Search**: Powered by OpenSearch
- 📊 **Real-time Dashboard**: Analytics and visualizations
- 🚀 **Event Streaming**: Kafka integration for scalability
- 🔒 **Multi-tenant**: Domain and environment isolation
- 🌐 **REST API**: Comprehensive search and query endpoints
- 📈 **Monitoring**: Spring Boot Actuator endpoints

## 🏗️ Architecture

**Current Mode: Kafka Streaming (Asynchronous)**

```
┌────────────────────────────────────────────────────────────────┐
│                   kockpit-demo-app                              │
│                   Port: 8091                                    │
│                   (@Audited annotations)                        │
└────────────────────────────────────────────────────────────────┘
                            │
                            │ Spring AOP intercepts
                            │ Kafka Producer sends audit events
                            ▼
                  ┌─────────────────┐
                  │     KAFKA       │
                  │  localhost:9092 │
                  │                 │
                  │  Topic: "audit" │
                  └─────────────────┘
                            │
                            │ Kafka Consumer reads batches
                            ▼
              ┌──────────────────────────────┐
              │ kockpit-audit-stream         │
              │ (Kafka Stream Consumer)      │
              │ Port: 9080                   │
              │                              │
              │ • Consumes from Kafka        │
              │ • Batches (max 50 messages)  │
              │ • Indexes every 5 seconds    │
              └──────────────────────────────┘
                            │
                            │ Bulk indexing
                            ▼
              ┌────────────────────────┐
              │      OPENSEARCH        │
              │    localhost:9200      │
              │                        │
              │ Multi-tenant indexes:  │
              │ {domain}-audit-data-   │
              │    {env}-ttl{X}d       │
              └────────────────────────┘
                            │
                            ▼
              ┌────────────────────────┐
              │  OpenSearch Dashboards │
              │    localhost:5601      │
              │  (Kibana-like UI)      │
              └────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  kockpit-backend-application (Optional - for manual queries)   │
│  Port: 8080                                                    │
│  • Audit Search API                                            │
│  • Dashboard Analytics                                         │
└────────────────────────────────────────────────────────────────┘
```

**Benefits of Kafka Streaming:**
- ✅ **Asynchronous**: No impact on application performance
- ✅ **Resilient**: Kafka guarantees message delivery
- ✅ **Scalable**: Can handle millions of audit events
- ✅ **Decoupled**: Applications and indexing are independent

## 📁 Project Structure

```
kockpit-client-monorepo/
├── os-kafka/                          # Infrastructure services
│   ├── docker-compose-dev.yml         # OpenSearch + Kafka + Dashboards
│   └── README.md                      # Infrastructure documentation
│
├── kockpit-audit-stream-kafka/        # Kafka Stream Consumer (NEW!)
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/org/kockpit/audit/stream/
│   │   │   └── resources/
│   │   │       ├── application.yml            # Base configuration
│   │   │       └── application-local.yml      # Local dev config
│   │   └── test/
│   ├── pom.xml                        # Maven dependencies
│   └── README.md                      # Stream consumer documentation
│
├── kockpit-backend-application/       # Backend API service (Optional)
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/org/kockpit/backend/
│   │   │   └── resources/
│   │   │       ├── application.yaml               # Base configuration
│   │   │       ├── application-opensearch.yaml    # OpenSearch config
│   │   │       └── application-filesystem.yaml    # Filesystem config
│   │   └── test/
│   ├── pom.xml                        # Maven dependencies
│   └── README.md                      # Backend documentation
│
├── kockpit-demo-app/                  # Demo e-commerce application
│   ├── src/
│   │   ├── main/java/com/kockpit/demo/
│   │   │   ├── controller/            # REST controllers (annotated with @Audited)
│   │   │   ├── service/               # Business logic
│   │   │   ├── repository/            # Data access (in-memory)
│   │   │   └── model/                 # Domain models
│   │   └── resources/
│   │       ├── application.yaml       # Application config (Kafka mode)
│   │       └── application-local.yaml # Local development config
│   ├── kockpit-doc/                   # Comprehensive documentation
│   │   ├── START-HERE.txt
│   │   ├── QUICK-START.txt
│   │   ├── ARCHITECTURE.txt
│   │   ├── BUILD-TROUBLESHOOTING.txt
│   │   └── KAFKA-QUICK-START.txt
│   ├── pom.xml
│   └── README.md                      # Demo app documentation
│
├── .gitignore                         # Git ignore rules
├── README.md                          # This file
├── ARCHITECTURE.md                    # Detailed architecture guide
├── SECURITY.md                        # Security best practices
└── LICENSE                            # License information
```

## 🔧 Prerequisites

### Required

- **Java 21** (OpenJDK or Amazon Corretto)
- **Maven 3.8+**
- **Docker Desktop** (or Docker Engine + Docker Compose)
- **Git**

### Recommended

- **IntelliJ IDEA** or **VS Code** with Java extensions
- **Postman** or **curl** for API testing
- **jq** for JSON formatting in CLI

### Installation

```bash
# Java 21 (using SDKMAN)
sdk install java 21.0.9-amzn
sdk use java 21.0.9-amzn

# Maven
sdk install maven 3.9.6

# Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Verify installations
java -version   # Should show 21.x.x
mvn -version    # Should show 3.8.x or higher
docker --version
docker compose version
```

## 🚀 Quick Start

### 1. Start Infrastructure

```bash
# Start OpenSearch, Kafka, and OpenSearch Dashboards
cd os-kafka
docker compose -f docker-compose-dev.yml up -d

# Verify services are running
curl http://localhost:9200        # OpenSearch
docker ps                         # Check all containers
```

**Services started:**
- Kafka: localhost:9092
- OpenSearch: localhost:9200
- OpenSearch Dashboards: localhost:5601

### 2. Start Kafka Stream Consumer

**Important:** This application consumes audit events from Kafka and indexes them to OpenSearch.

```bash
# Navigate to the kockpit-audit-stream-kafka module (in this monorepo)
cd kockpit-audit-stream-kafka

# Start the consumer
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Wait for: "Started KockpitStreamApplication in X.XXX seconds"
```

**Kafka Stream Consumer will be available at:** `http://localhost:9080`

Configuration:
- Kafka Consumer Group: `kockpit-audit-stream`
- Kafka Topic: `audit`
- OpenSearch: `http://localhost:9200`
- Batch size: 50 messages
- Index interval: Every 5 seconds

### 3. Start Demo Application

```bash
cd kockpit-demo-app

# Build and run
mvn clean compile
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Or from IntelliJ: Just run DemoApplication.java
```

**Demo app will be available at:** `http://localhost:8091/demo/api`

### 4. Test the System

```bash
# Create a product (auto-audited)
curl -X POST http://localhost:8091/demo/api/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","price":999.99,"stock":10}'

# Verify audit was sent to Kafka
# Check the kockpit-audit-stream console logs for:
# "indexing took X ms" - confirms the audit was indexed to OpenSearch

# View audits in OpenSearch Dashboards
open http://localhost:5601
# Create index pattern: demo-audit-data-*
# Time field: start

# Or query OpenSearch directly
curl "http://localhost:9200/*audit*/_search?pretty"
```

### Optional: Start Backend for Manual Queries

The backend API is **optional** in Kafka mode - it's only needed if you want to query audits via REST API instead of OpenSearch Dashboards.

```bash
cd kockpit-backend-application

# Build with both Maven profiles
mvn clean compile -Popensearch,filesystem

# Start backend API
mvn spring-boot:run -Popensearch,filesystem -Dspring-boot.run.profiles=opensearch,filesystem
```

**Backend will be available at:** `http://localhost:8080/backend/api`

## 📚 Detailed Setup

### Infrastructure Services

#### Start Services

```bash
cd os-kafka
docker compose -f docker-compose-dev.yml up -d
```

#### Verify Services

```bash
# OpenSearch (Elasticsearch-compatible search engine)
curl http://localhost:9200
# Expected: {"name":"opensearch-node1",...}

# OpenSearch Dashboards (Web UI)
open http://localhost:5601

# Kafka (Message broker)
docker exec -it os-kafka-kafka-1 kafka-topics --list --bootstrap-server localhost:9092
```

#### Stop Services

```bash
docker compose -f docker-compose-dev.yml down
# Add -v to also remove volumes (data will be lost)
```

### Backend Application

#### Configuration Files

**application.yaml** (Base configuration):
- Server port: 8080
- Context path: /backend/api
- SDK domain/env/appId

**application-opensearch.yaml**:
- OpenSearch endpoints with defaults
- Index configuration

**application-filesystem.yaml**:
- File system paths for manifests
- Communication settings

#### Maven Profiles

Must activate **both** profiles:

1. **opensearch**: Includes `kockpit-backend-service-search-opensearch` dependency
2. **filesystem**: Includes `kockpit-backend-service-storage-filesystem` dependency

#### IntelliJ Setup

1. **Maven Tool Window** → Profiles
2. ☑ **opensearch**
3. ☑ **filesystem**
4. Click **Reload All Maven Projects** 🔄
5. Run configuration: Add Spring profiles `opensearch,filesystem`

#### Build Commands

```bash
# Full build with tests
mvn clean install -Popensearch,filesystem

# Build without tests (faster)
mvn clean compile -Popensearch,filesystem

# Run
mvn spring-boot:run -Popensearch,filesystem \
  -Dspring-boot.run.profiles=opensearch,filesystem
```

### Demo Application

#### Features

- **Product Management**: CRUD operations on products
- **Order Management**: Order lifecycle (create, ship, deliver, cancel)
- **Automatic Auditing**: All controller methods annotated with `@Audited`

#### Endpoints

**Products** (`/api/products`):
- `GET /` - List all products
- `GET /{id}` - Get product by ID
- `POST /` - Create product
- `PUT /{id}` - Update product
- `DELETE /{id}` - Delete product

**Orders** (`/api/orders`):
- `GET /` - List all orders
- `GET /{id}` - Get order by ID
- `POST /` - Create order
- `POST /{id}/ship` - Ship order
- `POST /{id}/deliver` - Deliver order
- `POST /{id}/cancel` - Cancel order

#### Example Usage

```bash
# Create a product
curl -X POST http://localhost:8091/demo/api/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Laptop",
    "price": 1299.99,
    "stock": 5
  }'

# Create an order
curl -X POST http://localhost:8091/demo/api/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [
      {"productId": "prod-1", "quantity": 1, "price": 1299.99}
    ],
    "total": 1299.99
  }'

# Ship the order
curl -X POST http://localhost:8091/demo/api/api/orders/{orderId}/ship \
  -H "Content-Type: application/json" \
  -d '{"trackingNumber": "TRACK-123456"}'
```

## ⚙️ Configuration

### Environment Variables

```bash
# Infrastructure
export OPENSEARCH_ENDPOINTS=http://localhost:9200
export INDEX_NAME=kockpit-audit

# Kafka (already configured in docker-compose)
# No additional environment variables needed for demo

# Optional - if running backend API
export KOCKPIT_USERNAME=user
export KOCKPIT_PASSWORD=your_secure_password_here
# WARNING: Never commit actual passwords! Change for production!
```

### Application Properties

#### Demo App (application.yaml) - Kafka Mode

```yaml
spring:
  application:
    name: kockpit-demo-app
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer

kockpit:
  sdk:
    domain: demo                    # Application domain
    env: ${ENVIRONMENT:local}       # Environment (local, dev, prod)
    appId: demo-app                 # Application identifier
    enabled: true                   # Enable audit
    service:
      audit:
        notification:
          topic: audit              # Kafka topic for audit events

# Audits are sent to Kafka topic "audit" (asynchronous, no HTTP backend)
# kockpit-audit-stream-application-kafka consumes and indexes to OpenSearch
```

**Key Configuration Points:**
- **Kafka Bootstrap Server**: `localhost:9092`
- **Audit Topic**: `audit`
- **No HTTP Backend**: Audits go directly to Kafka
- **Domain/Env/AppId**: Used for OpenSearch index naming

#### Backend (application-opensearch.yaml) - Optional

```yaml
kockpit:
  audit:
    opensearch:
      index: ${INDEX_NAME:kockpit-audit}
      endpoints: ${OPENSEARCH_ENDPOINTS:http://localhost:9200}
  backend:
    opensearch:
      index: ${INDEX_NAME:kockpit-audit}
      endpoints: ${OPENSEARCH_ENDPOINTS:http://localhost:9200}
```

### Multi-tenant Setup

Audits are isolated by **domain** and **environment**:

```
URL Pattern: /{domain}/{env}/audits

Examples:
- /demo/local/audits    (Demo app in local environment)
- /demo/dev/audits      (Demo app in dev environment)
- /prod/prod/audits     (Production app in production)
```

OpenSearch indexes follow the pattern:
```
{domain}-audit-data-{env}-ttl{X}d-{date}

Examples:
- demo-audit-data-local-ttl5d-2026-02-07
- prod-audit-data-prod-ttl30d-2026-02-07
```

## 📖 API Documentation

### Backend API (port 8080)

**Base URL**: `http://localhost:8080/backend/api`

#### Authentication

All endpoints require HTTP Basic Auth:
- Username: Configured via environment variable
- Password: **MUST be set via `KOCKPIT_PASSWORD` environment variable**

**Security Warning**: The examples below use placeholder credentials. Always use environment variables and never commit real passwords to version control.

#### Audit Endpoints

**Search Audits**
```bash
GET /{domain}/{env}/audits/_search?start=0&size=10

curl -u user:password \
  "http://localhost:8080/backend/api/demo/local/audits/_search?start=0&size=10"
```

**Get Audit by ID**
```bash
GET /{domain}/{env}/audits/{id}

curl -u user:password \
  "http://localhost:8080/backend/api/demo/local/audits/{audit-id}"
```

**Create Audit**
```bash
POST /{domain}/{env}/audits

curl -u user:password \
  -X POST http://localhost:8080/backend/api/demo/local/audits \
  -H "Content-Type: application/json" \
  -d @audit-payload.json
```

#### Dashboard Endpoints

```bash
GET /{domain}/{env}/dashboard

curl -u user:password \
  "http://localhost:8080/backend/api/demo/local/dashboard"
```

### Swagger UI

Interactive API documentation is available at:

```
http://localhost:8080/backend/api/swagger-ui.html
```

## 📊 Monitoring

### Health Checks

```bash
# Backend health
curl http://localhost:8080/backend/api/backend/actuator/health

# Demo app health
curl http://localhost:8091/demo/api/actuator/health
```

### Metrics

```bash
# Backend metrics
curl http://localhost:8080/backend/api/backend/actuator/metrics

# Demo app metrics
curl http://localhost:8091/demo/api/actuator/metrics
```

### OpenSearch Dashboards

Access the web UI for data visualization:

```
http://localhost:5601
```

**Index Pattern**: `demo-audit-data-*`
**Time Field**: `start`

## 🐛 Troubleshooting

### Common Issues

#### 1. BuildProperties Bean Not Found

**Error**: `Parameter 1 of method auditor required a bean of type 'org.springframework.boot.info.BuildProperties'`

**Solution**:
```bash
cd kockpit-backend-application
mvn clean compile -Popensearch,filesystem
```

#### 2. ConfigApiService Bean Not Found

**Error**: `No qualifying bean of type 'org.kockpit.backend.services.storage.ConfigApiService'`

**Cause**: Maven profiles not activated

**Solution**:
- In IntelliJ: Activate **opensearch** + **filesystem** in Maven panel
- In CLI: Use `-Popensearch,filesystem` flag

#### 3. OpenSearch Connection Refused

**Error**: `Connection refused: localhost/127.0.0.1:9200`

**Solution**:
```bash
cd os-kafka
docker compose -f docker-compose-dev.yml up -d
curl http://localhost:9200  # Verify it's running
```

#### 4. Port Already in Use

**Error**: `Port 8080 is already in use`

**Solution**:
```bash
# Find process using port
lsof -i :8080

# Kill process
kill -9 <PID>

# Or change port in application.yaml
server:
  port: 8081
```

#### 5. Demo App Can't Reach Backend

**Symptom**: Audits not appearing in OpenSearch

**Checklist**:
- ✅ Backend running on port 8080?
- ✅ Credentials correct (user/password)?
- ✅ OpenSearch running?
- ✅ Network accessible (not blocked by firewall)?

**Test connectivity**:
```bash
curl -u user:password http://localhost:8080/backend/api/me
```

### Detailed Troubleshooting

See comprehensive guides in:
- `kockpit-demo-app/kockpit-doc/BUILD-TROUBLESHOOTING.txt`
- `kockpit-demo-app/kockpit-doc/KAFKA-TROUBLESHOOTING.txt`

## 📝 License

This project is part of the Kockpit platform demonstration.

## 🤝 Contributing

This is a demonstration repository. For contributions to the main Kockpit platform, please refer to the main Kockpit repository.

## 📧 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review documentation in `kockpit-demo-app/kockpit-doc/`
3. Check logs in the application console

## 🎓 Learning Resources

- **Quick Start**: `kockpit-demo-app/kockpit-doc/QUICK-START.txt`
- **Architecture Deep Dive**: `kockpit-demo-app/kockpit-doc/ARCHITECTURE.txt`
- **API Reference**: `kockpit-demo-app/kockpit-doc/API-REFERENCE.txt`
- **Kafka Integration**: `kockpit-demo-app/kockpit-doc/KAFKA-QUICK-START.txt`

---

**Built with ❤️ using the Kockpit Audit Platform**