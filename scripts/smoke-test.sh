#!/usr/bin/env bash
# Tests de fumée post-déploiement : le site répond, et les protections
# attendues sont effectivement en place côté client.
#
# Usage : smoke-test.sh <fqdn> [--insecure]
#   --insecure : accepte un certificat non public (staging, CA interne Caddy)
set -uo pipefail

readonly FQDN="${1:?fqdn}"
CURL_OPTS=(-sS --max-time 15 --retry 10 --retry-delay 6 --retry-all-errors)
[[ "${2:-}" == "--insecure" ]] && CURL_OPTS+=(-k)

failures=0
check() {
  local description="$1"; shift
  if "$@"; then
    printf '  [OK]    %s\n' "${description}"
  else
    printf '  [ÉCHEC] %s\n' "${description}"
    failures=$((failures + 1))
  fi
}

status_of() { curl "${CURL_OPTS[@]}" -o /dev/null -w '%{http_code}' "$1"; }
status_matches() { [[ "$(status_of "$1")" =~ $2 ]]; }

headers="$(curl "${CURL_OPTS[@]}" -D - -o /dev/null "https://${FQDN}/" | tr -d '\r')"
header_present() { grep -qi "^$1:" <<<"${headers}"; }
header_absent() { ! grep -qi "^$1:" <<<"${headers}"; }

echo "Tests de fumée sur https://${FQDN}"
check "page d'accueil en 200"                   test "$(status_of "https://${FQDN}/")" = "200"
check "HTTP redirigé vers HTTPS"                status_matches "http://${FQDN}/" '^30[178]$'
check "en-tête Strict-Transport-Security"       header_present strict-transport-security
check "en-tête X-Content-Type-Options"          header_present x-content-type-options
check "en-tête X-Frame-Options"                 header_present x-frame-options
check "en-tête Referrer-Policy"                 header_present referrer-policy
check "pas d'en-tête Server"                    header_absent server
check "pas d'en-tête X-Powered-By"              header_absent x-powered-by
check "xmlrpc.php bloqué (403)"                 test "$(status_of "https://${FQDN}/xmlrpc.php")" = "403"
check "énumération REST des comptes bloquée"    test "$(status_of "https://${FQDN}/wp-json/wp/v2/users")" = "403"
check "énumération ?author= bloquée"            test "$(status_of "https://${FQDN}/?author=1")" = "403"
check "readme.html absent ou bloqué"            status_matches "https://${FQDN}/readme.html" '^40[34]$'

if (( failures > 0 )); then
  echo "${failures} test(s) en échec"
  exit 1
fi
echo "Tous les tests de fumée sont passés"
