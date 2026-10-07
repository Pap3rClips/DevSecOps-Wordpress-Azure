# ADR 0004 — Supervision et sauvegardes testées

**Statut** : accepté

## Contexte

Une supervision qu'on n'a jamais vue sonner, et une sauvegarde qu'on n'a jamais restaurée, ne sont que des hypothèses.
Les défaillances typiques sont silencieuses :

- une règle d'alerte mal écrite ;
- une cible de sonde fausse ;
- un dump vide ;
- un mot de passe de dépôt perdu ;
- un jeton d'accès expiré.

## Décision

### Supervision

`wp-monitoring-test` s'exécute à chaque déploiement, en staging :

1. vérifie qu'aucune alerte `WordPressDown` n'est déjà active ;
2. **arrête WordPress** ;
3. attend que l'alerte soit active dans Alertmanager (API `/api/v2/alerts`), avec un délai maximal de 5 min ;
4. relance WordPress et attend qu'il redevienne sain ;
5. attend la **résolution** de l'alerte.

On vérifie l'alerte dans Alertmanager, et non dans Discord. Le test valide ainsi toute la chaîne métrique → règle → routage, sans dépendre d'un service externe.

### Sauvegardes

`wp-restore-test` s'exécute en staging à chaque déploiement, et chaque semaine en production :

1. écrit une **valeur sentinelle unique** (horodatage + aléa) dans la base ;
2. lance une sauvegarde ;
3. restaure le dernier instantané dans un répertoire temporaire ;
4. importe le dump dans une MariaDB **éphémère sans réseau** (`--network none`) ;
5. compare la sentinelle restaurée à celle écrite ;
6. vérifie `wp-content` et relit 5 % des données du dépôt (`restic check --read-data-subset`).

Une sentinelle **fraîche** prouve que c'est la sauvegarde de l'instant qui est restaurable, et pas un vieil instantané.

### Les tests sont eux-mêmes supervisés

Chaque script publie l'horodatage de son dernier succès. Les alertes `BackupTooOld` et `RestoreTestTooOld` se déclenchent si ces signaux s'arrêtent, par exemple si le timer est désactivé ou le workflow planifié cassé.

## Conséquences

- Une régression dans la configuration de supervision ou de sauvegarde **bloque le déploiement**.
- Le test de restauration en production crée un instantané supplémentaire par semaine. Son volume est négligeable grâce à la déduplication de restic.
