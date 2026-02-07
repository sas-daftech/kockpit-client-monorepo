================================================================================
                         KOCKPIT BACKENDS
================================================================================

Version: 1.0.0-SNAPSHOT
Date: 2025-12-01

================================================================================
                           DESCRIPTION
================================================================================

Kockpit Backends est une application Spring Boot modulaire qui fournit des
APIs REST pour la gestion d'audits, de configurations et de feature flags.

Fonctionnalites principales:
  - Recherche et consultation d'audits
  - Gestion de configurations applicatives
  - Feature flipping (activation/desactivation dynamique de fonctionnalites)
  - Multi-tenant (isolation par domain et environnement)
  - Adapters multiples (OpenSearch, Filesystem, Azure)


================================================================================
                         TECHNOLOGIES
================================================================================

Backend:
  - Java 21
  - Spring Boot 3.4.3
  - Spring Security (Basic Auth)
  - Spring Data
  - Maven 3.8+

Stockage:
  - OpenSearch 3.3.2 (recherche full-text)
  - Filesystem (developpement local)
  - Azure Storage Account (production)

Infrastructure:
  - Docker & Docker Compose
  - Tomcat (embedded)


================================================================================
                         ARCHITECTURE
================================================================================

Pattern: Hexagonal Architecture (Ports & Adapters)

