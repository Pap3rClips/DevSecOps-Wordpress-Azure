# .github/workflows/

Automatisation GitHub. Explications détaillées : [guide, chapitre 5](../../docs/guide/05-pipeline-ci-cd.md).

| Fichier | Rôle |
|---|---|
| [`workflows/ci.yml`](ci.yml) | Contrôles bloquants sur chaque PR : gitleaks, linters, tests, Trivy config, Trivy image. |
| [`workflows/cd.yml`](cd.yml) | Build → scan → publication → staging éphémère (tests de sécurité) → approbation → production. |
| [`workflows/restore-test.yml`](restore-test.yml) | Test de restauration hebdomadaire en production. |
| [`workflows/image-rescan.yml`](image-rescan.yml) | Rescan quotidien de l'image en production. |
| [`actions/setup-tools/`](../actions/setup-tools/action.yml) | Action composite : Terraform, Python, Ansible et collections, aux versions épinglées. |
| [`dependabot.yml`](../dependabot.yml) | Mises à jour hebdomadaires : actions, image de base, providers Terraform, outils Python. |
| [`pull_request_template.md`](../pull_request_template.md) | Check-list d'impact sécurité pour chaque PR. |

Toutes les actions tierces sont **épinglées par SHA de commit**, avec la version en commentaire.
