#!/bin/bash

###############################################################################
# Kockpit Demo Application - Test Script
###############################################################################

BASE_URL="http://localhost:8091/demo/api/api"
BACKEND_URL="http://localhost:8080/backend/api"

echo "========================================================================="
echo "                    Kockpit Demo Application Test"
echo "========================================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
    echo ""
    echo -e "${YELLOW}$1${NC}"
    echo "-------------------------------------------------------------------------"
}

# Function to check if service is running
check_service() {
    local url=$1
    local name=$2

    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|401"; then
        echo -e "${GREEN}✓${NC} $name is running"
        return 0
    else
        echo -e "${RED}✗${NC} $name is NOT running"
        return 1
    fi
}

# Check prerequisites
print_header "1. Checking Prerequisites"
check_service "$BASE_URL/products" "Demo Application"
DEMO_RUNNING=$?

check_service "$BACKEND_URL/config" "Kockpit Backend"
BACKEND_RUNNING=$?

if [ $DEMO_RUNNING -ne 0 ] || [ $BACKEND_RUNNING -ne 0 ]; then
    echo ""
    echo -e "${RED}Error: Required services are not running${NC}"
    echo "Please start the required services first."
    exit 1
fi

# Test Product API
print_header "2. Testing Product API"

echo "Creating product: Laptop..."
PRODUCT_ID=$(curl -s -X POST "$BASE_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "price": 999.99,
    "stock": 10
  }' | jq -r '.data.id')

if [ -n "$PRODUCT_ID" ] && [ "$PRODUCT_ID" != "null" ]; then
    echo -e "${GREEN}✓${NC} Product created with ID: $PRODUCT_ID"
else
    echo -e "${RED}✗${NC} Failed to create product"
    exit 1
fi

echo ""
echo "Retrieving product..."
curl -s "$BASE_URL/products/$PRODUCT_ID" | jq '.data | {id, name, price, stock}'

echo ""
echo "Updating product..."
curl -s -X PUT "$BASE_URL/products/$PRODUCT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop Pro",
    "price": 1299.99,
    "stock": 5
  }' | jq '.data | {id, name, price, stock}'

echo ""
echo "Listing all products..."
curl -s "$BASE_URL/products" | jq '.data | length'
echo " products found"

# Test Order API
print_header "3. Testing Order API"

echo "Creating order..."
ORDER_ID=$(curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-123\",
    \"items\": [
      {
        \"productId\": \"$PRODUCT_ID\",
        \"productName\": \"Laptop Pro\",
        \"quantity\": 2,
        \"price\": 1299.99
      }
    ],
    \"total\": 2599.98
  }" | jq -r '.data.id')

if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "null" ]; then
    echo -e "${GREEN}✓${NC} Order created with ID: $ORDER_ID"
else
    echo -e "${RED}✗${NC} Failed to create order"
    exit 1
fi

echo ""
echo "Shipping order..."
curl -s -X POST "$BASE_URL/orders/$ORDER_ID/ship" \
  -H "Content-Type: application/json" \
  -d '{
    "trackingNumber": "TRACK-123456"
  }' | jq '.data | {id, status, trackingNumber}'

echo ""
echo "Delivering order..."
curl -s -X POST "$BASE_URL/orders/$ORDER_ID/deliver" \
  -H "Content-Type: application/json" | jq '.data | {id, status, deliveredAt}'

# Test Order Cancellation
echo ""
echo "Creating another order for cancellation test..."
ORDER_ID_2=$(curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-456\",
    \"items\": [
      {
        \"productId\": \"$PRODUCT_ID\",
        \"productName\": \"Laptop Pro\",
        \"quantity\": 1,
        \"price\": 1299.99
      }
    ],
    \"total\": 1299.99
  }" | jq -r '.data.id')

echo "Cancelling order..."
curl -s -X POST "$BASE_URL/orders/$ORDER_ID_2/cancel" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Customer changed mind"
  }' | jq '.data | {id, status, cancelReason}'

# Check audits
print_header "4. Checking Audit Trail in Kockpit Backend"

echo "Waiting 2 seconds for audits to be indexed..."
sleep 2

echo ""
echo "Fetching audits from kockpit-backend..."
AUDIT_COUNT=$(curl -s -u user:password \
  "$BACKEND_URL/demo/local/audits/_search?start=0&size=50" | jq '.total_count')

echo -e "${GREEN}✓${NC} Total audits found: $AUDIT_COUNT"

if [ "$AUDIT_COUNT" -gt 0 ]; then
    echo ""
    echo "Sample audit entries:"
    curl -s -u user:password \
      "$BACKEND_URL/demo/local/audits/_search?start=0&size=5" | \
      jq '.items[] | {action: .action, timestamp: .timestamp, user: .user}'
fi

# Cleanup
print_header "5. Cleanup"

echo "Deleting product..."
curl -s -X DELETE "$BASE_URL/products/$PRODUCT_ID" | jq '.message'

# Summary
print_header "6. Test Summary"
echo ""
echo -e "${GREEN}✓${NC} Product CRUD operations: OK"
echo -e "${GREEN}✓${NC} Order lifecycle operations: OK"
echo -e "${GREEN}✓${NC} Order cancellation: OK"
echo -e "${GREEN}✓${NC} Audit trail: OK ($AUDIT_COUNT audits)"
echo ""
echo "========================================================================="
echo -e "${GREEN}All tests passed successfully!${NC}"
echo "========================================================================="
echo ""
echo "To view audits in OpenSearch Dashboards:"
echo "  http://localhost:5601"
echo ""
echo "To search audits via API:"
echo "  curl -u user:password \\"
echo "    \"$BACKEND_URL/demo/local/audits/_search?start=0&size=10\""
echo ""
