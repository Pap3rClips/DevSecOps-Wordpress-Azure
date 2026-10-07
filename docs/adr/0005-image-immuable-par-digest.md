# ADR 0005 — Image immuable déployée par digest

**Statut** : accepté

## Contexte

Un tag Docker (`:latest`, `:1.2`) est un pointeur mutable. Entre le scan et le déploiement, il peut désigner une autre image.
De plus, l'image WordPress officielle copie le cœur dans un volume au premier démarrage. Les mises à jour suivantes de l'image ne touchent alors plus le code qui tourne réellement.

## Décision

1. **Scan avant publication.** L'image est construite localement sur le runner, scannée par Trivy, et publiée sur GHCR seulement si le scan passe.
2. **Déploiement par digest.** Le digest `sha256:…` obtenu à la publication est transmis à Ansible. Ansible **refuse** une référence sans digest (assertion dans `site.yml`).
3. **Cœur WordPress en tmpfs.** Seul `wp-content` est persistant. Le cœur est recopié depuis l'image à chaque démarrage, et les mises à jour automatiques du cœur sont désactivées (`WP_AUTO_UPDATE_CORE = false`). La version du cœur est toujours celle de l'image scannée.
4. **Plugins et thèmes par défaut retirés dans l'image.** Ce qui n'est pas dans l'image ne revient pas au redémarrage.
5. **Jeton GHCR éphémère.** La VM s'authentifie au registre avec le `GITHUB_TOKEN` du job, valable le temps du job, puis se déconnecte. Aucun identifiant de registre ne reste sur la VM.
6. **SBOM.** Un SBOM CycloneDX est archivé pour chaque image publiée.

## Conséquences

- Traçabilité complète : commit → image → digest → SBOM → déploiement.
- Mettre à jour WordPress revient à changer le `FROM` du Dockerfile. Dependabot propose ce changement par PR, et il passe par tous les contrôles.
- Les mises à jour de plugins restent gérées dans `wp-content`. Le rescan quotidien et WPScan à chaque déploiement couvrent ce risque.
