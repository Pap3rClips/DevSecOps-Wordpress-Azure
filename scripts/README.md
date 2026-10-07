# scripts/

Scripts appelés par les workflows. Tous passent `shellcheck` sans avertissement.

| Script | Rôle | Appelé par |
|---|---|---|
| [`wpscan_gate.py`](wpscan_gate.py) | Lit le rapport JSON de WPScan et **bloque** si une vulnérabilité, une exposition sensible ou une exception expirée est trouvée. Testé par [`tests/`](../tests/). | `cd.yml` (staging) |
| [`smoke-test.sh`](smoke-test.sh) | Douze vérifications côté client : disponibilité, redirection HTTPS, en-têtes de sécurité, absence de fuite de version, blocage de xmlrpc et de l'énumération des comptes. | `cd.yml` (staging, production) |
| [`ephemeral-access.sh`](ephemeral-access.sh) | Ouvre puis ferme une règle NSG autorisant **uniquement l'IP du runner**, le temps du job. | tous les workflows de déploiement |
| [`render-ansible-inputs.sh`](render-ansible-inputs.sh) | Transforme les sorties Terraform en inventaire et fichier de secrets Ansible (mode 600), et masque les secrets dans les journaux GitHub. | tous les workflows de déploiement |

## Exemples

```bash
python3 scripts/wpscan_gate.py rapport.json --allowlist security/wpscan-allowlist.json
scripts/smoke-test.sh wpsec.francecentral.cloudapp.azure.com
scripts/ephemeral-access.sh open rg-wpsec-production nsg-wpsec-production 22
```
