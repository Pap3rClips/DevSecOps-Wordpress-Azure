#!/usr/bin/env bash
# Transforme les sorties Terraform d'un environnement en entrées Ansible :
#   <out>/inventory.yml  (hôte, utilisateur, FQDN)
#   <out>/secrets.yml    (secrets applicatifs, mode 0600, à supprimer après usage)
# Dans GitHub Actions, chaque secret est masqué dans les journaux.
#
# Usage : render-ansible-inputs.sh <dossier-terraform> <dossier-sortie> <environnement>
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage : $0 <dossier-terraform> <dossier-sortie> <environnement>" >&2
  exit 2
fi

readonly TF_DIR="$1" OUT_DIR="$2" ENVIRONMENT="$3"

umask 077
mkdir -p "${OUT_DIR}"
outputs="$(terraform -chdir="${TF_DIR}" output -json)"

json() { jq -r "$1" <<<"${outputs}"; }

host="$(json '.public_ip.value')"
user="$(json '.admin_username.value')"
fqdn="$(json '.fqdn.value')"

# Masquage des secrets dans les journaux GitHub Actions.
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  while IFS= read -r secret; do
    [[ -n "${secret}" ]] && echo "::add-mask::${secret}"
  done < <(jq -r '.app_secrets.value[], .backup.value.sas_token, .backup.value.restic_password' <<<"${outputs}")
fi

cat > "${OUT_DIR}/inventory.yml" <<EOF
all:
  hosts:
    app:
      ansible_host: ${host}
      ansible_user: ${user}
      ansible_ssh_common_args: >-
        -o UserKnownHostsFile=${OUT_DIR}/known_hosts
        -o StrictHostKeyChecking=accept-new
      wp_env: ${ENVIRONMENT}
      wp_fqdn: ${fqdn}
EOF

# Sérialisation JSON (sous-ensemble valide de YAML) : aucun problème
# d'échappement, quelle que soit la valeur des secrets.
jq '{
  db_root_password:       .app_secrets.value.db_root_password,
  db_password:            .app_secrets.value.db_password,
  wp_admin_password:      .app_secrets.value.wp_admin_password,
  wp_salt_seed:           .app_secrets.value.wp_salt_seed,
  restic_password:        .backup.value.restic_password,
  backup_storage_account: .backup.value.storage_account,
  backup_container:       .backup.value.container,
  backup_sas_token:       .backup.value.sas_token
}' <<<"${outputs}" > "${OUT_DIR}/secrets.yml"

chmod 600 "${OUT_DIR}/secrets.yml"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "host=${host}"
    echo "fqdn=${fqdn}"
    echo "resource_group=$(json '.resource_group_name.value')"
    echo "nsg=$(json '.nsg_name.value')"
  } >> "${GITHUB_OUTPUT}"
fi

echo "Entrées Ansible générées pour ${ENVIRONMENT} (${fqdn})"
