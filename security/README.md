# security/

Exceptions aux contrôles bloquants. Politique complète : [ADR 0002](../docs/adr/0002-seuils-de-blocage.md).

| Fichier | Contrôle concerné |
|---|---|
| [`wpscan-allowlist.json`](wpscan-allowlist.json) | Gate WPScan |
| [`../.trivyignore.yaml`](../.trivyignore.yaml) | Trivy (CVE d'image) |
| Commentaires `#trivy:ignore:` dans Terraform | Trivy (configuration), au plus près de la ressource |

## Ajouter une exception WPScan

```json
{
  "ids": ["CVE-2026-12345"],
  "justification": "Plugin désactivé, retrait planifié dans la PR #42.",
  "expires": "2026-11-30"
}
```

Les trois champs sont obligatoires. Une exception **expirée fait échouer le pipeline** : elle doit être réévaluée, pas oubliée.
Toute exception passe par une pull request relue.
