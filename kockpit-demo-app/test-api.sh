#!/bin/bash

###############################################################################
# Kockpit Demo Application - API Test Script
#
# Ce script teste l'API de démonstration avec des appels curl
# et génère automatiquement des audits dans le backend Kockpit
###############################################################################

set -e  # Exit on error

# Configuration
DEMO_URL="http://localhost:8091/demo/api/api"
BACKEND_URL="http://localhost:8080/backend/api"
BACKEND_USER="user"
BACKEND_PASS="password"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

###############################################################################
# Fonctions utilitaires
###############################################################################

print_banner() {
    echo ""
    echo "========================================================================="
    echo -e "${CYAN}$1${NC}"
    echo "========================================================================="
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}>>> $1${NC}"
    echo "-------------------------------------------------------------------------"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_service() {
    local url=$1
    local name=$2

    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|401"; then
        print_success "$name est accessible"
        return 0
    else
        print_error "$name n'est pas accessible à $url"
        return 1
    fi
}

wait_seconds() {
    local seconds=$1
    local message=$2
    echo -n "$message"
    for i in $(seq 1 $seconds); do
        echo -n "."
        sleep 1
    done
    echo " OK"
}

###############################################################################
# Tests
###############################################################################

print_banner "🚀 KOCKPIT DEMO - JEU DE TESTS API"

# Vérification des prérequis
print_section "1. Vérification des services"

check_service "$DEMO_URL/products" "Demo Application"
DEMO_OK=$?

check_service "$BACKEND_URL/config" "Kockpit Backend"
BACKEND_OK=$?

if [ $DEMO_OK -ne 0 ] || [ $BACKEND_OK -ne 0 ]; then
    echo ""
    print_error "Services requis non disponibles. Arrêt."
    exit 1
fi

###############################################################################
# SCÉNARIO 1: Gestion des produits
###############################################################################

print_banner "📦 SCÉNARIO 1: GESTION DES PRODUITS"

# 1.1 - Créer des produits
print_section "1.1 - Création de produits"

echo "Création du produit: Laptop Dell XPS 15..."
LAPTOP_RESPONSE=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop Dell XPS 15",
    "price": 1899.99,
    "stock": 15
  }')
LAPTOP_ID=$(echo "$LAPTOP_RESPONSE" | jq -r '.data.id')
print_success "Produit créé - ID: $LAPTOP_ID"

echo "Création du produit: iPhone 15 Pro..."
IPHONE_RESPONSE=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "iPhone 15 Pro",
    "price": 1299.99,
    "stock": 25
  }')
IPHONE_ID=$(echo "$IPHONE_RESPONSE" | jq -r '.data.id')
print_success "Produit créé - ID: $IPHONE_ID"

echo "Création du produit: Samsung Galaxy S24..."
SAMSUNG_RESPONSE=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Samsung Galaxy S24",
    "price": 999.99,
    "stock": 30
  }')
SAMSUNG_ID=$(echo "$SAMSUNG_RESPONSE" | jq -r '.data.id')
print_success "Produit créé - ID: $SAMSUNG_ID"

echo "Création du produit: AirPods Pro..."
AIRPODS_RESPONSE=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AirPods Pro",
    "price": 249.99,
    "stock": 50
  }')
AIRPODS_ID=$(echo "$AIRPODS_RESPONSE" | jq -r '.data.id')
print_success "Produit créé - ID: $AIRPODS_ID"

echo "Création du produit: MacBook Air M3..."
MACBOOK_RESPONSE=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MacBook Air M3",
    "price": 1499.99,
    "stock": 12
  }')
MACBOOK_ID=$(echo "$MACBOOK_RESPONSE" | jq -r '.data.id')
print_success "Produit créé - ID: $MACBOOK_ID"

# 1.2 - Lister tous les produits
print_section "1.2 - Liste de tous les produits"

PRODUCTS=$(curl -s "$DEMO_URL/products")
PRODUCT_COUNT=$(echo "$PRODUCTS" | jq '.data | length')
print_info "Nombre de produits: $PRODUCT_COUNT"
echo "$PRODUCTS" | jq '.data[] | {id, name, price, stock}'

# 1.3 - Récupérer un produit spécifique
print_section "1.3 - Récupération d'un produit spécifique"

