# Session de travail Kockpit - 2025-12-02

## Résumé de la session

Session complète de mise en place et de débogage du projet Kockpit, de la compilation initiale jusqu'à l'intégration complète backend/frontend/demo app avec OpenSearch.

---

## 🎯 Objectifs atteints

### 1. Build et compilation
- ✅ Résolution des problèmes de compilation Java 17 vs Java 25
- ✅ Configuration Lombok avec annotationProcessorPaths
- ✅ Build complet du projet (57 modules, 342 fichiers Java)

### 2. Infrastructure backend
- ✅ Démarrage du backend Kockpit sur port 8080
- ✅ Configuration OpenSearch (port 9200)
- ✅ Création des index OpenSearch pour les audits

### 3. Application demo
- ✅ Configuration et démarrage sur port 8091
- ✅ API REST fonctionnelle (produits, commandes)
- ✅ Scripts de test créés

### 4. Frontend
- ✅ Configuration et démarrage sur port 3000 (React 19 + Vite)
- ✅ Correction de l'authentification MSAL Azure AD
- ✅ Configuration Basic Auth pour les appels API backend
- ✅ Correction de la configuration vide (création de /tmp/kockpit-storage)
- ✅ Ajout du service audit dans la configuration

### 5. Système d'audit
- ✅ Identification du problème : pas d'implémentation HTTP pour envoyer les audits
- ✅ Création de `HttpAuditReportNotificationService` dans la demo app
- ✅ Création de l'endpoint POST `/audits` dans le backend
- ✅ Implémentation de l'ingestion des audits dans OpenSearch

---

## 📂 Architecture du projet

```
/home/debian/sources/kiss/kockpit/
├── kockpit-audit/              # Module d'audit
│   ├── kockpit-audit-sdk/      # SDK pour les applications
│   ├── kockpit-audit-api/      # API du système d'audit
│   ├── kockpit-audit-web-starter/  # Starter pour audit web
│   └── kockpit-audit-console-ui/   # Frontend React (port 3000)
├── kockpit-backends/           # Services backend
│   ├── kockpit-backend-service-search/  # Service de recherche
│   │   ├── kockpit-backend-service-search-api/
│   │   └── kockpit-backend-service-search-opensearch/
│   ├── kockpit-backend-service-storage/  # Service de stockage config
│   └── kockpit-backend-application/  # Application principale (port 8080)
└── kockpit-demo-app/           # Application de démo (port 8091)
```

---

## 🔧 Modifications majeures

### 1. Build fixes - Lombok

**Fichier**: `/home/debian/sources/kiss/kockpit/pom.xml`
```xml
<build>
    <pluginManagement>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>${lombok.version}</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
        </plugins>
    </pluginManagement>
</build>
```

### 2. Frontend - Authentification Azure AD

**Fichier**: `kockpit-audit-console-ui/src/authConfig.js`
```javascript
redirectUri: window.location.origin, // Au lieu de l'URL hardcodée production
```

**Fichier**: `kockpit-audit-console-ui/src/services/api.js`
```javascript
// Configuration Basic Auth pour les appels backend
axios.defaults.auth = {
  username: 'user',
  password: 'password'
};
```

### 3. Configuration backend

**Création de**: `/tmp/kockpit-storage/demo-application.json`
```json
[
  {
    "domain": "demo",
    "env": "local",
    "services": [
      {
        "name": "audit",
        "config": {
          "columns": ["eventDate", "userId", "action", "entityType", "entityId", "appId", "domain", "env"],
          "search_columns": ["userId", "action", "entityType", "entityId", "appId"],
          "saved_filters": []
        }
      }
    ]
  }
]
```

### 4. Endpoint d'ingestion des audits

**Nouveau fichier**: `kockpit-backend-service-search-api/src/main/java/org/kockpit/backend/services/search/IngestionApi.java`
```java
@RestController
@RequestMapping("/{domain}/{env}/audits")
public class IngestionApi {

    @PostMapping(consumes = "application/json")
    public ResponseEntity<Void> ingestAudit(
            @PathVariable("domain") String domain,
            @PathVariable("env") String env,
            @RequestBody String auditEventJson) {

        searchService.ingestAudit(domain, env, auditEventJson);
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }
}
```

