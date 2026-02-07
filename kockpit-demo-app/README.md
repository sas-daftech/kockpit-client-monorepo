# Kockpit Demo Application

Demo Spring Boot application showcasing the integration of **kockpit-audit-sdk** for automatic audit trail generation.

## Features

- ✅ RESTful API for Product management (CRUD)
- ✅ RESTful API for Order management (lifecycle tracking)
- ✅ Automatic audit logging via `@Audited` annotations
- ✅ Integration with kockpit-backend for audit storage and search
- ✅ Multi-environment configuration (local, dev, prod)

## Quick Start

### Prerequisites

- Java 17+
- Maven 3.9+
- Kockpit backend running on `http://localhost:8080`
- OpenSearch running on `http://localhost:9200`

### Build the project

```bash
cd /home/debian/sources/kiss/kockpit-demo-app
mvn clean package
```

### Run the application

```bash
# With local profile (default)
mvn spring-boot:run

# Or with IntelliJ IDEA
# Create run configuration with:
# - Main class: com.kockpit.demo.DemoApplication
# - Active profiles: local
```

### Test the API

```bash
# List products
curl http://localhost:8091/demo/api/api/products

# Create a product
curl -X POST http://localhost:8091/demo/api/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "price": 999.99,
    "stock": 10
  }'

# Create an order
curl -X POST http://localhost:8091/demo/api/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [
      {
        "productId": "prod-1",
        "productName": "Laptop",
        "quantity": 2,
        "price": 999.99
      }
    ],
    "total": 1999.98
  }'
```

### View audits

```bash
# Search audits in kockpit-backend
curl -u user:password \
  "http://localhost:8080/backend/api/demo/local/audits/_search?start=0&size=10"
```

## Documentation

For complete documentation, see: `/home/debian/sources/kiss/kockpit-doc/DEMO-APP-GUIDE.txt`

## Architecture

- **Controllers**: REST endpoints with `@Audited` annotations
- **Services**: Business logic layer
- **Repositories**: In-memory storage (for demo purposes)
- **Models**: DTOs for Products, Orders, and API responses

## Configuration

Edit `src/main/resources/application-local.yaml` to configure:
- Kockpit backend URL
- Audit settings
- Logging levels

## License

Same as Kockpit project
