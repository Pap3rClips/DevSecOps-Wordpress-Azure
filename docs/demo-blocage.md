# Démonstrations de blocage

Deux scénarios reproductibles qui montrent que les contrôles bloquent réellement.
Pensez à capturer les écrans des runs en échec : ce sont les preuves les plus parlantes du projet.

## 1. Régression d'infrastructure bloquée sur une pull request (Trivy)

Scénario réaliste : quelqu'un réactive l'authentification SSH par mot de passe « pour dépanner ».

```bash
git switch -c demo/regression-iac
sed -i 's/disable_password_authentication = true/disable_password_authentication = false/' \
  terraform/modules/wordpress-stack/main.tf
git commit -am "demo: authentification SSH par mot de passe"
git push -u origin demo/regression-iac
```

Ouvrez la pull request, puis observez :

- le job **Scan IaC et configuration (Trivy)** échoue sur `AZU-0039` (HIGH), *Password authentication should be disabled on Azure virtual machines* ;
- la fusion est impossible, puisque le check est requis ;
- le constat apparaît dans *Security → Code scanning*, sur la ligne fautive.

Fermez la PR sans la fusionner.

## 2. Plugin vulnérable bloqué avant la production (WPScan)

*Actions → CD → Run workflow*, avec `demo_vulnerable_plugin` = `contact-form-7:5.3.1`.

Cette version de Contact Form 7 est affectée par la CVE-2020-35489 (téléversement de fichier non restreint).

Déroulé attendu :

1. Les contrôles CI passent, et l'image est construite et publiée.
2. Le staging est créé, puis le plugin y est installé et activé. Le staging reste fermé à Internet.
3. Les tests de fumée passent : le site fonctionne.
4. **WPScan détecte le plugin vulnérable, et le gate échoue.** Le résumé du job liste la vulnérabilité et son identifiant.
5. Le staging est détruit.
6. Le job **Production** n'est pas exécuté.

> 📸 Capture à ajouter : `docs/img/demo-blocage.png` (résumé du job avec le gate en échec).

## 3. Pour aller plus loin en entretien

- **Une exception justifiée.** Ajoutez la CVE dans `security/wpscan-allowlist.json` avec une justification et une date d'expiration passée, puis relancez : le gate échoue quand même, parce que l'exception est expirée.
- **La supervision.** Le journal du job staging montre le test d'alerte : arrêt, alerte active en environ 75 s, puis résolution.
