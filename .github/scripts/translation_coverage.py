#!/usr/bin/env python3
"""Report per-locale translation coverage for the primary languages.

Run at release time (see .github/workflows/release-tag.yml). For each primary
language in deps/translate/langs.js it compares the committed translation JSON
under common/assets/translations/{ui,packs,packtags}/ against the English
baseline (en.json) and reports the percentage of source keys that are present,
non-empty, and actually differ from English (an identical copy means the string
was never translated).

Coverage lag is normal, so this NEVER fails the build: it writes a markdown
table to the run summary and emits ::warning:: annotations for primary
languages below 100%. Always exits 0.
"""

import json
import os
import sys
from pathlib import Path

# Repo layout: <root>/.github/scripts/translation_coverage.py
ROOT = Path(__file__).resolve().parents[2]
LANGS_JS = ROOT / "deps" / "translate" / "langs.js"
TRANSLATIONS = ROOT / "common" / "assets" / "translations"
CATEGORIES = ["ui", "packs", "packtags"]


def load_langs():
    """Parse the langs.js module the same way scripts/translate.py does."""
    text = LANGS_JS.read_text(encoding="utf-8").replace("export default ", "")
    data = json.loads(text)
    return data["langs"], data.get("langs-arb", {})


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def coverage(en, translated):
    """(covered, total) keys: present, non-empty, and differing from English."""
    total = len(en)
    if translated is None or total == 0:
        return 0, total
    covered = 0
    for key, src in en.items():
        val = translated.get(key)
        if isinstance(val, str) and val.strip() and val != src:
            covered += 1
    return covered, total


def pct(covered, total):
    return 100.0 * covered / total if total else 0.0


def main():
    primary, arb = load_langs()

    # Load the English baseline once per category.
    baselines = {cat: load_json(TRANSLATIONS / cat / "en.json") for cat in CATEGORIES}

    rows = []
    warnings = []
    for lang in primary:
        mapped = arb.get(lang, lang)
        per_cat = {}
        tot_cov = tot_all = 0
        for cat in CATEGORIES:
            en = baselines[cat]
            if not en:
                per_cat[cat] = None
                continue
            translated = load_json(TRANSLATIONS / cat / f"{mapped}.json")
            cov, tot = coverage(en, translated)
            per_cat[cat] = pct(cov, tot)
            tot_cov += cov
            tot_all += tot
        overall = pct(tot_cov, tot_all)
        rows.append((lang, mapped, per_cat, overall))
        if overall < 100.0:
            warnings.append((lang, mapped, overall))

    def cell(v):
        return f"{v:.1f}%" if v is not None else "n/a"

    lines = [
        "### Translation coverage (primary languages)",
        "",
        "| lang | file | ui | packs | packtags | overall |",
        "|------|------|----|-------|----------|---------|",
    ]
    for lang, mapped, per_cat, overall in rows:
        lines.append(
            f"| {lang} | `{mapped}.json` | {cell(per_cat['ui'])} | "
            f"{cell(per_cat['packs'])} | {cell(per_cat['packtags'])} | "
            f"**{overall:.1f}%** |"
        )
    lines.append("")
    lines.append(
        "_Coverage counts source keys that are present, non-empty, and differ "
        "from the English source. Strings that are legitimately identical to "
        "English (proper nouns, \"OK\", etc.) count as untranslated, so 100% is "
        "not always reachable; treat the numbers as a relative signal._"
    )
    report = "\n".join(lines) + "\n"

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(report)
    else:
        print(report)

    for lang, mapped, overall in warnings:
        print(
            f"::warning title=Translation coverage::{lang} ({mapped}) "
            f"overall {overall:.1f}% (< 100%)"
        )

    # Coverage lag is expected; never block a release.
    sys.exit(0)


if __name__ == "__main__":
    main()
