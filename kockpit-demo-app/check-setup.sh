#!/bin/bash

###############################################################################
# Script de vérification de la configuration Kockpit Demo
###############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================================================"
echo "  Vérification de la configuration Kockpit Demo"
echo "========================================================================"
echo ""

# 1. OpenSearch
echo -e "${BLUE}1. OpenSearch${NC}"
echo "---"
if curl -s http://localhost:9200 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} OpenSearch est accessible"

    # Version
    VERSION=$(curl -s http://localhost:9200 | jq -r '.version.number')
    echo "  Version: $VERSION"

    # Index demo
    echo ""
    echo "  Index demo:"
    curl -s "http://localhost:9200/_cat/indices/demo-*?h=index,docs.count" | while read line; do
        echo "    $line"
    done
else
    echo -e "${RED}✗${NC} OpenSearch n'est pas accessible"
fi

# 2. Backend Kockpit
echo ""
echo -e "${BLUE}2. Backend Kockpit${NC}"
echo "---"
if curl -s -u user:password http://localhost:8080/backend/api/config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backend est accessible"

    # Test recherche audits
    echo ""
    echo "  Test recherche audits pour demo/local:"
    AUDIT_RESPONSE=$(curl -s -u user:password "http://localhost:8080/backend/api/demo/local/audits/_search?start=0&size=1" 2>&1)

    if echo "$AUDIT_RESPONSE" | jq -e '.total_count' > /dev/null 2>&1; then
        AUDIT_COUNT=$(echo "$AUDIT_RESPONSE" | jq -r '.total_count')
        echo -e "    ${GREEN}✓${NC} Recherche fonctionne - $AUDIT_COUNT audits trouvés"
    else
        echo -e "    ${RED}✗${NC} Erreur de recherche"
        echo "$AUDIT_RESPONSE" | grep -o "index_not_found_exception\|error" | head -1
    fi
else
    echo -e "${RED}✗${NC} Backend n'est pas accessible"
fi

# 3. Application Demo
echo ""
echo -e "${BLUE}3. Application Demo${NC}"
echo "---"
if curl -s http://localhost:8091/demo/api/api/products > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Demo app est accessible"

    PRODUCT_COUNT=$(curl -s http://localhost:8091/demo/api/api/products | jq '.data | length')
    echo "  Produits: $PRODUCT_COUNT"

    ORDER_COUNT=$(curl -s http://localhost:8091/demo/api/api/orders | jq '.data | length')
    echo "  Commandes: $ORDER_COUNT"
else
    echo -e "${RED}✗${NC} Demo app n'est pas accessible"
fi

# 4. Configuration
echo ""
echo -e "${BLUE}4. Configuration${NC}"
echo "---"

# Vérifier le fichier de config
if [ -f "src/main/resources/application.yaml" ]; then
    DOMAIN=$(grep "domain:" src/main/resources/application.yaml | head -1 | awk '{print $2}')
    ENV=$(grep "env:" src/main/resources/application.yaml | grep -v "ENVIRONMENT" | head -1 | awk '{print $2}')
    echo "  Domain: $DOMAIN"
    echo "  Env: $ENV"

    BACKEND_URL=$(grep "url:" src/main/resources/application.yaml | head -1 | awk '{print $2}')
    echo "  Backend URL: $BACKEND_URL"
fi

# 5. Index OpenSearch attendus
echo ""
echo -e "${BLUE}5. Index OpenSearch attendus${NC}"
echo "---"

EXPECTED_READ="demo-kockpit-audit-local-read"
EXPECTED_WRITE="demo-kockpit-audit-local-write"

echo "  Index de lecture attendu: $EXPECTED_READ"
if curl -s "http://localhost:9200/$EXPECTED_READ" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${NC} Existe"
else
    echo -e "    ${RED}✗${NC} N'existe pas - Lancez ./setup-opensearch-index.sh"
fi

echo "  Index d'écriture attendu: $EXPECTED_WRITE"
if curl -s "http://localhost:9200/$EXPECTED_WRITE" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${NC} Existe"
else
    echo -e "    ${RED}✗${NC} N'existe pas - Lancez ./setup-opensearch-index.sh"
fi

# 6. Test complet du flux
echo ""
echo -e "${BLUE}6. Test du flux complet${NC}"
echo "---"
echo "  Création d'un produit de test..."

TEST_PRODUCT=$(curl -s -X POST http://localhost:8091/demo/api/api/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test Verification","price":123.45,"stock":5}')

if echo "$TEST_PRODUCT" | jq -e '.data.id' > /dev/null 2>&1; then
    PRODUCT_ID=$(echo "$TEST_PRODUCT" | jq -r '.data.id')
    echo -e "    ${GREEN}✓${NC} Produit créé: $PRODUCT_ID"

    echo ""
    echo "  Attente de 5 secondes pour l'indexation..."
    sleep 5

    echo "  Vérification des audits dans OpenSearch..."
    AUDIT_COUNT_AFTER=$(curl -s "http://localhost:9200/demo-kockpit-audit-local-write/_count" | jq '.count')
    echo "    Documents dans l'index write: $AUDIT_COUNT_AFTER"

    if [ "$AUDIT_COUNT_AFTER" -gt 0 ]; then
        echo -e "    ${GREEN}✓${NC} Des audits ont été écrits!"
    else
        echo -e "    ${YELLOW}⚠${NC} Aucun audit écrit - vérifiez les logs de l'application"
    fi

    echo ""
    echo "  Nettoyage..."
    curl -s -X DELETE "http://localhost:8091/demo/api/api/products/$PRODUCT_ID" > /dev/null
    echo -e "    ${GREEN}✓${NC} Produit de test supprimé"
else
    echo -e "    ${RED}✗${NC} Échec de création du produit"
fi

# Résumé
echo ""
echo "========================================================================"
echo "  Résumé"
echo "========================================================================"
echo ""

ALL_OK=true

if ! curl -s http://localhost:9200 > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} OpenSearch n'est pas démarré"
    echo "  → Démarrez avec: cd /path/to/opensearch && docker compose up -d"
    ALL_OK=false
fi

if ! curl -s "http://localhost:9200/$EXPECTED_READ" > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Index OpenSearch manquants"
    echo "  → Créez-les avec: ./setup-opensearch-index.sh"
    ALL_OK=false
fi

if ! curl -s -u user:password http://localhost:8080/backend/api/config > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Backend Kockpit n'est pas démarré"
    echo "  → Démarrez-le depuis kockpit-backends/kockpit-backend-application"
    ALL_OK=false
fi

if ! curl -s http://localhost:8091/demo/api/api/products > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Application demo n'est pas démarrée"
    echo "  → Démarrez avec: mvn spring-boot:run"
    ALL_OK=false
fi

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✓ Tous les services sont opérationnels!${NC}"
    echo ""
    echo "Vous pouvez maintenant lancer les tests:"
    echo "  ./test-api.sh"
else
    echo ""
    echo "Corrigez les problèmes ci-dessus avant de continuer."
fi

echo ""
