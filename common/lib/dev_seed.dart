// Local dev-account IDs used to seed the secure storage when launching the
// Mocked / FamilyMocked simulator schemes. The mocked entry points read
// these constants and write an active JsonAccount into secure storage so the
// app skips paywall + first-account-create on launch and proceeds directly
// to the home screen against the real backend.
//
// This file is committed with placeholder values so the codebase builds in a
// fresh checkout. Edit it locally with your dev account IDs to run the
// Mocked / FamilyMocked schemes; do NOT commit your personal IDs. See
// ios/SIMULATOR.md for the workflow (including how to tell jj/git to ignore
// your local edits).

const familyDevAccountId = 'REPLACE_WITH_FAMILY_DEV_ACCOUNT_ID';
const sixDevAccountId = 'REPLACE_WITH_SIX_DEV_ACCOUNT_ID';