echo "Récupération du produit: $LAPTOP_ID"
curl -s "$DEMO_URL/products/$LAPTOP_ID" | jq '.data'

# 1.4 - Mise à jour d'un produit
print_section "1.4 - Mise à jour de produits"

echo "Mise à jour du prix du Laptop (réduction)..."
curl -s -X PUT "$DEMO_URL/products/$LAPTOP_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop Dell XPS 15 (PROMO)",
    "price": 1699.99,
    "stock": 15
  }' | jq '.data | {id, name, price, stock}'
print_success "Prix mis à jour"

echo "Mise à jour du stock d'iPhone (réassort)..."
curl -s -X PUT "$DEMO_URL/products/$IPHONE_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "iPhone 15 Pro",
    "price": 1299.99,
    "stock": 45
  }' | jq '.data | {id, name, price, stock}'
print_success "Stock mis à jour"

###############################################################################
# SCÉNARIO 2: Création et gestion de commandes
###############################################################################

print_banner "🛒 SCÉNARIO 2: CRÉATION DE COMMANDES"

# 2.1 - Commande simple (1 produit)
print_section "2.1 - Commande simple (1 produit)"

echo "Création commande #1: 1x Laptop..."
ORDER1_RESPONSE=$(curl -s -X POST "$DEMO_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-alice-001\",
    \"items\": [
      {
        \"productId\": \"$LAPTOP_ID\",
        \"productName\": \"Laptop Dell XPS 15 (PROMO)\",
        \"quantity\": 1,
        \"price\": 1699.99
      }
    ],
    \"total\": 1699.99
  }")
ORDER1_ID=$(echo "$ORDER1_RESPONSE" | jq -r '.data.id')
print_success "Commande créée - ID: $ORDER1_ID"
echo "$ORDER1_RESPONSE" | jq '.data | {id, customerId, status, total}'

# 2.2 - Commande multiple (plusieurs produits)
print_section "2.2 - Commande multiple (plusieurs produits)"

echo "Création commande #2: 2x iPhone + 3x AirPods..."
ORDER2_RESPONSE=$(curl -s -X POST "$DEMO_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-bob-002\",
    \"items\": [
      {
        \"productId\": \"$IPHONE_ID\",
        \"productName\": \"iPhone 15 Pro\",
        \"quantity\": 2,
        \"price\": 1299.99
      },
      {
        \"productId\": \"$AIRPODS_ID\",
        \"productName\": \"AirPods Pro\",
        \"quantity\": 3,
        \"price\": 249.99
      }
    ],
    \"total\": 3349.95
  }")
ORDER2_ID=$(echo "$ORDER2_RESPONSE" | jq -r '.data.id')
print_success "Commande créée - ID: $ORDER2_ID"
echo "$ORDER2_RESPONSE" | jq '.data | {id, customerId, status, total, itemCount: (.items | length)}'

# 2.3 - Commande grosse valeur
print_section "2.3 - Commande de grosse valeur"

echo "Création commande #3: 3x MacBook + 2x iPhone..."
ORDER3_RESPONSE=$(curl -s -X POST "$DEMO_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-charlie-003\",
    \"items\": [
      {
        \"productId\": \"$MACBOOK_ID\",
        \"productName\": \"MacBook Air M3\",
        \"quantity\": 3,
        \"price\": 1499.99
      },
      {
        \"productId\": \"$IPHONE_ID\",
        \"productName\": \"iPhone 15 Pro\",
        \"quantity\": 2,
        \"price\": 1299.99
      }
    ],
    \"total\": 7099.95
  }")
ORDER3_ID=$(echo "$ORDER3_RESPONSE" | jq -r '.data.id')
print_success "Commande créée - ID: $ORDER3_ID"
echo "$ORDER3_RESPONSE" | jq '.data | {id, customerId, status, total}'

# 2.4 - Lister toutes les commandes
print_section "2.4 - Liste de toutes les commandes"

ORDERS=$(curl -s "$DEMO_URL/orders")
ORDER_COUNT=$(echo "$ORDERS" | jq '.data | length')
print_info "Nombre de commandes: $ORDER_COUNT"
echo "$ORDERS" | jq '.data[] | {id, customerId, status, total}'

###############################################################################
# SCÉNARIO 3: Cycle de vie des commandes
###############################################################################

