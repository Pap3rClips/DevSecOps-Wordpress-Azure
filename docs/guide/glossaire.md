# Glossaire

| Terme | Définition |
|---|---|
| **ADR** | *Architecture Decision Record*. Court document qui consigne une décision technique, son contexte et ses conséquences. |
| **Alertmanager** | Composant qui reçoit les alertes de Prometheus, les regroupe et les envoie (Discord, e-mail…). |
| **Ansible** | Outil d'automatisation qui configure des serveurs en décrivant l'état souhaité. Il fonctionne par SSH, sans agent. |
| **Blackbox exporter** | Sonde qui teste un service de l'extérieur, comme un utilisateur, et produit des métriques. |
| **Caddy** | Serveur web et reverse proxy qui gère automatiquement les certificats HTTPS. |
| **Capability (Linux)** | Fraction des pouvoirs de root, par exemple « ouvrir un port inférieur à 1024 ». Un conteneur qui les abandonne toutes est très limité, même s'il est compromis. |
| **CI/CD** | Intégration continue / déploiement continu. Automatisation des tests et des mises en production à chaque changement. |
| **CVE** | *Common Vulnerabilities and Exposures*. Identifiant public d'une vulnérabilité, par exemple CVE-2020-35489. |
| **DAST** | *Dynamic Application Security Testing*. Test de sécurité d'une application en cours d'exécution, en l'attaquant. WPScan en est un, spécialisé WordPress. |
| **Digest** | Empreinte SHA-256 d'une image Docker. Contrairement à un tag, elle désigne une image unique et immuable. |
| **Entra ID** | Le service d'identité de Microsoft, anciennement Azure Active Directory. |
| **GHCR** | *GitHub Container Registry*, le registre d'images Docker de GitHub. |
| **Idempotence** | Propriété d'une opération qui produit le même résultat qu'on l'exécute une fois ou dix fois. |
| **IaC** | *Infrastructure as Code*. Infrastructure décrite dans des fichiers versionnés plutôt que créée à la main. |
| **NSG** | *Network Security Group*. Pare-feu Azure appliqué à un subnet ou à une carte réseau. |
| **OIDC** | *OpenID Connect*. Protocole d'identité. Ici, GitHub prouve à Azure l'identité d'un job, sans mot de passe. |
| **Prometheus** | Système de supervision qui collecte des métriques et évalue des règles d'alerte. |
| **RBAC** | *Role-Based Access Control*. Droits attribués par rôle, sur une portée précise. |
| **restic** | Outil de sauvegarde chiffrée et dédupliquée. |
| **SARIF** | Format standard de résultats d'analyse de sécurité, affiché par GitHub dans l'onglet *Security*. |
| **SAS** | *Shared Access Signature*. Jeton Azure donnant un accès limité (portée, droits, durée) à un stockage. |
| **SBOM** | *Software Bill of Materials*. Inventaire complet des composants d'un logiciel. |
| **Shift-left** | Déplacer les contrôles de sécurité le plus tôt possible dans le cycle de développement. |
| **Smoke test** | Test de fumée. Vérification rapide qu'un déploiement fonctionne dans ses grandes lignes. |
| **Soft delete** | Suppression réversible pendant une durée donnée. |
| **State (Terraform)** | Fichier où Terraform mémorise les ressources qu'il gère. |
| **STRIDE** | Méthode de classement des menaces en six catégories (voir le [modèle de menace](08-modele-de-menace.md)). |
| **Terraform** | Outil d'IaC qui crée et modifie l'infrastructure cloud à partir de fichiers déclaratifs. |
| **tmpfs** | Système de fichiers en mémoire, vidé à chaque redémarrage. |
| **Trivy** | Scanner de sécurité : vulnérabilités d'images, mauvaises configurations d'IaC, secrets. |
| **Trusted Launch** | Option de VM Azure avec démarrage sécurisé et puce TPM virtuelle. |
| **WPScan** | Scanner de vulnérabilités spécialisé WordPress. |
