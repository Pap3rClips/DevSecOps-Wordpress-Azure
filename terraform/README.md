# terraform/

Infrastructure Azure décrite en code. Explications détaillées : [guide, chapitre 2](../docs/guide/02-infrastructure-terraform.md).

| Dossier | Rôle | Qui l'exécute |
|---|---|---|
| [`bootstrap/`](bootstrap/) | Stockage du state, resource groups, identités OIDC et RBAC. | **Un humain, une seule fois** (`make bootstrap`). |
| [`modules/wordpress-stack/`](modules/wordpress-stack/) | Un environnement complet : réseau, NSG, VM, stockage des sauvegardes, secrets. | Appelé par les environnements. |
| [`environments/staging/`](environments/staging/) | Staging fermé à Internet, créé puis détruit à chaque déploiement. | La CI (`cd.yml`). |
| [`environments/production/`](environments/production/) | Production publique et persistante. | La CI, après approbation. |

## Variables du module `wordpress-stack`

| Variable | Défaut | Description |
|---|---|---|
| `environment` | — | `staging` ou `production` |
| `resource_group_name` | — | RG existant, créé par le bootstrap |
| `dns_label` | — | Label DNS de l'IP publique |
| `admin_ssh_public_key` | — | Clé publique de déploiement |
| `public_web_access` | `false` | Ouvre 80/443 à Internet |
| `admin_ssh_cidrs` | `[]` | CIDR autorisés en SSH en permanence (Internet entier refusé) |
| `vm_size` | `Standard_B2s` | Taille de la VM |
| `backup_replication_type` | `LRS` | Réplication du stockage des sauvegardes |
| `backup_soft_delete_days` | `14` | Rétention des blobs supprimés |

## Commandes utiles

```bash
terraform fmt -recursive                                   # formater
terraform -chdir=environments/production init \
  -backend-config=resource_group_name=<rg-tfstate> \
  -backend-config=storage_account_name=<compte>            # lire la production en local
terraform -chdir=environments/production output -json app_secrets
```
