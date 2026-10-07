# 4. Image WordPress

`docker/wordpress/Dockerfile` part de l'image officielle `wordpress:7.1.2-php8.4-apache` et la durcit.
Cette image est l'artefact central du projet : c'est elle qui est scannée, publiée, puis déployée **par son digest**.

## 4.1 Les étapes du Dockerfile

| Étape | Ce qu'elle fait | Pourquoi |
|---|---|---|
| `FROM` épinglé | Version exacte de WordPress et de PHP. | Build reproductible. Dependabot propose les montées de version par PR. |
| `apt-get upgrade` | Applique les correctifs Debian disponibles au moment du build. | Réduit les CVE corrigeables remontées par Trivy entre deux versions de l'image de base. |
| WP-CLI vérifié | Téléchargé puis comparé à son empreinte SHA-512. | Aucun binaire n'entre dans l'image sans contrôle d'intégrité. |
| `php-security.ini` | `expose_php Off`, erreurs masquées, cookies `HttpOnly` / `Secure` / `SameSite`, limites raisonnables. | Pas de fuite d'information, sessions protégées. |
| `apache-security.conf` | `ServerTokens Prod`, pas de listing de répertoire, `TRACE` désactivé, fichiers sensibles refusés, **aucune exécution PHP dans `uploads/`**. | Le dernier point neutralise la classe d'attaque la plus courante sur WordPress : téléverser un fichier `.php`, puis l'appeler. |
| Modules désactivés | `status`, `autoindex`. | Surface réduite. |
| Plugins par défaut retirés | `akismet` et `hello.php` sont supprimés de l'image. | Code inutile = surface d'attaque inutile. |
| Thèmes non utilisés retirés | Seul le thème par défaut de la version de WordPress est conservé. Il est lu dynamiquement dans `WP_DEFAULT_THEME`. | Idem, et le build reste correct quand WordPress change de thème par défaut. |
| **Non-root** | Apache écoute sur **8080** et tourne sous **UID 33** (www-data). | Voir ci-dessous. |
| `HEALTHCHECK` | `curl` sur `wp-login.php`. | Docker Compose attend que WordPress soit réellement prêt avant de démarrer le proxy. |

## 4.2 Pourquoi non-root, et ce que ça change

Par défaut, l'image officielle démarre Apache en root pour écouter sur le port 80, puis délègue les requêtes à des processus www-data.
Si une faille permet d'exécuter du code dans le processus maître, l'attaquant est root dans le conteneur.

En écoutant sur 8080, port non privilégié, Apache n'a plus besoin de root. Le conteneur peut alors **abandonner toutes les capabilities Linux** (`cap_drop: [ALL]` dans `compose.yml`).
Une évasion de conteneur devient beaucoup plus difficile.

C'est Trivy qui a signalé ce point (contrôle `DS-0002`) lors du premier scan du projet. Il a été **corrigé**, pas mis en exception.

## 4.3 Le cœur immuable

```yaml
tmpfs:
  - /var/www/html:uid=33,gid=33,mode=0755,size=256m
volumes:
  - ./wp-content:/var/www/html/wp-content
```

| Ce qui est | Où | Persistant ? |
|---|---|---|
| Cœur WordPress (PHP, `wp-admin`, `wp-includes`) | tmpfs, en mémoire | Non : recopié depuis l'image à chaque démarrage. |
| `wp-config.php` | tmpfs | Non : régénéré depuis les variables d'environnement. |
| `wp-content` (uploads, plugins, thèmes) | `/srv/wordpress/wp-content` | Oui, et sauvegardé. |

Conséquences :

- **une modification malveillante du cœur disparaît au redémarrage** ;
- **la version du cœur qui tourne est toujours celle de l'image scannée** : les mises à jour automatiques du cœur sont désactivées, et l'on met à jour en changeant le `FROM` ;
- un plugin ou thème retiré de l'image ne réapparaît pas au redémarrage.

## 4.4 Configuration injectée au démarrage

`WORDPRESS_CONFIG_EXTRA` (dans `compose.yml`) ajoute à `wp-config.php` :

| Constante | Effet |
|---|---|
| Détection de `X-Forwarded-Proto` | WordPress sait qu'il est servi en HTTPS derrière Caddy. |
| `WP_HOME` / `WP_SITEURL` | URL canonique fixée, impossible à modifier depuis l'admin. |
| `FORCE_SSL_ADMIN` | Administration en HTTPS uniquement. |
| `DISALLOW_FILE_EDIT` | Pas d'éditeur de code dans l'admin : un compte admin compromis ne peut pas injecter de PHP en deux clics. |
| `WP_AUTO_UPDATE_CORE = false` | Le cœur est géré par l'image. |
| `WP_DEBUG = false` | Pas de messages d'erreur détaillés. |

## 4.5 Ce qui entoure l'image : Caddy

Caddy est le reverse proxy placé devant WordPress. Il :

- obtient et renouvelle **automatiquement** le certificat Let's Encrypt en production. En staging, fermé à Internet, il utilise sa CA interne ;
- ajoute les en-têtes de sécurité : HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Opener-Policy` ;
- retire les en-têtes qui trahissent la pile technique (`Server`, `X-Powered-By`) ;
- **bloque** `xmlrpc.php`, les fichiers sensibles (`.git`, `.env`, `*.sql`, `*.bak`, `debug.log`…), `readme.html` et `license.txt` ;
- **bloque l'énumération des comptes** pour les visiteurs non connectés : `/wp-json/wp/v2/users`, `?rest_route=/wp/v2/users`, `?author=N`. Les utilisateurs connectés en ont besoin pour l'éditeur, d'où la condition sur le cookie `wordpress_logged_in_`.

Caddy tourne lui aussi avec un système de fichiers en lecture seule et la seule capability `NET_BIND_SERVICE`.

Tout cela est **vérifié après chaque déploiement** par `scripts/smoke-test.sh` : douze contrôles côté client. Ces protections sont prouvées, pas seulement supposées.
