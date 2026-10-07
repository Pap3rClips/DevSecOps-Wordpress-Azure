# ADR 0001 — Authentification OIDC, aucun secret cloud

**Statut** : accepté

## Contexte

La CI doit créer et modifier des ressources Azure. L'approche classique consiste à stocker un *client secret* de service principal dans les secrets GitHub.
Ce secret a une longue durée de vie. Il fonctionne depuis n'importe où s'il fuit, que ce soit par un journal, une action tierce compromise ou un fork malveillant. Et sa rotation est souvent oubliée.

## Décision

GitHub Actions s'authentifie par **fédération d'identité OIDC** :

1. À chaque job, GitHub émet un jeton OIDC signé. Ce jeton décrit le contexte du job : dépôt, environnement.
2. Entra ID n'échange ce jeton contre un jeton Azure que si le *subject* correspond exactement à une identité fédérée déclarée, par exemple `repo:Pap3rClips/devsecops-wordpress-azure:environment:production`.
3. Le jeton Azure obtenu vit environ une heure.

On crée **une identité par environnement**. Chacune n'a de droits que sur son resource group et son conteneur de state Terraform.
Le stockage du state refuse toute authentification par clé (`shared_access_key_enabled = false`).

## Conséquences

- Aucun secret Azure à stocker, faire tourner ou risquer de divulguer.
- Une branche de fonctionnalité ou un fork ne peut pas obtenir de jeton : il faut un job rattaché à un environnement GitHub, lui-même restreint à `main`.
- Compromettre l'identité de staging ne donne aucun accès à la production.
- Contrepartie : le bootstrap doit être exécuté une fois par un humain disposant des droits *Owner*.
