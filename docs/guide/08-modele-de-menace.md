# 8. Modèle de menace

Ce chapitre recense les menaces prises en compte, les mesures qui y répondent et les risques résiduels assumés.
Les menaces sont classées selon la méthode **STRIDE** : *Spoofing* (usurpation), *Tampering* (altération), *Repudiation* (répudiation), *Information disclosure* (fuite d'information), *Denial of service* (déni de service), *Elevation of privilege* (élévation de privilèges).

## 8.1 Actifs à protéger

| Actif | Pourquoi il compte |
|---|---|
| Le site et ses données (base, uploads) | Disponibilité, intégrité, données des visiteurs. |
| L'abonnement Azure | Un accès permettrait de détruire, d'espionner ou de miner aux frais du propriétaire. |
| La chaîne de déploiement | La compromettre revient à pouvoir déployer n'importe quel code en production. |
| Les sauvegardes | Dernier recours en cas d'incident ou de rançongiciel. |

## 8.2 Surface d'attaque

| Point d'entrée | Exposé à | Contrôles |
|---|---|---|
| HTTPS 443 / HTTP 80 (production) | Internet | Caddy (filtrage, en-têtes), WordPress durci, WPScan à chaque déploiement. |
| SSH 22 | **Personne par défaut** | Ouvert seulement pour l'IP du runner CI, le temps d'un job. |
| API Azure | Jobs GitHub autorisés | OIDC, *subject* exact, RBAC limité au resource group. |
| Registre GHCR | GitHub | Publication seulement après scan. Lecture par la VM avec un jeton éphémère. |
| Dépôt GitHub | Contributeurs | Branche protégée, checks requis, approbation pour la production. |

## 8.3 Menaces et mesures

| # | Menace | STRIDE | Mesures | Risque résiduel |
|---|---|---|---|---|
| T1 | Exploitation d'un plugin WordPress vulnérable | E, T | WPScan bloquant avant production ; plugins par défaut retirés ; `DISALLOW_FILE_EDIT` ; pas d'exécution PHP dans `uploads/` ; conteneur non-root sans capabilities. | Vulnérabilité publiée **après** le dernier déploiement, sur un plugin installé. |
| T2 | Brute force / énumération des comptes | S | Énumération bloquée par Caddy ; `xmlrpc.php` bloqué (vecteur courant de brute force) ; mot de passe administrateur aléatoire de 32 caractères. | Pas de limitation de débit sur `wp-login.php`. Piste : `rate_limit` Caddy ou CrowdSec. |
| T3 | Vol des identifiants Azure de la CI | S, E | **Aucun secret** : OIDC fédéré, jeton d'environ 1 h, *subject* lié à un environnement GitHub restreint à `main`. | Compromission du compte GitHub du propriétaire. Atténuation : 2FA, approbation requise. |
| T4 | Action GitHub compromise (chaîne d'approvisionnement) | T | Actions épinglées **par SHA** ; permissions minimales par job ; `persist-credentials: false`. | Une action légitime, épinglée, mais malveillante dès l'origine. |
| T5 | Image de base contenant une CVE critique | T, E | Trivy bloquant avant publication ; rescan quotidien de l'image en production ; SBOM archivé. | CVE sans correctif (`ignore-unfixed`) : visible dans l'onglet Security, non bloquante. |
| T6 | Substitution d'image entre scan et déploiement | T | Déploiement **par digest** ; Ansible refuse un tag. | Pas de signature d'image. Piste : cosign. |
| T7 | Secret committé dans le dépôt | I | gitleaks sur tout l'historique, bloquant ; `.gitignore` sur les fichiers générés. | Secret dans un format non reconnu par gitleaks. |
| T8 | Accès SSH par un attaquant | S, E | Port fermé hors jobs CI ; clé uniquement ; root interdit ; fail2ban ; `AllowUsers`. | Clé de déploiement volée **et** port ouvert au même moment. |
| T9 | Écoute ou altération du trafic | I, T | HTTPS obligatoire, HSTS, TLS géré par Caddy. | — |
| T10 | Lecture du state Terraform (contient des secrets) | I | Stockage sans clé d'accès, RBAC par conteneur, isolation staging/production. | Les identités de CI peuvent le lire, par conception. Piste : Key Vault. |
| T11 | Rançongiciel / suppression des sauvegardes depuis la VM | T, D | Soft delete 14 jours, hors de portée du SAS ; chiffrement restic. | Compromission du compte Azure lui-même. |
| T12 | Sauvegarde inutilisable découverte trop tard | D | Test de restauration à chaque déploiement et chaque semaine ; alertes si ces tests s'arrêtent. | — |
| T13 | Panne non détectée | D | Sondes interne et externe ; test d'alerte à chaque déploiement. | Une seule VM : pas de bascule automatique. |
| T14 | Modification malveillante du cœur WordPress | T | Cœur en tmpfs, recopié depuis l'image à chaque démarrage. | La modification persiste jusqu'au prochain redémarrage. |
| T15 | Accès aux interfaces de supervision | I | Prometheus et Alertmanager liés à `127.0.0.1`, accès par tunnel SSH. | — |
| T16 | Déploiement non autorisé en production | E | Approbation manuelle sur l'environnement `production` ; `concurrency` ; historique des runs. | Le propriétaire est aussi le seul reviewer, ce qui est inhérent à un projet solo. |
| T17 | Contestation d'une action (« ce n'est pas moi ») | R | Historique git, journal des runs GitHub, journal d'activité Azure, auditd sur la VM. | Journaux non centralisés. Piste : Log Analytics. |

## 8.4 Hors périmètre

- Attaques sur l'infrastructure Azure ou GitHub elles-mêmes.
- Déni de service volumétrique. Il relève d'un CDN ou d'Azure DDoS Protection, hors budget étudiant.
- Menace interne d'un administrateur Azure légitime.
- Sécurité du contenu publié sur le site.