**Méthode ajoutée**: `OpensearchRepository.ingestAudit()`
```java
public void ingestAudit(String domain, String env, String auditEventJson) {
    String indexName = domain + "-" + index + "-" + env + "-write";

    org.opensearch.action.index.IndexRequest indexRequest =
            new org.opensearch.action.index.IndexRequest(indexName)
                    .source(auditEventJson, org.opensearch.common.xcontent.XContentType.JSON);

    client.index(indexRequest, RequestOptions.DEFAULT);
}
```

### 5. Service HTTP d'envoi des audits

**Nouveau fichier**: `kockpit-demo-app/src/main/java/com/kockpit/demo/audit/HttpAuditReportNotificationService.java`
```java
@Component
public class HttpAuditReportNotificationService implements AuditReportNotificationService {

    private final RestTemplate restTemplate;
    private final String backendUrl;
    // ...

    @Override
    public void notify(List<AuditJsonReport> auditReports) {
        auditReports.forEach(auditReport -> {
            String url = String.format("%s/%s/%s/audits", backendUrl, domain, env);
            String auditJson = auditReport.getAuditJson();

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBasicAuth(username, password);

            HttpEntity<String> request = new HttpEntity<>(auditJson, headers);
            restTemplate.exchange(url, HttpMethod.POST, request, String.class);
        });
    }
}
```

**Dépendances ajoutées** dans `kockpit-demo-app/pom.xml`:
- `kockpit-audit-api`
- `kockpit-audit-web-starter`
- SLF4J API
- Configuration `build-info` pour Spring Boot

---

## 🗄️ OpenSearch - Index créés

```bash
# Index de lecture
demo-kockpit-audit-local-read

# Index d'écriture
demo-kockpit-audit-local-write

# Index RCU
rcu-kockpit-audit-local-read
rcu-kockpit-audit-local-write
```

**Mappings** (voir `/home/debian/sources/kiss/kockpit-demo-app/setup-opensearch-index.sh`):
- eventDate (date)
- domain, env, appId, userId, action, entityType, entityId (keyword)

---

## 🚀 Commandes de démarrage

### 1. OpenSearch
```bash
cd /home/debian/sources/others/opensearch
docker compose -f docker-compose-dev.yml up -d
```

### 2. Backend Kockpit
```bash
cd /home/debian/sources/kiss/kockpit/kockpit-backends/kockpit-backend-application

# Initialiser la configuration (première fois)
./setup-config.sh

# Démarrer
JAVA_HOME=/home/debian/.sdkman/candidates/java/17.0.17-amzn \
  mvn spring-boot:run -Dspring-boot.run.profiles=local,opensearch,filesystem
```

### 3. Demo App
```bash
cd /home/debian/sources/kiss/kockpit-demo-app
JAVA_HOME=/home/debian/.sdkman/candidates/java/17.0.17-amzn \
  mvn spring-boot:run
```

### 4. Frontend
```bash
cd /home/debian/sources/kiss/kockpit/kockpit-audit/kockpit-audit-console-ui
npm run dev
```

---

## 📊 URLs importantes

| Service | URL | Authentification |
|---------|-----|------------------|
| Frontend | http://localhost:3000 | Mock en dev |
| Backend API | http://localhost:8080/backend/api | user:password |
| Demo App API | http://localhost:8091/demo/api/api | Aucune |
| OpenSearch | http://localhost:9200 | Aucune |
| OpenSearch Dashboards | http://localhost:5601 | Aucune |

---

## 🐛 Problème en cours

### Symptôme
Les audits ne sont pas écrits dans OpenSearch depuis la demo app, bien que:
- ✅ Le filtre d'audit (`auditFilter`) est configuré et actif
- ✅ Les audits sont générés par le SDK Kockpit
- ✅ Le `HttpAuditReportNotificationService` est initialisé
- ✅ Les audits sont envoyés au backend (visible dans les logs)
- ❌ Le backend retourne une erreur 500

### Logs observés

**Demo app** (`logs/demo-app.log`):
```
2025-12-02 17:32:26 - Sending audit to: http://localhost:8080/backend/api/demo/local/audits - Payload: {"id":"...","domain":"demo","env":"local",...}
org.springframework.web.client.HttpServerErrorException$InternalServerError: 500 on POST request
```

**Tests manuels**:
- ✅ JSON simple fonctionne (201 Created, écrit dans OpenSearch)
- ❌ JSON complexe de la demo app retourne 500 (cause à identifier)

