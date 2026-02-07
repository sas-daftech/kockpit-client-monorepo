#!/bin/bash

###############################################################################
# Script de création des index OpenSearch pour Kockpit Demo
#
# Ce script crée les index nécessaires dans OpenSearch pour stocker
# les audits générés par l'application de démonstration
###############################################################################

set -e

OPENSEARCH_URL="http://localhost:9200"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================================================="
echo "  Configuration des index OpenSearch pour Kockpit Demo"
echo "========================================================================="
echo ""

# Vérifier qu'OpenSearch est accessible
echo -n "Vérification de la connexion à OpenSearch... "
if curl -s -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL" | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}ÉCHEC${NC}"
    echo "OpenSearch n'est pas accessible à $OPENSEARCH_URL"
    echo "Démarrez OpenSearch avec: docker compose up -d"
    exit 1
fi

echo ""
echo "Création des index pour la démonstration..."
echo ""

###############################################################################
# Index pour les audits en lecture (demo-kockpit-audit-local-read)
###############################################################################

echo "1. Création de l'index: demo-kockpit-audit-local-read"

INDEX_READ_RESPONSE=$(curl -s -X PUT "$OPENSEARCH_URL/demo-kockpit-audit-local-read" \
  -H 'Content-Type: application/json' \
  -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index": {
      "refresh_interval": "1s"
    }
  },
  "mappings": {
    "properties": {
      "id": {
        "type": "keyword"
      },
      "domain": {
        "type": "keyword"
      },
      "env": {
        "type": "keyword"
      },
      "appId": {
        "type": "keyword"
      },
      "requestId": {
        "type": "keyword"
      },
      "hostname": {
        "type": "keyword"
      },
      "version": {
        "type": "keyword"
      },
      "artifact": {
        "type": "keyword"
      },
      "timestamp": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "start": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "end": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "action": {
        "type": "keyword"
      },
      "resource": {
        "type": "keyword"
      },
      "resourceType": {
        "type": "keyword"
      },
      "user": {
        "type": "keyword"
      },
      "userId": {
        "type": "keyword"
      },
      "status": {
        "type": "keyword"
      },
      "method": {
        "type": "keyword"
      },
      "path": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      },
      "duration": {
        "type": "long"
      },
      "statusCode": {
        "type": "integer"
      },
      "result": {
        "type": "text"
      },
      "error": {
        "type": "text"
      },
      "metadata": {
        "type": "object",
        "enabled": true
      },
      "audits": {
        "type": "nested",
        "properties": {
          "action": {
            "type": "keyword"
          },
          "timestamp": {
            "type": "date"
          },
          "data": {
            "type": "object",
            "enabled": true
          }
        }
      }
    }
  }
}')

if echo "$INDEX_READ_RESPONSE" | grep -q '"acknowledged":true'; then
    echo -e "   ${GREEN}✓${NC} Index créé avec succès"
else
    if echo "$INDEX_READ_RESPONSE" | grep -q 'resource_already_exists_exception'; then
        echo -e "   ${YELLOW}⚠${NC} Index existe déjà"
    else
        echo -e "   ${RED}✗${NC} Erreur lors de la création"
        echo "$INDEX_READ_RESPONSE" | jq '.'
    fi
fi

###############################################################################
# Index pour les audits en écriture (demo-kockpit-audit-local-write)
###############################################################################

echo ""
echo "2. Création de l'index: demo-kockpit-audit-local-write"

