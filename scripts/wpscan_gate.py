#!/usr/bin/env python3
"""Contrôle bloquant sur un rapport WPScan (format JSON).

WPScan signale les vulnérabilités mais ne fait pas échouer un pipeline de
façon exploitable. Ce script lit le rapport et renvoie un code de sortie non
nul si :
  - une vulnérabilité connue est remontée (cœur, thème ou plugin) et n'est
    pas couverte par une exception valide de la liste d'autorisation ;
  - une « découverte intéressante » d'un type jugé bloquant est présente
    (xmlrpc actif, listing de répertoire, sauvegarde exposée, etc.) ;
  - l'API de vulnérabilités n'a pas été utilisée (sans elle, le scan ne
    détecte aucune vulnérabilité : un rapport vide ne prouverait rien).

Les exceptions vivent dans security/wpscan-allowlist.json, chacune avec une
justification et une date d'expiration obligatoires.

Codes de sortie : 0 = conforme, 1 = bloquant, 2 = erreur d'usage/entrée.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

# Types tels qu'émis par WPScan (nom de classe du modèle en snake_case).
DEFAULT_BLOCKING_FINDINGS = frozenset(
    {
        "xmlrpc",  # XML-RPC actif : bloqué par le reverse proxy, doit le rester
        "readme",  # readme.html exposé (divulgation de version)
        "registration",  # inscription publique ouverte
        "upload_directory_listing",
        "debug_log",
        "full_path_disclosure",
        "backup_db",
        "backup_folder",
        "config_backup",
        "db_export",
        "upload_sql_dump",
        "emergency_pwd_reset_script",
        "duplicator_installer_log",
        "search_replace_db2",
        "tmm_db_migrate",
        "fantastico_fileslist",
    }
)


@dataclass(frozen=True)
class Vulnerability:
    component: str
    title: str
    ids: frozenset[str]
    fixed_in: str | None

    def describe(self) -> str:
        fix = f" (corrigé en {self.fixed_in})" if self.fixed_in else " (pas de correctif)"
        ref = f" [{', '.join(sorted(self.ids))}]" if self.ids else ""
        return f"{self.component} : {self.title}{fix}{ref}"


@dataclass(frozen=True)
class Exception_:
    ids: frozenset[str]
    justification: str
    expires: dt.date


def _vuln_ids(vuln: dict[str, Any]) -> frozenset[str]:
    """Identifiants stables d'une vulnérabilité (CVE et ID WPScan)."""
    refs = vuln.get("references") or {}
    ids: set[str] = set()
    for cve in refs.get("cve") or []:
        ids.add(cve if str(cve).upper().startswith("CVE-") else f"CVE-{cve}")
    for wpvulndb in refs.get("wpvulndb") or []:
        ids.add(f"WPVDB-{wpvulndb}")
    if vuln.get("uuid"):
        ids.add(f"WPVDB-{vuln['uuid']}")
    return frozenset(ids)


def _vulns_of(component: str, data: dict[str, Any] | None) -> Iterable[Vulnerability]:
    if not data:
        return
    for vuln in data.get("vulnerabilities") or []:
        yield Vulnerability(
            component=component,
            title=str(vuln.get("title", "vulnérabilité sans titre")),
            ids=_vuln_ids(vuln),
            fixed_in=vuln.get("fixed_in"),
        )


def collect_vulnerabilities(report: dict[str, Any]) -> list[Vulnerability]:
    vulns: list[Vulnerability] = []
    version = report.get("version")
    if version:
        vulns += _vulns_of(f"WordPress {version.get('number', '?')}", version)
    main_theme = report.get("main_theme")
    if main_theme:
        vulns += _vulns_of(f"thème {main_theme.get('slug', '?')}", main_theme)
    for kind in ("themes", "plugins"):
        label = "thème" if kind == "themes" else "plugin"
        for slug, data in (report.get(kind) or {}).items():
            vulns += _vulns_of(f"{label} {slug}", data)
    # Un même thème peut apparaître dans main_theme et themes.
    unique = {(v.component, v.title, v.ids): v for v in vulns}
    return list(unique.values())


