# syntax=docker/dockerfile:1
# -----------------------------------------------------------------------------
# Image WordPress durcie. C'est CETTE image (identifiée par son digest) qui est
# scannée par Trivy en CI puis déployée : ce qui est testé est ce qui tourne.
# Base épinglée sur une version précise ; Dependabot propose les mises à jour.
# -----------------------------------------------------------------------------
FROM wordpress:7.1.2-php8.4-apache

ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832

LABEL org.opencontainers.image.title="wordpress-hardened" \
      org.opencontainers.image.description="WordPress durci pour le pipeline DevSecOps" \
      org.opencontainers.image.source="https://github.com/Pap3rClips/devsecops-wordpress-azure" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Correctifs de sécurité Debian disponibles au moment du build : réduit les
# CVE corrigeables remontées par Trivy entre deux versions de l'image de base.
# hadolint ignore=DL3005
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# WP-CLI, vérifié par empreinte SHA-512 (aucun binaire téléchargé sans contrôle).
RUN curl -fsSLo /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && echo "${WP_CLI_SHA512}  /usr/local/bin/wp" | sha512sum -c - \
    && chmod 0755 /usr/local/bin/wp

# Durcissement PHP et Apache.
COPY php-security.ini /usr/local/etc/php/conf.d/zz-security.ini
COPY apache-security.conf /etc/apache2/conf-available/zz-security.conf
RUN a2enconf zz-security \
    && a2dismod -f status autoindex \
    && rm -f /usr/src/wordpress/readme.html /usr/src/wordpress/license.txt

# Réduction de la surface d'attaque : on retire les plugins livrés par défaut
# et tous les thèmes sauf le thème par défaut de cette version de WordPress.
# (Le cœur WordPress est recopié depuis /usr/src/wordpress à chaque démarrage
# du conteneur : ce qui n'est pas dans l'image ne revient pas.)
RUN rm -rf /usr/src/wordpress/wp-content/plugins/akismet \
           /usr/src/wordpress/wp-content/plugins/hello.php \
    && default_theme="$(sed -n "s/.*define( *'WP_DEFAULT_THEME', *'\([a-z0-9-]*\)'.*/\1/p" /usr/src/wordpress/wp-includes/default-constants.php)" \
    && test -n "${default_theme}" \
    && find /usr/src/wordpress/wp-content/themes -mindepth 1 -maxdepth 1 -type d ! -name "${default_theme}" -exec rm -rf {} + \
    && test -d "/usr/src/wordpress/wp-content/themes/${default_theme}"

# Exécution sans privilèges : Apache écoute sur 8080 (port non privilégié) et
# tourne directement sous www-data. Le conteneur peut alors abandonner toutes
# les capabilities Linux (cap_drop: ALL dans compose).
RUN sed -ri 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -ri 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf \
    && grep -q '^Listen 8080$' /etc/apache2/ports.conf \
    && grep -q '<VirtualHost \*:8080>' /etc/apache2/sites-available/000-default.conf

# www-data (UID/GID 33 dans les images Debian)
USER 33:33
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["curl", "-fsS", "-o", "/dev/null", "http://localhost:8080/wp-login.php"]
