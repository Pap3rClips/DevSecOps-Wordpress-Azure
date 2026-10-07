# Mise en place

Compter environ 30 minutes. Prérequis : un abonnement Azure dont vous êtes *Owner* (Azure for Students convient),
Azure CLI, Terraform ≥ 1.9, et un fork ou une copie de ce dépôt sur GitHub.

## 1. Bootstrap Azure (une seule fois, en local)

```bash
az login
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # renseigner subscription_id et github_repository
terraform init
terraform apply
terraform output github_variables
```

Cette étape crée le stockage du state, les deux resource groups, les deux identités de CI fédérées avec GitHub et leurs droits.
Elle enregistre aussi les *resource providers* Azure nécessaires (Compute, Network, Storage) : l'identité de CI n'a pas les droits pour le faire elle-même.

Le state du bootstrap reste local (`terraform.tfstate`, exclu par `.gitignore`). Conservez-le, il sert à tout supprimer proprement.

## 2. Clé SSH de déploiement

Générez une clé dédiée à la CI, sans phrase de passe :

```bash
ssh-keygen -t ed25519 -C "ci-deploy" -f ./id_deploy -N ""
```

## 3. Configuration GitHub

### Variables du dépôt

*Settings → Secrets and variables → Actions → Variables*

| Variable | Valeur |
|---|---|
| `AZURE_TENANT_ID` | sortie du bootstrap |
| `AZURE_SUBSCRIPTION_ID` | sortie du bootstrap |
| `TFSTATE_RESOURCE_GROUP` | sortie du bootstrap |
| `TFSTATE_STORAGE_ACCOUNT` | sortie du bootstrap |
| `DNS_LABEL_PREFIX` | préfixe DNS unique, par ex. `wpsec-hadrien` |
| `SSH_PUBLIC_KEY` | contenu de `id_deploy.pub` |
| `ACME_EMAIL` | adresse pour Let's Encrypt et le compte admin WordPress |

### Secrets du dépôt

| Secret | Valeur |
|---|---|
| `SSH_PRIVATE_KEY` | contenu de `id_deploy` |
| `WPSCAN_API_TOKEN` | jeton gratuit sur [wpscan.com](https://wpscan.com/register) (25 requêtes/jour) |

Supprimez ensuite les fichiers `id_deploy*` locaux, ou rangez-les dans un gestionnaire de mots de passe.

### Environnements

*Settings → Environments*

| Environnement | Variable `AZURE_CLIENT_ID` | Protection |
|---|---|---|
| `staging` | identité *staging* | branche `main` uniquement |
| `production` | identité *production* | branche `main` + **reviewer obligatoire** (vous) |
| `production-ops` | identité *production* | branche `main` uniquement |

Pour recevoir les alertes, ajoutez le secret optionnel `ALERT_DISCORD_WEBHOOK` sur l'environnement `production`.

### Protection de la branche `main`

*Settings → Branches* (ou *Rules*) :

- pull request obligatoire avant fusion ;
- checks requis : tous les jobs du workflow **CI** ;
- historique linéaire, aucun push forcé.

### Visibilité de l'onglet Security

Les rapports SARIF de Trivy apparaissent dans *Security → Code scanning*.
C'est gratuit sur un dépôt public.

## 4. Premier déploiement

Poussez sur `main`. Le workflow **CD** déroule les étapes suivantes :

1. les contrôles CI ;
2. le build, le scan et la publication de l'image ;
3. le staging éphémère, de sa création à sa destruction ;
4. l'attente de votre approbation, puis la production.

Le site est ensuite disponible sur `https://<DNS_LABEL_PREFIX>.francecentral.cloudapp.azure.com`.
Le mot de passe du compte `site-owner` se lit dans le state :

```bash
cd terraform/environments/production
terraform init -backend-config=resource_group_name=<...> -backend-config=storage_account_name=<...>
terraform output -json app_secrets | jq -r .wp_admin_password
```

## 5. Accès à la supervision

```bash
# Ouvrir temporairement SSH pour votre IP (CLI Azure connectée)
scripts/ephemeral-access.sh open rg-wpsec-production nsg-wpsec-production 22
make tunnel HOST=<ip-publique>
# Prometheus : http://localhost:9090 · Alertmanager : http://localhost:9093
scripts/ephemeral-access.sh close rg-wpsec-production nsg-wpsec-production
```