def load_allowlist(path: Path | None, today: dt.date) -> tuple[list[Exception_], list[str]]:
    """Charge les exceptions ; renvoie aussi les erreurs (format, expiration)."""
    if path is None or not path.exists():
        return [], []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [], [f"liste d'autorisation illisible : {exc}"]

    exceptions: list[Exception_] = []
    errors: list[str] = []
    for index, entry in enumerate(raw.get("exceptions", [])):
        where = f"exception n°{index + 1}"
        ids = entry.get("ids") or []
        justification = (entry.get("justification") or "").strip()
        if not ids or not justification or "expires" not in entry:
            errors.append(f"{where} : 'ids', 'justification' et 'expires' sont obligatoires")
            continue
        try:
            expires = dt.date.fromisoformat(entry["expires"])
        except ValueError:
            errors.append(f"{where} : date d'expiration invalide '{entry['expires']}'")
            continue
        if expires < today:
            errors.append(f"{where} ({', '.join(ids)}) : expirée le {expires}, à réévaluer")
            continue
        exceptions.append(Exception_(frozenset(ids), justification, expires))
    return exceptions, errors


def is_allowed(vuln: Vulnerability, exceptions: list[Exception_]) -> Exception_ | None:
    for exc in exceptions:
        if vuln.ids & exc.ids:
            return exc
    return None


def evaluate(
    report: dict[str, Any],
    exceptions: list[Exception_],
    blocking_findings: frozenset[str],
    require_api: bool,
) -> tuple[list[str], list[str]]:
    """Renvoie (motifs de blocage, informations non bloquantes)."""
    blocking: list[str] = []
    info: list[str] = []

    vuln_api = report.get("vuln_api") or {}
    if require_api and (not vuln_api or "error" in vuln_api):
        reason = vuln_api.get("error", "absente du rapport")
        blocking.append(f"API de vulnérabilités WPScan non utilisée ({reason})")

    for vuln in collect_vulnerabilities(report):
        exc = is_allowed(vuln, exceptions)
        if exc:
            info.append(f"exception acceptée jusqu'au {exc.expires} : {vuln.describe()} — {exc.justification}")
        else:
            blocking.append(f"vulnérabilité : {vuln.describe()}")

    for finding in report.get("interesting_findings") or []:
        kind = finding.get("type", "")
        text = f"{kind} : {finding.get('to_s', '')}"
        if kind in blocking_findings:
            blocking.append(f"découverte bloquante — {text}")
        else:
            info.append(f"découverte — {text}")

    users = report.get("users") or {}
    if users:
        info.append(f"comptes énumérés : {', '.join(sorted(users))}")

    return blocking, info


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("report", type=Path, help="rapport WPScan au format JSON")
    parser.add_argument("--allowlist", type=Path, default=None, help="exceptions justifiées (JSON)")
    parser.add_argument("--allow-no-api", action="store_true", help="ne pas exiger l'API de vulnérabilités")
    parser.add_argument("--summary", type=Path, default=None, help="écrit un résumé Markdown (ex. $GITHUB_STEP_SUMMARY)")
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Rapport WPScan illisible : {exc}", file=sys.stderr)
        return 2

    if "scan_aborted" in report:
        print(f"Scan WPScan interrompu : {report['scan_aborted']}", file=sys.stderr)
        return 1

    exceptions, allowlist_errors = load_allowlist(args.allowlist, args.today)
    blocking, info = evaluate(report, exceptions, DEFAULT_BLOCKING_FINDINGS, not args.allow_no_api)
    blocking = [f"liste d'autorisation : {e}" for e in allowlist_errors] + blocking

    verdict = "BLOQUANT" if blocking else "CONFORME"
    lines = [f"## Contrôle WPScan : {verdict}", ""]
    lines += [f"- :x: {b}" for b in blocking]
    lines += [f"- :information_source: {i}" for i in info]
    if not blocking and not info:
        lines.append("- Aucune vulnérabilité ni découverte.")
    output = "\n".join(lines)

    print(output)
    if args.summary:
        with args.summary.open("a", encoding="utf-8") as fh:
            fh.write(output + "\n")

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main())
