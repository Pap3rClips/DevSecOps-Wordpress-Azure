# 3. Configuration (Ansible)

Terraform crée une VM Ubuntu vierge. Ansible la transforme en serveur durci qui fait tourner WordPress.
Ansible est **idempotent** : on peut rejouer le même playbook autant de fois que nécessaire, il n'applique que les différences.

```
ansible/
├── site.yml               # playbook de déploiement
├── test-monitoring.yml    # test de la chaîne d'alerte
├── test-restore.yml       # test de restauration
├── group_vars/all.yml     # valeurs par défaut (versions d'images, rétention…)
└── roles/
    ├── hardening/         # système d'exploitation
    ├── docker/            # moteur de conteneurs
    ├── stack/             # application + supervision
    └── backup/            # sauvegardes
```

## 3.1 Entrées : d'où viennent les variables

Ansible reçoit trois sources de variables, sans qu'aucun secret ne soit écrit dans le dépôt.

| Fichier | Produit par | Contenu |
|---|---|---|
| `inventory.yml` | `scripts/render-ansible-inputs.sh` | Adresse IP, utilisateur, FQDN, environnement |
| `secrets.yml` (mode 600) | `scripts/render-ansible-inputs.sh`, depuis les sorties Terraform | Mots de passe, jeton SAS, graine de salage |
| `runtime.yml` (mode 600) | le workflow CD | Image par digest, jeton GHCR éphémère, e-mail ACME |

Le script de rendu émet `::add-mask::` pour chaque secret : GitHub les remplace par `***` dans les journaux.
Les fichiers sont supprimés à la fin du job, même en cas d'échec.

## 3.2 Les pré-vérifications

`site.yml` commence par deux plays de garde.

1. **Attendre la VM.** `wait_for_connection`, puis `cloud-init status --wait`. Juste après sa création, une VM Ubuntu installe encore ses mises à jour et tient le verrou APT.
2. **Valider les entrées.** Une assertion vérifie la présence et la longueur minimale de chaque secret, et surtout que **l'image est référencée par digest** (`@sha256:`). Un tag mutable est refusé ([ADR 0005](../adr/0005-image-immuable-par-digest.md)).

## 3.3 Rôle `hardening`

| Mesure | Détail |
|---|---|
| Mises à jour automatiques | `unattended-upgrades` installe les correctifs de sécurité chaque jour. |
| SSH durci | Clé uniquement, root interdit, `MaxAuthTries 3`, pas de X11 ni d'agent forwarding, `AllowUsers` limité à l'utilisateur de déploiement. La config est validée par `sshd -t` **avant** d'être appliquée, pour ne jamais se couper l'accès. |
| fail2ban | Bannit une IP pendant 1 h après 4 échecs SSH en 10 min. |
| sysctl | Anti-spoofing (`rp_filter`), pas de redirections ICMP, SYN cookies, `kptr_restrict`, `dmesg_restrict`, BPF non privilégié désactivé… |
| ufw | Refus par défaut en entrée, seuls 22/80/443 sont ouverts. C'est une défense en profondeur derrière le NSG Azure. |
| auditd | Journalisation des événements de sécurité du noyau. |

> **Piège Docker / ufw.** Docker publie ses ports via iptables *avant* les règles d'ufw. Un port Docker lié à `0.0.0.0` serait donc exposé malgré ufw. C'est pourquoi Prometheus et Alertmanager sont liés explicitement à `127.0.0.1` dans `compose.yml`.

## 3.4 Rôle `docker`

Installe Docker Engine depuis le dépôt officiel. La clé GPG est stockée dans `/etc/apt/keyrings`, et le dépôt est déclaré avec `signed-by` : il ne peut être signé que par cette clé.

Configuration du démon (`daemon.json`) :

| Option | Effet |
|---|---|
| `no-new-privileges: true` | Aucun processus de conteneur ne peut gagner de privilèges via un binaire setuid. |
| `live-restore: true` | Les conteneurs survivent à un redémarrage du démon Docker. |
| `icc: false` | Pas de communication implicite entre conteneurs sur le bridge par défaut. |
| Rotation des journaux | 5 × 10 Mo par conteneur, le disque ne se remplit pas. |

## 3.5 Rôle `stack`

C'est le rôle principal. Il :

1. **crée l'arborescence** `/srv/wordpress` : `wp-content` appartient à l'UID 33 (www-data), et `db` est en mode 700 ;
2. **dépose les fichiers d'environnement** (`.env-db`, `.env-wordpress`) en mode 600, avec `no_log` pour qu'ils n'apparaissent pas dans la sortie Ansible ;
3. **dépose les configurations** générées depuis les templates : `compose.yml`, `Caddyfile`, Prometheus, règles d'alerte, Blackbox, Alertmanager ;
4. **démarre la stack** : connexion à GHCR avec le jeton éphémère, `docker compose up` avec attente des healthchecks, puis **déconnexion systématique** dans un bloc `always`, même en cas d'échec ;
5. **installe WordPress** au premier déploiement, via WP-CLI. Le mot de passe administrateur passe par l'**entrée standard** (`--prompt=admin_password`) et non en argument, où il serait visible dans la liste des processus ;
6. **applique les réglages de sécurité** : inscription fermée, commentaires et pings désactivés, indexation désactivée hors production ;
7. **installe le plugin de démonstration** si on le demande. Une assertion refuse cette étape hors staging.

### Les clés de salage WordPress

WordPress signe ses cookies de session avec huit clés (`AUTH_KEY`, `SECURE_AUTH_KEY`…). Une seule graine aléatoire est générée par Terraform.
Ansible en dérive les huit clés par `sha256(graine:NOM_DE_CLÉ)`. Elles sont stables d'un redémarrage à l'autre, donc les sessions survivent, et leur rotation tient en une commande (voir le [runbook](../runbook.md#rotation-des-secrets-applicatifs)).

## 3.6 Rôle `backup`

Détaillé au [chapitre 7](07-sauvegardes.md). En bref :

- installe restic depuis le binaire officiel, **vérifié par SHA-256** ;
- dépose ses paramètres dans `/etc/restic/env` (mode 600) ;
- initialise le dépôt s'il n'existe pas ;
- installe les scripts de sauvegarde et de test de restauration ;
- programme un timer systemd quotidien.

## 3.7 Qualité

`ansible-lint --profile production` est le profil le plus strict. Il s'exécute à chaque PR et passe sans aucun avertissement.
Il impose notamment :

- les noms de modules pleinement qualifiés (`ansible.builtin.apt`) ;
- un `changed_when` sur chaque commande ;
- un préfixe de rôle sur les variables (`backup_restic_version`) ;
- `set -o pipefail` dans les scripts shell.
