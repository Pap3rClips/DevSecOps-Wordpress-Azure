# Runbook

Procédures pour les alertes et les opérations courantes.
Toutes les commandes VM supposent un accès SSH ouvert pour votre IP (voir [setup.md](setup.md#5-accès-à-la-supervision)).

## WordPressDown / SiteUnreachableFromInternet

```bash
cd /srv/wordpress
sudo docker compose ps
sudo docker compose logs --tail=100 wordpress caddy db
sudo docker compose up -d     # relance les services arrêtés
```

Si la base est en cause, consultez `docker compose logs db`. MariaDB refuse de démarrer si le disque est plein : voir `DiskSpaceLow`.

## BackupFailed / BackupTooOld

```bash
sudo systemctl status wp-backup.service
sudo journalctl -u wp-backup.service -n 100
sudo /usr/local/sbin/wp-backup        # relance manuelle
```

Causes fréquentes :

- **Jeton SAS expiré.** Redéployez : Terraform le renouvelle automatiquement passé la date de rotation.
- **Base arrêtée.** Le dump échoue.
- **Règle réseau du compte de stockage modifiée.**

## Restaurer la production

> À ne faire qu'après avoir vérifié la sauvegarde visée : `restic snapshots`.

```bash
sudo -i
set -a; . /etc/restic/env; set +a
restic snapshots --host production

cd /srv/wordpress
docker compose stop wordpress caddy

# Base de données
restic dump latest --host production --tag wp-db /wordpress.sql \
  | docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot'

# wp-content
mv wp-content "wp-content.avant-restauration.$(date +%s)"
restic restore latest --host production --tag wp-content --target / --include /srv/wordpress/wp-content
chown -R 33:33 wp-content

docker compose start wordpress caddy
```

Ensuite, contrôlez le site, puis lancez `sudo /usr/local/sbin/wp-restore-test`.

## Rotation des secrets applicatifs

```bash
cd terraform/environments/production
terraform apply -replace=module.stack.random_password.wp_salt_seed   # invalide toutes les sessions
```

Puis redéployez via le workflow CD. Pour les mots de passe de base de données, un changement nécessite aussi une mise à jour dans MariaDB : planifiez une fenêtre de maintenance.

## Compromission suspectée

1. **Isoler** : supprimez la règle NSG `allow-web-internet` depuis le portail ou la CLI.
2. **Préserver** : prenez un snapshot du disque OS depuis Azure, pour l'analyse.
3. **Reconstruire depuis le code** : détruisez la VM, puis redéployez. L'infrastructure est entièrement reproductible.
4. **Restaurer les données** depuis un instantané **antérieur** à la compromission. Le soft delete conserve 14 jours de blobs supprimés.
5. **Faire tourner tous les secrets**, et révoquer puis recréer la clé SSH de déploiement.
