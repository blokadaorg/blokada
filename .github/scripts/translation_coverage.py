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
languages below COVERAGE_WARN_THRESHOLD (default 80). Any unexpected error is
downgraded to a warning. Always exits 0.
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

# Below this overall percentage a primary language is flagged with a warning.
# Coverage counts only keys that differ from English, so fully-usable locales
# still land well under 100; the default flags genuinely-behind locales without
# warning on every language. Override via the env var to tune the signal.
THRESHOLD = float(os.environ.get("COVERAGE_WARN_THRESHOLD", "80"))


def warn(message):
    print(f"::warning title=Translation coverage::{message}")


def load_langs():
    """Parse the langs.js module the same way scripts/translate.py does."""
    text = LANGS_JS.read_text(encoding="utf-8").replace("export default ", "")
    data = json.loads(text)
    return data["langs"], data.get("langs-arb", {})


def load_json(path):
    """Load a translation file, or None if missing/unparseable (best-effort)."""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except (json.JSONDecodeError, OSError) as e:
        warn(f"could not read {path.name}: {e}; treating as uncovered")
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


def run():
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
        if overall < THRESHOLD:
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
        f"not reachable; languages below {THRESHOLD:.0f}% are flagged._"
    )
    report = "\n".join(lines) + "\n"

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(report)
    else:
        print(report)

    for lang, mapped, overall in warnings:
        warn(f"{lang} ({mapped}) overall {overall:.1f}% (< {THRESHOLD:.0f}%)")


def main():
    # Informational only: coverage lag is expected, and a release must never be
    # blocked by this. Downgrade any unexpected failure to a warning.
    try:
        run()
    except Exception as e:  # noqa: BLE001 - best-effort reporting
        warn(f"coverage report failed: {e}")
    sys.exit(0)


if __name__ == "__main__":
    main()
