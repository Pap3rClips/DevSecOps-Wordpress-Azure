# ADR 0002 — Seuils de blocage et exceptions

**Statut** : accepté

## Contexte

Un contrôle trop strict bloque tout et finit désactivé. Un contrôle trop laxiste ne bloque rien et devient décoratif.
Il faut un seuil défendable, et un moyen d'accepter un risque **explicitement** plutôt qu'en contournant le contrôle.

## Décision

### Seuils

| Contrôle | Seuil bloquant | Raison |
|---|---|---|
| Trivy image | CVE **HIGH** et **CRITICAL** **corrigeables** (`--ignore-unfixed`) | Bloquer sur une CVE sans correctif disponible n'offre aucune action possible. Elle reste visible dans l'onglet Security, et le rescan quotidien détecte le jour où un correctif paraît. |
| Trivy config | **HIGH** et **CRITICAL** | Les MEDIUM et LOW sont remontés mais non bloquants, voir ci-dessous. |
| WPScan | **Toute** vulnérabilité connue | Une vulnérabilité WordPress a presque toujours un correctif : mettre à jour ou retirer le plugin. |
| WPScan | Découvertes sensibles (xmlrpc, listing, sauvegardes exposées, inscription ouverte…) | Ce sont exactement les protections que le projet prétend appliquer. |
| WPScan | API de vulnérabilités absente | Sans l'API, WPScan ne remonte aucune vulnérabilité : un rapport vide serait trompeur. |

### Exceptions

Toute exception doit porter trois éléments : un **identifiant**, une **justification** et une **date d'expiration**.

- **Trivy, au niveau d'une ressource Terraform** : commentaire `#trivy:ignore:<ID>` placé juste au-dessus de la ressource, précédé de sa justification.
- **Trivy, pour une CVE d'image** : fichier `.trivyignore.yaml`, avec `statement` et `expired_at`.
- **WPScan** : fichier `security/wpscan-allowlist.json`, avec `ids`, `justification` et `expires`. Le gate **échoue** si une exception est expirée ou incomplète.

Une exception s'ajoute par pull request : elle est donc relue et tracée dans l'historique.

### Exceptions en vigueur

| ID | Ressource | Justification |
|---|---|---|
| `AZU-0047` | Règle NSG `allow-web-internet` (production) | Un site web public doit accepter 80/443 depuis Internet. Limitée à ces deux ports ; SSH n'est jamais ouvert ainsi. |
| `AZU-0012` | Compte de stockage du state | Les runners GitHub hébergés n'ont pas d'IP fixe, un pare-feu réseau bloquerait la CI. La protection repose sur l'identité : aucune clé, RBAC par conteneur, TLS 1.2+. Levée possible avec des runners auto-hébergés. |

### Constats MEDIUM/LOW connus (non bloquants)

- **Clés gérées par le client, chiffrement d'infrastructure, géo-réplication.** Coût et complexité disproportionnés pour ce périmètre.
- **Journalisation du stockage.** Piste d'amélioration, via les paramètres de diagnostic vers Log Analytics.
- **IP publique sur la carte réseau.** Volontaire pour une VM unique. L'alternative serait un Application Gateway ou Azure Bastion, hors budget étudiant.
- **NSG non associé à la carte réseau.** Faux positif : le NSG est associé au subnet, ce qui couvre la carte.

## Conséquences

- Un échec de pipeline signifie toujours quelque chose d'actionnable.
- Accepter un risque est une décision visible, relue et limitée dans le temps.
