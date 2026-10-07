# tests/

Tests unitaires du gate WPScan ([`scripts/wpscan_gate.py`](../scripts/wpscan_gate.py)). Un contrôle de sécurité est du code : s'il régresse silencieusement, il laisse tout passer.

```bash
make test        # ou : pytest -v tests
```

| Catégorie | Cas couverts |
|---|---|
| Doit passer | rapport propre ; vulnérabilité couverte par une exception valide ; API absente explicitement autorisée |
| Doit bloquer | plugin vulnérable ; cœur vulnérable ; XML-RPC actif ; API de vulnérabilités absente ; scan interrompu |
| Exceptions | expirée ; sans justification ; portant sur une autre CVE |
| Robustesse | rapport illisible (code 2) ; dédoublonnage du thème principal ; normalisation des CVE ; écriture du résumé |
