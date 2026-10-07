"""Tests du contrôle bloquant WPScan : le gate doit bloquer ce qu'il faut,
laisser passer le reste, et ne jamais être contourné silencieusement."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import wpscan_gate  # noqa: E402

TODAY = "2026-10-07"


def clean_report(**overrides):
    report = {
        "vuln_api": {"plan": "free", "requests_done_during_scan": 3, "requests_remaining": 22},
        "version": {"number": "7.1.2", "vulnerabilities": []},
        "main_theme": {"slug": "twentytwentyfive", "vulnerabilities": []},
        "plugins": {},
        "themes": {},
        "interesting_findings": [
            {"type": "headers", "to_s": "Headers"},
            {"type": "robots_txt", "to_s": "robots.txt found"},
        ],
    }
    report.update(overrides)
    return report


def vulnerable_plugin(slug="contact-form-7", cve="2020-35489", wpvulndb="7391118e-eef5-4ff8-a8ea-f6b65f442c63"):
    return {
        slug: {
            "slug": slug,
            "version": {"number": "5.3.1"},
            "vulnerabilities": [
                {
                    "title": "Contact Form 7 < 5.3.2 - Unrestricted File Upload",
                    "fixed_in": "5.3.2",
                    "references": {"cve": [cve], "wpvulndb": [wpvulndb]},
                }
            ],
        }
    }


def run(tmp_path, report, allowlist=None, extra_args=()):
    report_path = tmp_path / "wpscan.json"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    args = [str(report_path), "--today", TODAY, *extra_args]
    if allowlist is not None:
        allow_path = tmp_path / "allowlist.json"
        allow_path.write_text(json.dumps(allowlist), encoding="utf-8")
        args += ["--allowlist", str(allow_path)]
    return wpscan_gate.main(args)


def test_clean_report_passes(tmp_path):
    assert run(tmp_path, clean_report()) == 0


def test_vulnerable_plugin_blocks(tmp_path, capsys):
    assert run(tmp_path, clean_report(plugins=vulnerable_plugin())) == 1
    out = capsys.readouterr().out
    assert "BLOQUANT" in out
    assert "CVE-2020-35489" in out


def test_core_vulnerability_blocks(tmp_path):
    report = clean_report(
        version={"number": "5.0", "vulnerabilities": [{"title": "Core RCE", "references": {"cve": ["2019-8942"]}}]}
    )
    assert run(tmp_path, report) == 1


def test_xmlrpc_finding_blocks(tmp_path):
    findings = clean_report()["interesting_findings"] + [{"type": "xmlrpc", "to_s": "XML-RPC seems to be enabled"}]
    assert run(tmp_path, clean_report(interesting_findings=findings)) == 1


def test_missing_api_blocks_by_default(tmp_path):
    report = clean_report(vuln_api={"error": "No WPScan API Token given"})
    assert run(tmp_path, report) == 1


def test_missing_api_can_be_explicitly_allowed(tmp_path):
    report = clean_report(vuln_api={"error": "No WPScan API Token given"})
    assert run(tmp_path, report, extra_args=["--allow-no-api"]) == 0


def test_valid_exception_lets_vulnerability_through(tmp_path, capsys):
    allowlist = {
        "exceptions": [
            {"ids": ["CVE-2020-35489"], "justification": "Plugin désactivé, retrait planifié.", "expires": "2026-12-31"}
        ]
    }
    assert run(tmp_path, clean_report(plugins=vulnerable_plugin()), allowlist) == 0
    assert "exception acceptée" in capsys.readouterr().out


def test_expired_exception_blocks(tmp_path, capsys):
    allowlist = {"exceptions": [{"ids": ["CVE-2020-35489"], "justification": "Temporaire.", "expires": "2026-01-01"}]}
    assert run(tmp_path, clean_report(plugins=vulnerable_plugin()), allowlist) == 1
    assert "expirée" in capsys.readouterr().out


def test_exception_without_justification_is_rejected(tmp_path):
    allowlist = {"exceptions": [{"ids": ["CVE-2020-35489"], "justification": " ", "expires": "2026-12-31"}]}
    assert run(tmp_path, clean_report(plugins=vulnerable_plugin()), allowlist) == 1


def test_exception_for_other_cve_does_not_apply(tmp_path):
    allowlist = {"exceptions": [{"ids": ["CVE-1999-0001"], "justification": "Autre.", "expires": "2026-12-31"}]}
    assert run(tmp_path, clean_report(plugins=vulnerable_plugin()), allowlist) == 1


def test_aborted_scan_blocks(tmp_path):
    assert run(tmp_path, {"scan_aborted": "The remote website is up, but does not seem to be running WordPress."}) == 1


def test_unreadable_report_is_usage_error(tmp_path):
    bad = tmp_path / "wpscan.json"
    bad.write_text("{not json", encoding="utf-8")
    assert wpscan_gate.main([str(bad)]) == 2


def test_duplicate_main_theme_counted_once():
    theme = {"slug": "old", "vulnerabilities": [{"title": "XSS", "references": {"cve": ["2021-1"]}}]}
    report = clean_report(main_theme=theme, themes={"old": theme})
    vulns = wpscan_gate.collect_vulnerabilities(report)
    assert len({v.title for v in vulns}) == 1


def test_summary_file_is_written(tmp_path):
    summary = tmp_path / "summary.md"
    run(tmp_path, clean_report(plugins=vulnerable_plugin()), extra_args=["--summary", str(summary)])
    assert "Contrôle WPScan : BLOQUANT" in summary.read_text(encoding="utf-8")


@pytest.mark.parametrize("cve_value", ["2020-35489", "CVE-2020-35489"])
def test_cve_normalisation(cve_value):
    vuln = {"references": {"cve": [cve_value]}}
    assert wpscan_gate._vuln_ids(vuln) == frozenset({"CVE-2020-35489"})
