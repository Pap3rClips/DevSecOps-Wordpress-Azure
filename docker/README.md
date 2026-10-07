# docker/

Image WordPress durcie. Explications détaillées : [guide, chapitre 4](../docs/guide/04-image-wordpress.md).

| Fichier | Rôle |
|---|---|
| [`wordpress/Dockerfile`](wordpress/Dockerfile) | Base épinglée, correctifs Debian, WP-CLI vérifié, plugins et thèmes inutiles retirés, exécution non-root sur 8080. |
| [`wordpress/php-security.ini`](wordpress/php-security.ini) | Durcissement PHP : pas de fuite de version ni d'erreurs, cookies sécurisés. |
| [`wordpress/apache-security.conf`](wordpress/apache-security.conf) | Durcissement Apache : pas de signature ni de listing, fichiers sensibles refusés, aucune exécution PHP dans `uploads/`. |

Le fichier `compose.yml` qui fait tourner l'image est généré par Ansible : [`roles/stack/templates/compose.yml.j2`](../ansible/roles/stack/templates/compose.yml.j2).

## En local

```bash
docker build -t wordpress-hardened:local docker/wordpress
trivy image --severity HIGH,CRITICAL --ignore-unfixed wordpress-hardened:local
```
