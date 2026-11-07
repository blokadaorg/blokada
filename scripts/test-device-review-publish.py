#!/usr/bin/env python3
"""Tests for scripts/device-review-publish.py: python3 scripts/test-device-review-publish.py"""

import importlib.util
import os
import unittest

spec = importlib.util.spec_from_file_location(
    "publish", os.path.join(os.path.dirname(os.path.abspath(__file__)), "device-review-publish.py")
)
publish = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publish)

SCOPE = {
    "build": 1232,
    "prs": [
        {"pr": 1430, "kind": "app", "title": "support: drop local cc commands", "issues": [538]},
        {"pr": 1443, "kind": "no-app", "title": "ci: something", "issues": []},
        {"pr": 1444, "kind": "strings", "title": "sync: update translate strings", "issues": []},
        {"pr": 1451, "kind": "app", "title": "fix(ui): grey strip", "issues": [551]},
        {"pr": None, "kind": "app", "title": "direct push", "issues": []},
    ],
}


class BuildItemsTest(unittest.TestCase):
    def test_every_reviewed_pr_gets_a_line_and_unreported_ones_are_unclear(self):
        review = {"items": [
            {"pr": 1430, "result": "pass", "summary": "chat opens", "flavor": "six"},
            {"pr": 9999, "result": "pass", "summary": "outside the scope"},
        ]}
        items = publish.build_items(SCOPE, review, set())
        self.assertEqual([i["pr"] for i in items], [1430, 1444, 1451])
        self.assertEqual([i["result"] for i in items], ["pass", "unclear", "unclear"])
        self.assertEqual(items[1]["summary"], "not reviewed")

    def test_issues_come_from_the_scope_not_the_agent(self):
        review = {"items": [{"pr": 1451, "result": "glitch", "summary": "strip", "issues": [1]}]}
        item = publish.build_items(SCOPE, review, set())[2]
        self.assertEqual(item["issues"], [551])

    def test_unknown_result_is_unclear_and_screenshots_must_exist(self):
        review = {"items": [{"pr": 1430, "result": "ship it", "summary": "x",
                             "screenshots": ["review-a.png", "../../etc/passwd", "review-b.jpg"]}]}
        review["items"][0]["flavor"] = "six"
        item = publish.build_items(SCOPE, review, {"review-a.jpg"})[0]
        self.assertEqual(item["result"], "unclear")
        self.assertEqual(item["screenshots"], ["review-a.jpg"])

    def test_text_is_capped_and_mentions_and_fences_neutralised(self):
        review = {"items": [{"pr": 1430, "result": "glitch", "summary": "@kar look\n" + "x" * 300,
                             "log_excerpt": "```\nend"}]}
        item = publish.build_items(SCOPE, review, set())[0]
        self.assertLessEqual(len(item["summary"]), 120)
        self.assertNotIn("@kar", item["summary"])
        self.assertNotIn("```", item["log_excerpt"])


class VerdictTest(unittest.TestCase):
    def items(self, *results):
        return [{"result": r} for r in results]

    def test_ship_only_when_all_pass_and_smoke_green(self):
        self.assertEqual(publish.verdict(self.items("pass", "pass"), "success"), "ship")
        self.assertEqual(publish.verdict(self.items("pass", "unclear"), "success"), "hold")
        self.assertEqual(publish.verdict(self.items("pass"), "failure"), "hold")
        self.assertEqual(publish.verdict([], "success"), "ship")

    def test_report_shape(self):
        items = publish.build_items(SCOPE, {"items": [{"pr": 1430, "result": "pass", "summary": "chat", "flavor": "both"}]}, set())
        text = publish.report("26.11.1232", 1232, "2026-11-10", "https://run", "success", items)
        lines = text.splitlines()
        self.assertEqual(lines[0], "App release 26.11.1232 (build 1232)")
        self.assertIn("pass    #1430 chat (#538)", lines)
        self.assertEqual(lines[-1], "Verdict: hold")

    def test_shot_path(self):
        self.assertEqual(publish.shot_path("26.11.1232", "42", 1451, "review-strip-1.jpg"), "26.11.1232/42/pr-1451-strip-1.jpg")

    def test_result_without_flavor_is_unclear(self):
        items = publish.build_items(SCOPE, {"items": [{"pr": 1430, "result": "pass", "summary": "chat"}]}, set())
        self.assertEqual(items[0]["result"], "unclear")

    def test_milestone_keeps_operator_notes(self):
        old = ("App release 26.11.1232 (build 1232)\nPicked 2026-11-10, device review pending\n"
               "Device review of build 1232, old\npass    #1 x\nVerdict: hold\n\nNote: hold for #1430 copy")
        merged = publish.merge_description(old, "26.11.1232", "App release 26.11.1232 (build 1232)\nVerdict: ship")
        self.assertEqual(merged, "App release 26.11.1232 (build 1232)\nVerdict: ship\n\nNote: hold for #1430 copy")
        self.assertEqual(publish.merge_description("", "26.11.1232", "R"), "R")


if __name__ == "__main__":
    unittest.main()
