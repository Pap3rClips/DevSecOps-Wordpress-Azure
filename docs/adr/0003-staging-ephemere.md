# ADR 0003 — Staging éphémère et fermé

**Statut** : accepté

## Contexte

Les tests de sécurité dynamiques (WPScan), le test d'alerte et le test de restauration ont besoin d'un environnement réel.
Les mener en production serait risqué. Un staging permanent coûte de l'argent et dérive avec le temps, par modifications manuelles et état résiduel.
Il expose aussi une surface d'attaque supplémentaire.

## Décision

Le staging est **créé au début de chaque déploiement et détruit à la fin**, même en cas d'échec (étape `if: always()`).

- **Fermé à Internet.** Le NSG n'autorise que l'adresse IP du runner, et seulement pendant le job.
- **TLS par la CA interne de Caddy.** Let's Encrypt ne pourrait pas valider un domaine fermé.
- **Démo de blocage cantonnée au staging.** Le plugin volontairement vulnérable n'est installable qu'ici. Ansible le refuse ailleurs, et le job de production est sauté lors d'une démo.

## Conséquences

- **Coût quasi nul**, de l'ordre de quelques minutes de VM par déploiement.
- **Reproductibilité prouvée à chaque run.** L'infrastructure est recréée depuis le code à chaque fois : si le code ne suffit plus à reconstruire l'environnement, le pipeline échoue immédiatement.
- **Contrepartie : un déploiement prend plus de temps**, la création de la VM comptant pour plusieurs minutes. C'est acceptable pour un site à faible fréquence de mise en production.
- **Une différence avec la production** : le mode TLS. Elle est couverte par les tests de fumée de la production.