print_banner "🚚 SCÉNARIO 3: CYCLE DE VIE DES COMMANDES"

# 3.1 - Expédier une commande
print_section "3.1 - Expédition d'une commande"

echo "Expédition de la commande $ORDER1_ID..."
curl -s -X POST "$DEMO_URL/orders/$ORDER1_ID/ship" \
  -H "Content-Type: application/json" \
  -d '{
    "trackingNumber": "DHL-FR-123456789"
  }' | jq '.data | {id, status, trackingNumber, shippedAt}'
print_success "Commande expédiée"

# 3.2 - Livrer une commande
print_section "3.2 - Livraison d'une commande"

wait_seconds 2 "Simulation du transport"

echo "Livraison de la commande $ORDER1_ID..."
curl -s -X POST "$DEMO_URL/orders/$ORDER1_ID/deliver" \
  -H "Content-Type: application/json" | jq '.data | {id, status, deliveredAt}'
print_success "Commande livrée"

# 3.3 - Expédier et livrer la commande 2
print_section "3.3 - Cycle complet pour commande #2"

echo "Expédition de la commande $ORDER2_ID..."
curl -s -X POST "$DEMO_URL/orders/$ORDER2_ID/ship" \
  -H "Content-Type: application/json" \
  -d '{
    "trackingNumber": "UPS-FR-987654321"
  }' | jq '.data.status'

wait_seconds 1 "Simulation du transport"

echo "Livraison de la commande $ORDER2_ID..."
curl -s -X POST "$DEMO_URL/orders/$ORDER2_ID/deliver" \
  -H "Content-Type: application/json" | jq '.data.status'
print_success "Commande livrée"

# 3.4 - Annuler une commande
print_section "3.4 - Annulation d'une commande"

echo "Création d'une commande à annuler..."
ORDER_CANCEL_RESPONSE=$(curl -s -X POST "$DEMO_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-david-004\",
    \"items\": [
      {
        \"productId\": \"$SAMSUNG_ID\",
        \"productName\": \"Samsung Galaxy S24\",
        \"quantity\": 1,
        \"price\": 999.99
      }
    ],
    \"total\": 999.99
  }")
ORDER_CANCEL_ID=$(echo "$ORDER_CANCEL_RESPONSE" | jq -r '.data.id')
print_info "Commande créée: $ORDER_CANCEL_ID"

echo "Annulation de la commande $ORDER_CANCEL_ID..."
curl -s -X POST "$DEMO_URL/orders/$ORDER_CANCEL_ID/cancel" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Client a changé d avis - veut un iPhone à la place"
  }' | jq '.data | {id, status, cancelReason}'
print_success "Commande annulée"

###############################################################################
# SCÉNARIO 4: Tests de suppression
###############################################################################

print_banner "🗑️  SCÉNARIO 4: SUPPRESSION DE PRODUITS"

print_section "4.1 - Suppression d'un produit"

echo "Suppression du produit: $AIRPODS_ID (AirPods Pro)..."
curl -s -X DELETE "$DEMO_URL/products/$AIRPODS_ID" | jq '.message'
print_success "Produit supprimé"

echo "Vérification de la suppression..."
DELETED_CHECK=$(curl -s "$DEMO_URL/products/$AIRPODS_ID" | jq -r '.error')
if [ "$DELETED_CHECK" != "null" ]; then
    print_success "Produit bien supprimé (erreur attendue)"
else
    print_error "Le produit existe encore!"
fi

###############################################################################
# SCÉNARIO 5: Vérification des audits
###############################################################################

print_banner "📊 SCÉNARIO 5: VÉRIFICATION DES AUDITS"

print_section "5.1 - Attente de l'indexation des audits"

wait_seconds 3 "Attente de l'indexation dans OpenSearch"

print_section "5.2 - Consultation des audits dans le backend"

echo "Récupération des audits depuis Kockpit Backend..."
AUDITS=$(curl -s -u "$BACKEND_USER:$BACKEND_PASS" \
  "$BACKEND_URL/demo/local/audits/_search?start=0&size=50")

AUDIT_COUNT=$(echo "$AUDITS" | jq -r '.total_count')
print_success "Total d'audits trouvés: $AUDIT_COUNT"