### JSON envoyé par la demo app

Le SDK Kockpit envoie des objets complexes avec:
- Métadonnées: id, domain, env, requestId, appId, hostname, version, start, end, ttl
- indexedKeyValues: tableau d'objets avec key/value/valueInteger/valueFloat/valueDate
- audits: tableau avec type "builtin.web" et events contenant httpAuditedRequest/Response
- Timestamps en format décimal (ex: 1764693140.099165939)

### État actuel

**OpenSearch**:
```bash
curl -s "http://localhost:9200/demo-kockpit-audit-local-write/_count" | jq .count
# Résultat: 3 (seulement les tests manuels, pas les audits de la demo app)
```

### Prochaines étapes pour résoudre

1. **Vérifier les logs du backend** au moment de l'erreur 500
   - Chercher l'exception complète
   - Identifier quel champ pose problème

2. **Tester le JSON réel** manuellement:
   ```bash
   # Extraire le JSON d'un audit de la demo app
   grep "Sending audit to:" logs/demo-app.log | tail -1 | sed 's/.*Payload: //' > /tmp/audit.json

   # Le tester directement sur le backend
   curl -X POST http://localhost:8080/backend/api/demo/local/audits \
     -u user:password \
     -H 'Content-Type: application/json' \
     --data-binary '@/tmp/audit.json' -v
   ```

3. **Vérifier le parsing JSON** dans `OpensearchRepository.ingestAudit()`:
   - Peut-être un problème avec les types (timestamps décimaux, valeurs null)
   - Vérifier si OpenSearch accepte ce format

4. **Redémarrer la demo app** avec un buffer vide:
   ```bash
   cd /home/debian/sources/kiss/kockpit-demo-app
   JAVA_HOME=/home/debian/.sdkman/candidates/java/17.0.17-amzn \
     mvn spring-boot:run 2>&1 | tee logs/demo-app-clean.log
   ```

5. **Faire un test propre**:
   ```bash
   # Créer un produit
   curl -X POST http://localhost:8091/demo/api/api/products \
     -H 'Content-Type: application/json' \
     -d '{"name":"Test Clean","price":99.99,"stock":10}'

   # Attendre 15 secondes
   sleep 15

   # Vérifier OpenSearch
   curl -s "http://localhost:9200/demo-kockpit-audit-local-write/_count" | jq .

   # Vérifier les logs pour l'erreur
   grep -A 10 "500" logs/demo-app-clean.log
   ```

---

## 📝 Scripts créés

### Backend
- `/home/debian/sources/kiss/kockpit/kockpit-backends/kockpit-backend-application/setup-config.sh` - Initialise la configuration

### Demo App
- `/home/debian/sources/kiss/kockpit-demo-app/setup-opensearch-index.sh` - Crée les index OpenSearch
- `/home/debian/sources/kiss/kockpit-demo-app/test-api.sh` - Tests complets de l'API
- `/home/debian/sources/kiss/kockpit-demo-app/check-setup.sh` - Vérifie la configuration complète

### Frontend
- `/home/debian/sources/kiss/kockpit/kockpit-audit/kockpit-audit-console-ui/start.sh` - Démarrage avec vérifications

---

## 📚 Documentation créée

### Kockpit (principal)
- `BUILD-TROUBLESHOOTING.txt` - Guide complet de résolution des problèmes de build
- `CHANGELOG-BUILD-FIXES.txt` - Détail de toutes les modifications
- `START-HERE.txt` - Guide d'orientation pour nouveaux développeurs
- `SUMMARY-BUILD-FIXES-2025-12-02.txt` - Résumé de session
- `QUICK-FIX-SUMMARY.txt` - Référence rapide

### Backend
- `kockpit-backends/kockpit-backend-application/CONFIG.md` - Documentation du système de configuration
- `kockpit-backends/kockpit-backend-application/setup-config.sh` - Script d'init

### Frontend
- `kockpit-audit-console-ui/START-FRONTEND.md` - Guide de démarrage frontend
- `kockpit-audit-console-ui/FRONTEND-FIXES.md` - Documentation des corrections frontend
- `kockpit-audit-console-ui/start.sh` - Script de démarrage

### Demo App
- `kockpit-demo-app/README.md` - Mis à jour avec port 8091
- `kockpit-demo-app/setup-opensearch-index.sh` - Script de création d'index
- `kockpit-demo-app/test-api.sh` - Script de test
- `kockpit-demo-app/check-setup.sh` - Script de vérification

