# Documentation

Cette documentation explique le projet de bout en bout : ce qu'il fait, comment chaque brique fonctionne, pourquoi elle a été conçue ainsi, et comment le reproduire.

## Par où commencer

| Vous avez… | Lisez |
|---|---|
| **5 minutes** | Le [README principal](../README.md), puis la [vue d'ensemble](guide/01-vue-d-ensemble.md). |
| **30 minutes**, profil technique | Le guide dans l'ordre (chapitres 1 à 8), puis les [décisions d'architecture](adr/). |
| **Un abonnement Azure** et l'envie de le faire tourner | [Mise en place](setup.md), puis [démonstrations de blocage](demo-blocage.md). |
| **Un incident** à traiter | [Runbook](runbook.md). |

## Guide technique

| # | Chapitre | Contenu |
|---|---|---|
| 1 | [Vue d'ensemble](guide/01-vue-d-ensemble.md) | Le problème, les objectifs, le parcours complet d'un commit jusqu'à la production. |
| 2 | [Infrastructure (Terraform)](guide/02-infrastructure-terraform.md) | Bootstrap, identités OIDC, module réutilisable, réseau, VM, stockage. |
| 3 | [Configuration (Ansible)](guide/03-configuration-ansible.md) | Les quatre rôles, l'ordre d'exécution, la gestion des secrets. |
| 4 | [Image WordPress](guide/04-image-wordpress.md) | Durcissement, exécution non-root, cœur immuable. |
| 5 | [Pipeline CI/CD](guide/05-pipeline-ci-cd.md) | Les quatre workflows, chaque job, chaque contrôle bloquant. |
| 6 | [Supervision](guide/06-supervision.md) | Prometheus, sondes, alertes, et le test qui prouve qu'elles fonctionnent. |
| 7 | [Sauvegardes](guide/07-sauvegardes.md) | restic, Azure Blob, rétention, et le test de restauration. |
| 8 | [Modèle de menace](guide/08-modele-de-menace.md) | Ce contre quoi le projet protège, et ce qu'il ne couvre pas. |
| — | [Glossaire](guide/glossaire.md) | Les termes techniques, expliqués simplement. |

## Référence

- [Architecture](architecture.md) : schémas Azure et réseau de la stack.
- [Décisions d'architecture (ADR)](adr/) : le *pourquoi* de chaque choix structurant.
- [Mise en place](setup.md) : du bootstrap Azure au premier déploiement.
- [Démonstrations de blocage](demo-blocage.md) : prouver que les contrôles bloquent.
- [Runbook](runbook.md) : procédures d'exploitation et de réponse à incident.
