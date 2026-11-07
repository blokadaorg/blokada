#!/usr/bin/env python3
"""Publish an automated device review (.github/workflows/device-review.yml).

    device-review-publish.py --scope scope.json --review review.json \
        --shots DIR --smoke success|failure|... --version 26.11.1232 \
        --build 1232 --run-url URL [--dry-run]

scope.json is release_scope.py --json for the build (from blokadaorg/workflows,
the app-rollout skill); review.json is the review agent's structured output.

The agent's output is untrusted: it read PR and issue text. Everything it can
influence is checked here, not trusted:
- the verdict is computed from the per-PR results and the smoke, never read;
- a PR in scope that the agent did not report becomes `unclear`, and PRs
  outside the scope are dropped;
- comments go only to the tracker issues the scope links to that PR;
- text is length-capped, code fences and @mentions are neutralised;
- screenshots must be files the review job produced, named review-*.jpg.

Writes, with GH_TOKEN (the blokada-ci App, issue-tracker only): screenshots to
the image-only release-review branch, one comment per glitch on its issues,
and the report into the description of the milestone named after the version.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
from typing import Any

TRACKER = "blokadaorg/issue-tracker"
BRANCH = "release-review"
# Store listing copy and CI-only changes have nothing to drive on a device.
REVIEWED_KINDS = {"app", "deps", "strings"}
RESULTS = {"pass", "glitch", "unclear"}
FLAVORS = {"six", "family", "both"}
SHOT_NAME = re.compile(r"^review-[A-Za-z0-9-]{1,70}\.jpg$")
CAPS = {"summary": 120, "steps": 1500, "expected": 600, "seen": 600, "log_excerpt": 3000}


def clean(text: Any, cap: int) -> str:
    value = str(text or "").replace("\r", "").strip()
    value = value.replace("```", "'''")
    # A zero-width space after @ keeps a mention from notifying anyone.
    value = re.sub(r"@(?=\w)", "@​", value)
    if len(value) > cap:
        value = value[: cap - 1] + "…"
    return value


def one_line(text: Any, cap: int) -> str:
    return clean(re.sub(r"\s+", " ", str(text or "")), cap)


def jpg_name(name: Any) -> str:
    """The review job converts each review-*.png to a JPEG of the same stem."""
    stem = str(name).rsplit("/", 1)[-1]
    stem = re.sub(r"\.(png|jpe?g)$", "", stem, flags=re.IGNORECASE)
    return f"{stem}.jpg"


def build_items(scope: dict[str, Any], review: dict[str, Any], shots: set[str]) -> list[dict[str, Any]]:
    by_pr: dict[int, dict[str, Any]] = {}
    for item in review.get("items") or []:
        if isinstance(item, dict) and isinstance(item.get("pr"), int):
            by_pr.setdefault(item["pr"], item)

    items = []
    for pr in scope.get("prs") or []:
        if pr.get("pr") is None or pr.get("kind") not in REVIEWED_KINDS:
            continue
        found = by_pr.get(pr["pr"], {})
        result = found.get("result") if found.get("result") in RESULTS else "unclear"
        # A result must say which apps it covers; one that does not is not a check.
        if found.get("flavor") not in FLAVORS:
            result = "unclear"
        summary = one_line(found.get("summary") or ("not reviewed" if not found else ""), CAPS["summary"])
        items.append({
            "pr": pr["pr"],
            "title": one_line(pr.get("title"), 80),
            "issues": [int(n) for n in pr.get("issues") or []],
            "result": result,
            "summary": summary or "no summary",
            "flavor": one_line(found.get("flavor"), 12),
            "steps": clean(found.get("steps"), CAPS["steps"]),
            "expected": clean(found.get("expected"), CAPS["expected"]),
            "seen": clean(found.get("seen"), CAPS["seen"]),
            "log_excerpt": clean(found.get("log_excerpt"), CAPS["log_excerpt"]),
            "screenshots": [n for n in map(jpg_name, found.get("screenshots") or []) if n in shots][:4],
        })
    return items


def verdict(items: list[dict[str, Any]], smoke: str, reviewed: bool = True) -> str:
    """ship only with a usable review, a green smoke and every PR passing."""
    ok = reviewed and smoke == "success" and all(i["result"] == "pass" for i in items)
    return "ship" if ok else "hold"


def report(version: str, build: int, date: str, run_url: str, smoke: str, items: list[dict[str, Any]],
           reviewed: bool = True) -> str:
    lines = [
        f"App release {version} (build {build})",
        f"Device review of build {build}, {date}, automated on the CI phone: {run_url}",
        f"Smoke: iOS {smoke}",
    ]
    for i in items:
        issues = ", ".join(f"#{n}" for n in i["issues"])
        lines.append(f"{i['result']:<7} #{i['pr']} {i['summary']}" + (f" ({issues})" if issues else ""))
    lines.append("Operator spot-checks: third-party keyboard, free-form support chat")
    if not reviewed:
        lines.append("Review output missing or unreadable: see the run")
    lines.append(f"Verdict: {verdict(items, smoke, reviewed)}")
    return "\n".join(lines)


def shot_path(version: str, run_id: str, pr: int, name: str) -> str:
    """run_id is <run id>-<attempt>: unique per attempt, so a rerun never writes an existing file (which needs its sha)."""
    return f"{version}/{run_id}/pr-{pr}-{name.removeprefix('review-')}"


def comment(version: str, build: int, run_url: str, item: dict[str, Any], links: list[str]) -> str:
    parts = [
        f"**Device review glitch** in {version} (build {build}), PR blokadaorg/blokada#{item['pr']}, "
        f"automated run: {run_url}",
        f"**{item['summary']}**" + (f" ({item['flavor']})" if item["flavor"] else ""),
    ]
    for key, label in (("steps", "Steps"), ("expected", "Expected"), ("seen", "Seen")):
        if item[key]:
            parts.append(f"{label}:\n{item[key]}")
    parts += [f"![screenshot]({link})" for link in links]
    if item["log_excerpt"]:
        parts.append(f"App log:\n```\n{item['log_excerpt']}\n```")
    parts.append("Written by an agent from an automated review; confirm before acting on it.")
    return "\n\n".join(parts)


def gh(args: list[str], body: dict[str, Any] | None = None) -> Any:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        if body is not None:
            json.dump(body, handle)
        path = handle.name
    try:
        cmd = ["gh", "api", *args] + (["--input", path] if body is not None else [])
        result = subprocess.run(cmd, capture_output=True, text=True)
    finally:
        os.unlink(path)
    if result.returncode != 0:
        raise RuntimeError(f"gh api {' '.join(args)}: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def branch_exists() -> bool:
    result = subprocess.run(["gh", "api", f"repos/{TRACKER}/branches/{BRANCH}", "--silent"], capture_output=True)
    return result.returncode == 0


def upload(path: str, data: bytes) -> str:
    content = base64.b64encode(data).decode()
    if branch_exists():
        gh(["-X", "PUT", f"repos/{TRACKER}/contents/{path}"],
           {"message": f"review {path}", "branch": BRANCH, "content": content})
    else:
        # The first image starts the branch as a root commit, so it never
        # carries a copy of main and has nothing to merge.
        blob = gh([f"repos/{TRACKER}/git/blobs"], {"content": content, "encoding": "base64"})["sha"]
        tree = gh([f"repos/{TRACKER}/git/trees"],
                  {"tree": [{"path": path, "mode": "100644", "type": "blob", "sha": blob}]})["sha"]
        commit = gh([f"repos/{TRACKER}/git/commits"], {"message": f"review {path}", "tree": tree})["sha"]
        gh([f"repos/{TRACKER}/git/refs"], {"ref": f"refs/heads/{BRANCH}", "sha": commit})
    return f"https://github.com/{TRACKER}/blob/{BRANCH}/{path}?raw=true"


REVIEW_START = re.compile(r"^Device review of build \d+")


def merge_description(old: str, version: str, report_text: str) -> str:
    """The report replaces the header, the pick line and an earlier review; other lines stay below it.

    An earlier review runs from its "Device review of build" line to its
    "Verdict:" line. Without that end line only the start line goes, so no
    note is ever dropped.
    """
    lines = (old or "").splitlines()
    drop: set[int] = set()
    for start, line in enumerate(lines):
        if REVIEW_START.match(line):
            end = next((k for k in range(start, len(lines)) if lines[k].startswith("Verdict:")), start)
            drop.update(range(start, end + 1))
    kept = [
        line for k, line in enumerate(lines)
        if k not in drop and not line.startswith(f"App release {version}") and not line.startswith("Picked ")
    ]
    notes = "\n".join(kept).strip()
    return report_text + (f"\n\n{notes}" if notes else "")


def write_milestone(version: str, report_text: str) -> None:
    # One page: the tracker has a handful of milestones, release ones included.
    milestones = gh([f"repos/{TRACKER}/milestones?state=all&per_page=100&sort=due_on&direction=desc"])
    match = next((m for m in milestones or [] if m["title"] == version), None)
    if match:
        description = merge_description(match.get("description") or "", version, report_text)
        gh(["-X", "PATCH", f"repos/{TRACKER}/milestones/{match['number']}"], {"description": description})
    else:
        gh([f"repos/{TRACKER}/milestones"], {"title": version, "description": report_text})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    for name in ("scope", "review", "shots", "smoke", "version", "run-url", "run-id", "date"):
        parser.add_argument(f"--{name}", required=True)
    parser.add_argument("--build", type=int, required=True)
    parser.add_argument("--dry-run", action="store_true")
    opts = parser.parse_args()

    if not re.fullmatch(r"\d{2}\.\d{1,2}\.\d{4,}", opts.version) or not opts.version.endswith(f".{opts.build}"):
        raise RuntimeError(f"version {opts.version} does not name build {opts.build}")
    with open(opts.scope) as handle:
        scope = json.load(handle)
    if scope.get("build") != opts.build:
        raise RuntimeError(f"scope is for build {scope.get('build')}, not {opts.build}")
    reviewed = True
    try:
        with open(opts.review) as handle:
            review = json.load(handle)
        if not isinstance(review, dict) or not isinstance(review.get("items"), list):
            raise ValueError("not an object with an items list")
    except (OSError, ValueError) as error:
        reviewed = False
        # No usable review output: every PR is reported unclear, the verdict is hold.
        print(f"::warning::no review output ({error}); every PR is unclear", file=sys.stderr)
        review = {}
    shots = {n for n in os.listdir(opts.shots) if SHOT_NAME.match(n)} if os.path.isdir(opts.shots) else set()

    items = build_items(scope, review, shots)
    text = report(opts.version, opts.build, opts.date, opts.run_url, opts.smoke, items, reviewed)
    print(text)
    if opts.dry_run:
        return 0

    if not re.fullmatch(r"\d+-\d+", opts.run_id):
        raise RuntimeError(f"run id {opts.run_id} is not <run id>-<attempt>")
    uploaded: dict[str, str] = {}
    for item in items:
        if item["result"] != "glitch" or not item["issues"]:
            continue
        links = []
        for name in item["screenshots"]:
            path = shot_path(opts.version, opts.run_id, item["pr"], name)
            if path not in uploaded:
                with open(os.path.join(opts.shots, name), "rb") as handle:
                    uploaded[path] = upload(path, handle.read())
            links.append(uploaded[path])
        body = comment(opts.version, opts.build, opts.run_url, item, links)
        for issue in item["issues"]:
            gh([f"repos/{TRACKER}/issues/{issue}/comments"], {"body": body})
    write_milestone(opts.version, text)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, KeyError, json.JSONDecodeError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)