---

## 🔑 Points clés à retenir

### Configuration Java
- **Java 17 obligatoire** (pas Java 25)
- Utiliser: `JAVA_HOME=/home/debian/.sdkman/candidates/java/17.0.17-amzn`

### Lombok
- Nécessite `annotationProcessorPaths` dans le maven-compiler-plugin
- Scope `provided` dans les modules

### Architecture d'audit
Le système d'audit Kockpit utilise:
1. **SDK dans l'application** (`kockpit-audit-sdk` + `kockpit-audit-web-starter`)
2. **Filtre web** (`AuditFilter`) qui intercepte les requêtes HTTP
3. **Notification service** (Kafka, EventHubs, ou notre custom HTTP)
4. **Backend d'ingestion** (nouveau endpoint POST créé)
5. **OpenSearch** pour le stockage
6. **Frontend** pour la visualisation

### Configuration backend
- Stockée dans `/tmp/kockpit-storage` (filesystem local)
- Format: fichiers JSON contenant des tableaux de ConfigItem
- Chaque fichier = une application avec ses domain/env
- Le service `audit` doit être défini avec columns/search_columns

### OpenSearch
- Index séparés pour read et write
- Naming: `{domain}-kockpit-audit-{env}-{read|write}`
- Le SDK bufferise les audits (flush toutes les 10 secondes par défaut)

---

## 💡 Leçons apprises

1. **Pas d'implémentation HTTP native** dans kockpit-audit-sdk
   - Seulement Console, Kafka, EventHubs
   - Nous avons créé HttpAuditReportNotificationService

2. **BuildProperties requis** par le SDK
   - Ajouter `<goal>build-info</goal>` au spring-boot-maven-plugin

3. **Format des audits très riche**
   - Contient request/response complets
   - Headers, body, timing, métadonnées
   - ~2.5KB par audit

4. **Configuration frontend essentielle**
   - Sans config backend, l'interface est blanche
   - Le service audit doit être défini dans la config

---

## 🎓 Architecture technique

### Backend - Hexagonal Architecture
```
kockpit-backend-application
├── Controllers (@RestController)
│   ├── SearchApi (GET, search)
│   └── IngestionApi (POST, nouvellement créé)
├── Services (interfaces)
│   └── SearchService
└── Adapters (implémentations)
    └── OpensearchRepository
```

### SDK - Event sourcing pattern
```
Application → AuditFilter → Auditor → NotificationManager → Queue → AuditReportNotificationService → Backend
                                                                      ↓
                                                                   (buffer 10s)
```

### Frontend - React 19 + Vite
```
App.jsx
├── MSAL Auth (Azure AD en prod, mock en dev)
├── DomainEnv selector (charge config backend)
└── Routes
    ├── /audits → AuditListPage
    ├── /audits/:id → DetailsPage
    ├── /config → ConfigPage
    └── /feature-flipping → FeatureFlippingPage
```

---

## 📞 Pour reprendre

1. **Démarrer les services dans l'ordre**:
   - OpenSearch
   - Backend Kockpit (avec setup-config.sh si première fois)
   - Demo App
   - Frontend

2. **Vérifier l'état**:
   ```bash
   # OpenSearch
   curl http://localhost:9200

   # Backend
   curl -u user:password http://localhost:8080/backend/api/config | jq .

   # Demo App
   curl http://localhost:8091/demo/api/api/products | jq .

   # Frontend
   curl http://localhost:3000
   ```

3. **Résoudre le problème d'audit**:
   - Vérifier les logs du backend lors d'un POST d'audit
   - Identifier l'erreur 500 exacte
   - Corriger le parsing ou le mapping OpenSearch

4. **Test final**:
   ```bash
   ./test-api.sh
   sleep 15
   curl -s "http://localhost:9200/demo-kockpit-audit-local-write/_count" | jq .
   # Devrait afficher plusieurs dizaines d'audits

   # Puis vérifier le frontend
   firefox http://localhost:3000
   ```

---

**Date**: 2025-12-02
**Durée**: Session complète (build → frontend → audit system)
**Status**: 95% complet - Reste à résoudre l'erreur 500 lors de l'ingestion des audits complexes
**Prochaine étape**: Déboguer l'erreur 500 dans le backend lors du POST des audits de la demo app
