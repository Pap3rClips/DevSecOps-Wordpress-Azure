# ansible/

Configuration de la VM. Explications détaillées : [guide, chapitre 3](../docs/guide/03-configuration-ansible.md).

## Playbooks

| Playbook | Rôle |
|---|---|
| [`site.yml`](site.yml) | Déploiement complet : attente de la VM, validation des entrées, puis les quatre rôles. |
| [`test-monitoring.yml`](test-monitoring.yml) | Coupe WordPress et vérifie que l'alerte se déclenche puis se résout. |
| [`test-restore.yml`](test-restore.yml) | Sauvegarde fraîche, restauration isolée, vérification d'une sentinelle. |

## Rôles

| Rôle | Contenu |
|---|---|
| [`hardening`](roles/hardening/) | Mises à jour automatiques, SSH durci, fail2ban, sysctl, ufw, auditd. |
| [`docker`](roles/docker/) | Docker Engine depuis le dépôt officiel signé, démon durci. |
| [`stack`](roles/stack/) | `compose.yml` (Caddy, WordPress, MariaDB, Prometheus, Alertmanager, exporters), installation de WordPress, script de test d'alerte. |
| [`backup`](roles/backup/) | restic vérifié par SHA-256, timer systemd, scripts de sauvegarde et de test de restauration. |

## Variables attendues

Fournies par la CI, jamais commitées :

| Variable | Source |
|---|---|
| `wp_env`, `wp_fqdn` | inventaire généré depuis Terraform |
| `db_root_password`, `db_password`, `wp_admin_password`, `wp_salt_seed` | sorties Terraform |
| `restic_password`, `backup_storage_account`, `backup_container`, `backup_sas_token` | sorties Terraform |
| `wp_image` | job `build`, **référence par digest obligatoire** |
| `acme_email`, `ghcr_username`, `ghcr_token` | workflow CD |

Les valeurs par défaut (versions d'images, rétention, planning) sont dans [`group_vars/all.yml`](group_vars/all.yml).

## Exécution manuelle

```bash
make setup
ansible-playbook ansible/site.yml -i <inventaire> --private-key <clé> \
  -e @secrets.yml -e @runtime.yml
```
