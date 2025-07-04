#!/usr/bin/env node

// Simple unit test for popup status logic
// Run with: node popup.test.js

import { determineStatusState, isValidDate } from "./popup-logic.js";

const tests = [
  {
    name: "Inactive app",
    input: { active: false, timestamp: "2024-12-31T23:59:59Z" },
    expected: { state: "inactive", messageKey: "status_inactive" },
  },
  {
    name: "Active subscription (far future)",
    input: { active: true, timestamp: "2099-12-31T23:59:59Z" },
    expected: { state: "active", messageKey: "status_blocking_active" },
  },
  {
    name: "Expired subscription",
    input: { active: true, timestamp: "2023-01-01T00:00:00Z" },
    expected: { state: "inactive", messageKey: "status_inactive" },
  },
  {
    name: "Expiring soon (3 days)",
    input: {
      active: true,
      timestamp: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    },
    expected: { state: "expiring", messageKey: "status_expiring_soon" },
  },
  {
    name: "Active freemium trial (5 days left)",
    input: {
      active: true,
      timestamp: "2023-01-01T00:00:00Z",
      freemium: true,
      freemiumYoutubeUntil: new Date(
        Date.now() + 5 * 24 * 60 * 60 * 1000,
      ).toISOString(),
    },
    expected: {
      state: "trial",
      messageKey: "status_trial_active",
      daysLeft: 5,
    },
  },
  {
    name: "Expired freemium trial (back to essentials)",
    input: {
      active: true,
      timestamp: "2023-01-01T00:00:00Z",
      freemium: true,
      freemiumYoutubeUntil: "2023-06-01T00:00:00Z",
    },
    expected: { state: "essentials", messageKey: "status_essentials_active" },
  },
  {
    name: "Invalid freemium date (treat as essentials)",
    input: {
      active: true,
      timestamp: "2023-01-01T00:00:00Z",
      freemium: true,
      freemiumYoutubeUntil: "invalid-date",
    },
    expected: { state: "essentials", messageKey: "status_essentials_active" },
  },
  {
    name: "Active freemium essentials (content blocking only)",
    input: {
      active: true,
      timestamp: "2023-01-01T00:00:00Z",
      freemium: true,
      // freemiumYoutubeUntil is undefined - user has basic freemium access
    },
    expected: { state: "essentials", messageKey: "status_essentials_active" },
  },
  {
    name: "Active freemium trial with Swift date format",
    input: {
      active: true,
      timestamp: "1970-01-01T00:00:00.000Z", // Expired account
      freemium: true,
      freemiumYoutubeUntil: "2025-07-04T10:42:47.072Z", // Swift ISO format
    },
    expected: {
      state: "trial",
      messageKey: "status_trial_active",
      daysLeft: Math.ceil(
        (new Date("2025-07-04T10:42:47.072Z") - new Date()) /
          (24 * 60 * 60 * 1000),
      ),
    },
  },
];

function runTests() {
  let passed = 0;
  let failed = 0;

  console.log("Running popup status state tests...\n");

  tests.forEach((test) => {
    const result = determineStatusState(test.input);
    const success =
      result.state === test.expected.state &&
      result.messageKey === test.expected.messageKey &&
      (test.expected.daysLeft === undefined ||
        result.daysLeft === test.expected.daysLeft);

    if (success) {
      console.log(`✓ ${test.name}`);
      passed++;
    } else {
      console.log(`✗ ${test.name}`);
      console.log(`  Expected: ${JSON.stringify(test.expected)}`);
      console.log(`  Actual:   ${JSON.stringify(result)}`);
      failed++;
    }
  });

  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  return failed === 0;
}

// Run tests if this is the main module
if (import.meta.url === `file://${process.argv[1]}`) {
  const success = runTests();
  process.exit(success ? 0 : 1);
}

export { runTests };
