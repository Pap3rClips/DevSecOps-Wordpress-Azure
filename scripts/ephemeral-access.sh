#!/usr/bin/env bash
# Ouvre ou ferme un accès réseau temporaire, limité à l'adresse IP publique du
# runner CI, sur le NSG d'un environnement. Aucun port d'administration n'est
# ouvert en permanence : l'accès n'existe que pendant le job.
#
# Usage : ephemeral-access.sh open|close <resource-group> <nsg> [ports]
#   ports : liste séparée par des espaces (défaut : "22")
set -euo pipefail

readonly ACTION="${1:?open|close}" RG="${2:?resource group}" NSG="${3:?nsg}"
readonly PORTS="${4:-22}"
readonly RULE_NAME="ci-ephemeral-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}"

case "${ACTION}" in
  open)
    runner_ip="$(curl -fsS --max-time 10 https://api.ipify.org)"
    if [[ ! "${runner_ip}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
      echo "Adresse IP du runner invalide : '${runner_ip}'" >&2
      exit 1
    fi
    # shellcheck disable=SC2086 # découpage voulu de la liste de ports
    az network nsg rule create \
      --resource-group "${RG}" --nsg-name "${NSG}" --name "${RULE_NAME}" \
      --priority 200 --direction Inbound --access Allow --protocol Tcp \
      --source-address-prefixes "${runner_ip}/32" \
      --destination-port-ranges ${PORTS} \
      --description "Accès éphémère CI (run ${GITHUB_RUN_ID:-local})" \
      --output none
    echo "Accès ouvert pour ${runner_ip}/32 sur les ports ${PORTS}"
    ;;
  close)
    az network nsg rule delete \
      --resource-group "${RG}" --nsg-name "${NSG}" --name "${RULE_NAME}" \
      --output none
    echo "Accès éphémère fermé"
    ;;
  *)
    echo "Action inconnue : ${ACTION}" >&2
    exit 2
    ;;
esac