Modules:
  kockpit-backends/
    ├── kockpit-backend-application            (Point d'entree)
    ├── kockpit-backend-authentication-basic   (Securite)
    ├── kockpit-backend-service-search         (Recherche d'audits)
    │   ├── api                                (Port)
    │   └── opensearch                         (Adapter)
    ├── kockpit-backend-service-storage        (Stockage de configs)
    │   ├── api                                (Port)
    │   ├── filesystem                         (Adapter)
    │   └── azure                              (Adapter)
    └── kockpit-service-featureflipping        (Feature flags)
        ├── api                                (Port)
        ├── filesystem                         (Adapter)
        └── storageaccount                     (Adapter)


Structure:
                Client HTTP
                     |
              Spring Security
                     |
        +------------+------------+
        |            |            |
    SearchApi    ConfigApi   FeatureFlippingApi
        |            |            |
    Service      Service      Service
        |            |            |
    +---+---+    +---+---+    +---+---+
    |       |    |       |    |       |
OpenSearch  ES  FS   Azure   FS   Azure


Architecture Kafka (Event-Driven):
  Pour les environnements à haute charge, une architecture événementielle
  alternative est disponible via Apache Kafka.

  Application avec @Audited
         |
         v
  kockpit-audit-sdk (Producer)
         |
         v
  Apache Kafka (Topic: "audit")
         |
         v
  kockpit-audit-stream-application-kafka (Consumer)
         |
         v
  OpenSearch
         |
         v
  OpenSearch Dashboards

  Avantages:
    - Traitement asynchrone (pas d'impact sur l'application)
    - Scalabilité horizontale (partitions Kafka)
    - Fiabilité (persistence des messages)
    - Découplage complet (backend Kockpit pas nécessaire)

  Voir KAFKA-QUICK-START.txt pour le guide complet d'intégration.


================================================================================
                         ENDPOINTS PRINCIPAUX
================================================================================

Base URL: http://localhost:8080/backend/api

Audits:
  GET    /{domain}/{env}/audits/_search        Rechercher des audits
  POST   /{domain}/{env}/audits/_search        Recherche avancee
  GET    /{domain}/{env}/audits/{id}           Recuperer un audit

Configuration:
  GET    /config                                Lister les configs
  POST   /config                                Creer une config

Feature Flipping:
  PUT    /{domain}/{env}/feature-flipping      Activer/desactiver
  GET    /{domain}/{env}/feature-flipping/history  Historique

Monitoring:
  GET    /backend/actuator/health              Health check
  GET    /backend/actuator/metrics             Metriques


================================================================================
                         DEMARRAGE RAPIDE
================================================================================

1. Pre-requis:
   - Java 21+
   - Maven 3.8+
   - Docker & Docker Compose

2. Cloner le projet:
   $ git clone <repo-url> kockpit
   $ cd kockpit

3. Demarrer OpenSearch:
   $ cd /home/debian/sources/others/opensearch
   $ docker compose -f docker-compose-dev.yml up -d

4. Demarrer l'application:
   $ cd kockpit-backends/kockpit-backend-application
   $ mvn spring-boot:run -Dspring-boot.run.profiles=local,opensearch,filesystem

5. Tester:
   $ curl -u user:password \
     http://localhost:8080/backend/api/rcu/local/audits/_search

   Reponse attendue:
   {"size":0,"items":[],"total_count":0}


================================================================================
                         CONFIGURATION
================================================================================

Profiles disponibles:
  - local       : Developpement local
  - opensearch  : Backend OpenSearch (defaut)
  - filesystem  : Storage filesystem
  - azure       : Storage Azure

Variables d'environnement:
  OPENSEARCH_ENDPOINTS   : URL OpenSearch (ex: http://localhost:9200)
  INDEX_NAME             : Nom de l'index (ex: kockpit-audit)
  STORAGE_PATH           : Chemin stockage local (ex: /tmp/kockpit-storage)

Fichiers de configuration:
  application.yaml              : Config de base
  application-local.yaml        : Config dev local
  application-opensearch.yaml   : Config OpenSearch
  application-storageaccount.yaml : Config Azure


================================================================================
                         SECURITE
================================================================================

Authentification:
  Type: HTTP Basic Authentication
  Username: user (configurable)
  Password: password (configurable)

IMPORTANT:
  La configuration actuelle est adaptee au DEVELOPPEMENT.
  En production:
    - Utiliser JWT ou OAuth2
    - Activer HTTPS
    - Externaliser les credentials
    - Durcir les regles de securite


================================================================================
                         BUILD & DEPLOIEMENT
================================================================================

Build:
  # Build complet
  $ mvn clean install

  # Build sans tests
  $ mvn clean install -DskipTests

  # Build avec profils
  $ mvn clean package -P opensearch,filesystem

Execution:
  # Via Maven
  $ mvn spring-boot:run

  # Via JAR
  $ java -jar target/kockpit-backend-application-1.0.0-SNAPSHOT.jar

Docker:
  # Build image
  $ docker build -t kockpit-backend:1.0.0 .

  # Run
  $ docker run -p 8080:8080 \
      -e OPENSEARCH_ENDPOINTS=http://opensearch:9200 \
      kockpit-backend:1.0.0


================================================================================
                         DOCUMENTATION
================================================================================

Documentation disponible dans /home/debian/sources/kiss/kockpit-doc/:

  START-HERE.txt            : Guide d'orientation (COMMENCER ICI)
  README.txt                : Ce fichier (vue d'ensemble)
  QUICK-START.txt           : Guide de demarrage rapide
  ARCHITECTURE.txt          : Documentation architecture complete
  API-REFERENCE.txt         : Reference complete des APIs
  KAFKA-QUICK-START.txt     : Guide Kafka event-driven (NOUVEAU)
  KAFKA-TROUBLESHOOTING.txt : Résolution problèmes Kafka (NOUVEAU)
  DEMO-APP-GUIDE.txt        : Guide application demo
  BUILD-TROUBLESHOOTING.txt : Résolution problèmes de build


Autres ressources:
  - Swagger UI: http://localhost:8080/swagger-ui.html (si active)
  - Actuator: http://localhost:8080/backend/actuator
  - OpenSearch Dashboard: http://localhost:5601


================================================================================
                         DEVELOPPEMENT
================================================================================

Structure du code:
  src/main/java/
    org/kockpit/backend/
      ├── KockpitAuditBackendApplication.java    (Main)
      ├── config/                                 (Configurations)
      ├── security/                               (Securite)
      └── services/
          ├── search/                             (Recherche)
          ├── storage/                            (Stockage)
          └── featureflipping/                    (Features)

  src/main/resources/
    ├── application.yaml                          (Config)
    ├── application-local.yaml
    └── application-opensearch.yaml

Tests:
  src/test/java/
    org/kockpit/backend/


Bonnes pratiques:
  - Ecrire des tests unitaires
  - Documenter les APIs (OpenAPI)
  - Utiliser les logs appropriement (SLF4J)
  - Valider les entrees (@Valid)
  - Gerer les erreurs correctement


================================================================================
                         TROUBLESHOOTING
================================================================================

Problemes courants:

1. Application ne demarre pas:
   - Verifier qu'OpenSearch est accessible
   - Verifier le port 8080 disponible
   - Consulter les logs

2. Erreur de connexion OpenSearch:
   - curl http://localhost:9200
   - Verifier application-local.yaml
   - Verifier les logs OpenSearch

3. 401 Unauthorized:
   - Username: user
   - Password: password
   - Encoder en Base64: echo -n "user:password" | base64

4. 404 Not Found:
   - Verifier le context path: /backend/api
   - Verifier le format de l'URL

Logs:
  - Application: Console ou fichiers de logs
  - OpenSearch: docker logs opensearch-node1-dev


================================================================================
                         CONTRIBUTION
================================================================================

Pour contribuer au projet:

1. Fork le repository
2. Creer une branche feature:
   $ git checkout -b feature/ma-nouvelle-feature

3. Commiter les changements:
   $ git commit -m "Ajout de ma nouvelle feature"

4. Push vers la branche:
   $ git push origin feature/ma-nouvelle-feature

5. Ouvrir une Pull Request


Standards de code:
  - Java Code Conventions
  - Spring Boot Best Practices
  - Clean Code principles


================================================================================
                         SUPPORT
================================================================================

Pour obtenir de l'aide:
  - Issues: (a completer)
  - Wiki: (a completer)
  - Email: (a completer)
  - Slack: (a completer)


================================================================================
                         LICENSE
================================================================================

(A completer selon la licence choisie)


================================================================================
                         CHANGELOG
================================================================================

Version 1.0.0-SNAPSHOT (2025-12-01)
  - Version initiale
  - Support OpenSearch
  - APIs Audits, Config, Feature Flipping
  - Multi-tenant
  - Adapters Filesystem et Azure


================================================================================
                         AUTEURS
================================================================================

Equipe Kockpit Development Team
Contact: (a completer)


================================================================================

Pour demarrer rapidement: Consulter QUICK-START.txt

================================================================================