if [ "$AUDIT_COUNT" -gt 0 ]; then
    echo ""
    echo "Détail des 10 derniers audits:"
    echo "$AUDITS" | jq '.items[0:10] | .[] | {
      action: .action,
      timestamp: .timestamp,
      user: .user,
      resource: .resource
    }'

    echo ""
    echo "Statistiques par action:"
    echo "$AUDITS" | jq '[.items[].action] | group_by(.) | map({action: .[0], count: length}) | sort_by(.count) | reverse'
fi

print_section "5.3 - Audits par client"

echo "Audits pour customer-alice-001:"
curl -s -u "$BACKEND_USER:$BACKEND_PASS" \
  "$BACKEND_URL/demo/local/audits/_search?start=0&size=10" | \
  jq '[.items[] | select(.user == "customer-alice-001")] | length' | \
  xargs -I {} echo "  Nombre d'actions: {}"

echo "Audits pour customer-bob-002:"
curl -s -u "$BACKEND_USER:$BACKEND_PASS" \
  "$BACKEND_URL/demo/local/audits/_search?start=0&size=10" | \
  jq '[.items[] | select(.user == "customer-bob-002")] | length' | \
  xargs -I {} echo "  Nombre d'actions: {}"

###############################################################################
# SCÉNARIO 6: Tests de cas limites
###############################################################################

print_banner "⚠️  SCÉNARIO 6: TESTS DE CAS LIMITES"

print_section "6.1 - Produit avec prix négatif (doit échouer)"

echo "Tentative de création d'un produit avec prix négatif..."
INVALID_PRODUCT=$(curl -s -X POST "$DEMO_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Produit Invalide",
    "price": -100.00,
    "stock": 10
  }')
if echo "$INVALID_PRODUCT" | jq -e '.error' > /dev/null; then
    print_success "Validation correcte - produit rejeté"
else
    print_error "Le produit invalide a été accepté!"
fi

print_section "6.2 - Commande avec montant total incorrect"

echo "Commande avec total qui ne correspond pas aux items..."
INVALID_ORDER=$(curl -s -X POST "$DEMO_URL/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"customer-test\",
    \"items\": [
      {
        \"productId\": \"$LAPTOP_ID\",
        \"productName\": \"Laptop\",
        \"quantity\": 1,
        \"price\": 1699.99
      }
    ],
    \"total\": 100.00
  }")
echo "$INVALID_ORDER" | jq -e '.error // .data'

print_section "6.3 - Récupération d'un produit inexistant"

echo "Tentative de récupération d'un produit inexistant..."
curl -s "$DEMO_URL/products/id-inexistant-99999" | jq '.error // "Erreur non gérée"'

###############################################################################
# RÉSUMÉ FINAL
###############################################################################

print_banner "✅ RÉSUMÉ DES TESTS"

echo ""
print_success "Produits créés: 5"
print_success "Commandes créées: 4"
print_success "Commandes expédiées: 2"
print_success "Commandes livrées: 2"
print_success "Commandes annulées: 1"
print_success "Produits supprimés: 1"
print_success "Audits générés: $AUDIT_COUNT"
echo ""

print_info "État final du système:"
echo ""

echo "Produits restants:"
curl -s "$DEMO_URL/products" | jq '.data | length' | xargs -I {} echo "  Total: {} produits"

echo ""
echo "Commandes par statut:"
ALL_ORDERS=$(curl -s "$DEMO_URL/orders")
echo "$ALL_ORDERS" | jq '[.data[].status] | group_by(.) | map({status: .[0], count: length})' | \
  jq -r '.[] | "  \(.status): \(.count)"'

echo ""
print_banner "🎉 TESTS TERMINÉS AVEC SUCCÈS"

echo ""
echo "Pour consulter les audits dans OpenSearch Dashboards:"
echo "  → http://localhost:5601"
echo ""
echo "Pour consulter les audits via l'API Backend:"
echo "  → curl -u $BACKEND_USER:$BACKEND_PASS \\"
echo "      \"$BACKEND_URL/demo/local/audits/_search?start=0&size=20\""
echo ""
echo "Pour relancer les tests:"
echo "  → ./test-api.sh"
echo ""

print_info "Les données créées restent en mémoire jusqu'au redémarrage de l'application"
echo ""