INDEX_WRITE_RESPONSE=$(curl -s -X PUT "$OPENSEARCH_URL/demo-kockpit-audit-local-write" \
  -H 'Content-Type: application/json' \
  -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index": {
      "refresh_interval": "1s"
    }
  },
  "mappings": {
    "properties": {
      "id": {
        "type": "keyword"
      },
      "domain": {
        "type": "keyword"
      },
      "env": {
        "type": "keyword"
      },
      "appId": {
        "type": "keyword"
      },
      "requestId": {
        "type": "keyword"
      },
      "hostname": {
        "type": "keyword"
      },
      "version": {
        "type": "keyword"
      },
      "artifact": {
        "type": "keyword"
      },
      "timestamp": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "start": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "end": {
        "type": "date",
        "format": "strict_date_optional_time||epoch_millis"
      },
      "action": {
        "type": "keyword"
      },
      "resource": {
        "type": "keyword"
      },
      "resourceType": {
        "type": "keyword"
      },
      "user": {
        "type": "keyword"
      },
      "userId": {
        "type": "keyword"
      },
      "status": {
        "type": "keyword"
      },
      "method": {
        "type": "keyword"
      },
      "path": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      },
      "duration": {
        "type": "long"
      },
      "statusCode": {
        "type": "integer"
      },
      "result": {
        "type": "text"
      },
      "error": {
        "type": "text"
      },
      "metadata": {
        "type": "object",
        "enabled": true
      },
      "audits": {
        "type": "nested",
        "properties": {
          "action": {
            "type": "keyword"
          },
          "timestamp": {
            "type": "date"
          },
          "data": {
            "type": "object",
            "enabled": true
          }
        }
      }
    }
  }
}')

if echo "$INDEX_WRITE_RESPONSE" | grep -q '"acknowledged":true'; then
    echo -e "   ${GREEN}✓${NC} Index créé avec succès"
else
    if echo "$INDEX_WRITE_RESPONSE" | grep -q 'resource_already_exists_exception'; then
        echo -e "   ${YELLOW}⚠${NC} Index existe déjà"
    else
        echo -e "   ${RED}✗${NC} Erreur lors de la création"
        echo "$INDEX_WRITE_RESPONSE" | jq '.'
    fi
fi

###############################################################################
# Alias pour simplifier l'accès
###############################################################################

echo ""
echo "3. Création des alias"

# Alias en lecture
ALIAS_READ_RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_aliases" \
  -H 'Content-Type: application/json' \
  -d '{
  "actions": [
    {
      "add": {
        "index": "demo-kockpit-audit-local-read",
        "alias": "demo-audits-read"
      }
    }
  ]
}')

if echo "$ALIAS_READ_RESPONSE" | grep -q '"acknowledged":true'; then
    echo -e "   ${GREEN}✓${NC} Alias 'demo-audits-read' créé"
else
    echo -e "   ${YELLOW}⚠${NC} Alias 'demo-audits-read' existe peut-être déjà"
fi

# Alias en écriture
ALIAS_WRITE_RESPONSE=$(curl -s -X POST "$OPENSEARCH_URL/_aliases" \
  -H 'Content-Type: application/json' \
  -d '{
  "actions": [
    {
      "add": {
        "index": "demo-kockpit-audit-local-write",
        "alias": "demo-audits-write"
      }
    }
  ]
}')

if echo "$ALIAS_WRITE_RESPONSE" | grep -q '"acknowledged":true'; then
    echo -e "   ${GREEN}✓${NC} Alias 'demo-audits-write' créé"
else
    echo -e "   ${YELLOW}⚠${NC} Alias 'demo-audits-write' existe peut-être déjà"
fi

###############################################################################
# Vérification
###############################################################################

echo ""
echo "4. Vérification des index créés"
echo ""

curl -s "$OPENSEARCH_URL/_cat/indices/demo-*?v&h=index,health,status,docs.count,store.size" | \
  while read line; do
    echo "   $line"
  done

echo ""
echo "========================================================================="
echo -e "${GREEN}Configuration terminée avec succès!${NC}"
echo "========================================================================="
echo ""
echo "Index créés:"
echo "  • demo-kockpit-audit-local-read  (pour les recherches)"
echo "  • demo-kockpit-audit-local-write (pour l'écriture)"
echo ""
echo "Alias créés:"
echo "  • demo-audits-read"
echo "  • demo-audits-write"
echo ""
echo "Vous pouvez maintenant:"
echo "  1. Démarrer l'application demo: mvn spring-boot:run"
echo "  2. Lancer les tests: ./test-api.sh"
echo "  3. Consulter les audits via l'API Backend"
echo ""
echo "Pour supprimer les index:"
echo "  curl -X DELETE \"$OPENSEARCH_URL/demo-*\""
echo ""
