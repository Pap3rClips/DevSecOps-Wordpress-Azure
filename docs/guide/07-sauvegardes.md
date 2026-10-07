# 7. Sauvegardes

## 7.1 Ce qui est sauvegardé

| Donnée | Méthode | Pourquoi |
|---|---|---|
| Base MariaDB | `mariadb-dump --single-transaction` | Instantané cohérent sans bloquer le site : InnoDB fournit une vue figée le temps du dump. |
| `wp-content` | copie de fichiers | Uploads, plugins et thèmes installés. |
| Cœur WordPress | **non sauvegardé** | Il est dans l'image, reconstructible à l'identique depuis le code ([chapitre 4](04-image-wordpress.md#43-le-cœur-immuable)). |

## 7.2 L'outil : restic

restic est un outil de sauvegarde moderne :

- **chiffrement côté client**, avant l'envoi : Azure ne voit que des données chiffrées ;
- **déduplication** : seuls les blocs modifiés sont envoyés, donc une sauvegarde quotidienne coûte très peu ;
- **vérification d'intégrité** intégrée (`restic check`).

Il est installé depuis le binaire officiel, en version épinglée et **vérifiée par SHA-256**. La version des dépôts Ubuntu est trop ancienne pour l'option `--stdin-from-command`.

### Pourquoi `--stdin-from-command`

L'approche naïve consiste à envoyer le dump dans restic par un pipe :

```bash
mariadb-dump … | restic backup --stdin   # à éviter
```

Si `mariadb-dump` échoue à mi-parcours, restic a déjà reçu un dump tronqué… et crée un instantané qui a l'air valide.
Avec `--stdin-from-command`, restic lance lui-même la commande et **n'enregistre l'instantané que si elle réussit**.

## 7.3 Le stockage : Azure Blob

| Protection | Effet |
|---|---|
| Jeton SAS limité au conteneur `restic` | La VM ne détient jamais la clé du compte de stockage. |
| SAS à durée de vie bornée | Rotation tous les 90 jours via Terraform, avec 30 jours de marge. |
| Pare-feu du compte | N'accepte que le trafic du subnet de la VM. |
| **Soft delete 14 jours** | Si un attaquant prend la VM et supprime les sauvegardes, elles restent récupérables pendant 14 jours. C'est la protection contre un rançongiciel. |
| Réplication ZRS (production) | Copie sur trois zones de disponibilité. |

## 7.4 Planification et rétention

Un timer systemd lance `wp-backup` chaque nuit à 2 h 30. Un délai aléatoire de 15 minutes maximum est ajouté, et le timer est `Persistent` : si la VM était éteinte, la sauvegarde se lance au démarrage.

Rétention (`restic forget --prune`) :

- 7 sauvegardes quotidiennes ;
- 4 hebdomadaires ;
- 6 mensuelles.

Le service tourne avec une priorité basse (`Nice=10`, `IOSchedulingClass=idle`) pour ne pas ralentir le site.

## 7.5 Le test de restauration

Une sauvegarde n'existe que si l'on a prouvé qu'on sait la restaurer. `/usr/local/sbin/wp-restore-test` :

| Étape | Action | Ce qu'elle prouve |
|---|---|---|
| 1 | Écrit une **sentinelle unique** (horodatage + aléa) dans la table `wp_options` de la vraie base. | — |
| 2 | Lance une sauvegarde. | La sauvegarde fonctionne. |
| 3 | Restaure le dernier instantané dans un répertoire temporaire. | Le dépôt est lisible, le mot de passe est le bon, le SAS est valide. |
| 4 | Démarre une MariaDB **éphémère sans réseau** (`--network none`) et y importe le dump. | Le dump est un SQL valide et complet. |
| 5 | Lit la sentinelle dans la base restaurée et la compare. | C'est bien **la sauvegarde de l'instant** qui est restaurée, pas un vieil instantané. |
| 6 | Vérifie `wp-content`, puis relit 5 % des données du dépôt (`restic check --read-data-subset=5%`). | Les fichiers sont présents, les données stockées ne sont pas corrompues. |

La base éphémère n'a aucun accès réseau : un dump piégé ne pourrait rien atteindre.
Tout est nettoyé à la fin (`trap cleanup EXIT`), même en cas d'échec.

En cas de succès, le script publie `wp_restore_test_last_success_timestamp_seconds`, surveillé par l'alerte `RestoreTestTooOld`.

**Quand il s'exécute :**

- en staging, à chaque déploiement : il bloque le déploiement s'il échoue ;
- en production, chaque lundi (`restore-test.yml`).

## 7.6 Restaurer pour de vrai

La procédure manuelle de restauration de la production est dans le [runbook](../runbook.md#restaurer-la-production).
