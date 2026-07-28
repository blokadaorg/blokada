# Release pipeline

Design and runbook for how Blokada builds, versions and ships to the App Store
and Google Play.

The shape is continuous delivery to internal channels, plus a separate
promote-only release step:

- **Every merge to `main`** builds all four artifacts (six + family, iOS +
  Android) and uploads them to Play **internal** and **TestFlight**. Nothing is
  published and nothing is submitted for review.
- **Releasing** never builds. It takes a build number that is already uploaded
  and promotes it: to Play `alpha` + `beta`, and to an App Store version that is
  optionally submitted for review. Publishing is always a manual click.

The point is that the binary you ship is the exact binary that has been sitting
on internal, not a fresh build that merely came from the same commit.

## Why change the current pipeline

Three concrete problems:

1. **The publish path is never exercised until release day.** PR CI builds the
   app but never archives, signs or uploads, which is how the ITMS-91065
   signing regression merged green in #1133 and only exploded during the 26.2.18
   release.
2. **A version name does not identify a build.** `26.2.13/six/ios` and
   `26.2.13/six/android` are separate workflow runs with different version
   codes, so one version name refers to two different binaries.
3. **The version code cannot survive a re-run.** It is `GITHUB_RUN_NUMBER`, and
   GitHub does not increment that on re-run — only `attempt`. Re-running a
   failed release rebuilds with an identical code, which Play rejects. Run #13
   (`26.2.21/family/ios`) failed and the next tag was `26.2.22` rather than a
   re-run.

## Versioning

```
26.7.1042
│  │ └── build number: forever-incrementing counter
│  └──── month (1-12)
└─────── year, two digits
```

Calendar-derived, so nobody picks a number. The previous scheme used quarters
in the minor position, which carried no useful information.

Store codes are the same build number with an offset, identical on both
platforms:

```
versionCode / CURRENT_PROJECT_VERSION = 669000000 + build
```

The offset exists to sit above legacy Blokada 5 codes and is unchanged from the
current script.

### Why the build number has to be the patch component

Apple limits `CFBundleShortVersionString` to at most three period-separated
integers, so there is no room for a fourth component. The build number must
occupy the patch slot or live outside the version entirely.

### Headroom

Play caps `versionCode` at 2,100,000,000. With the 669,000,000 offset that
leaves 1,431,000,000 build numbers. At ~600/year (see below) it never runs out.

## Build number allocation

A git tag is the allocator. `release_context` claims the next number before
anything is built:

```bash
LAST=$(git ls-remote --tags origin 'refs/tags/build/*' \
       | sed 's#.*refs/tags/build/##' | sort -n | tail -1)
NEXT=$(( ${LAST:-999} + 1 ))
VERSION="$(date +%y).$(date +%-m).$NEXT"
git tag -a "build/$NEXT" -m "$VERSION" && git push origin "build/$NEXT"   # push loses a race => retry
```

The tag is **annotated with the version name**, and that annotation is the
authoritative record of it. This is not cosmetic: the version name is baked into
the binary at build time, so a build allocated in July is `26.7.1042` forever.
If the release job recomputed the version from the current date it would derive
`26.8.1042` for a build promoted in August and address a version that does not
exist. The release job reads the name back instead:

```bash
VERSION=$(git tag -l --format='%(contents:subject)' "build/$N")
```

Android does not strictly need this — promotion keys off the version *code*,
which is `669000000 + N` — but iOS does, because `deliver` looks a build up by
`app_version` together with `build_number`.

Properties that matter:

- **Forever increasing**, independent of any GitHub counter.
- **Re-run safe** — a re-run allocates a *fresh* number, which is correct.
- **Atomic** — the tag push either wins or fails, so it doubles as the lock.
- **Auditable** — `build/1042` points at the exact commit that produced it.

Failed runs leave an orphan `build/N` with no matching release tag. That is
expected; numbers are cheap and gaps are meaningless.

Rejected alternatives: `GITHUB_RUN_NUMBER` reuses values on re-run and resets to
1 if the workflow file is ever renamed or recreated, which would send codes
backwards permanently. `github.run_id` is ~30,339,020,750 — an order of
magnitude above Play's ceiling.

### Starting value

The counter starts at **1000**, so the first code is `669001000`, safely above
the current maximum of `669000015`. The gap is a deliberate marker of the scheme
change.

Marketing versions also stay ordered across the migration: last shipped is
`26.2.22`, first new is `26.7.1000`, and `26.7 > 26.2`. Apple requires
`CFBundleShortVersionString` to increase, so this matters.

## Workflow A — `ci-release.yml`

Trigger: `push` to `main`. **No path filters** — filtering would create commits
on main that were never proven publishable, which defeats the purpose.
Dependabot merges get proven end-to-end too.

```yaml
concurrency:
  group: ci-release
  cancel-in-progress: false
```

Cancelling mid-flight would strand a consumed build number and a half-finished
upload, so runs queue instead.

Jobs:

1. **allocate** — claim `build/N`, output the number.
2. **build** — matrix over `{six, family} × {ios, android}`, all four stamped
   with the same number via `make version`.
3. **upload** — Play **internal only**, iOS **TestFlight only**.

### Upload constraints on this path

**iOS must not use `deliver` here.** The current lanes set
`skip_app_version_update: false`, so every run creates an App Store version
record. On every merge that produces hundreds of junk versions, and it hard
fails the moment a real release sits in Pending Developer Release with *"You
cannot create a new version of the App in the current state."* Main would go red
for the whole duration of every release window. `upload_to_testflight` needs no
version record, so the continuous path uses that.

**Play must be internal only, without metadata.** `alpha` and `beta` require
review, and store listing changes are reviewed on both stores too. So
`publish-android` uploads the AAB to internal and passes all four skip flags
(`--skip_upload_metadata/changelogs/images/screenshots true`). It has no
promote step at all — that moves wholesale to `promote-android`. Metadata is a
release-time concern.

### Cost

~41 commits to main per 30 days, 12-15 merges per week: roughly 2-3 runs per
working day. Current single-flavor single-platform release runs take 5-24
minutes and at least two run concurrently, so a four-artifact matrix lands
around 15-25 minutes wall-clock. That is comfortably absorbable.

Consumes ~600 build numbers and ~600 `build/N` tags per year. The numbers are
free; the tags are noise and can be pruned.

## Workflow B — `release.yml`

Trigger: `workflow_dispatch` only.

| Input | Default | Meaning |
|---|---|---|
| `build_number` | latest | Which already-uploaded build to promote |
| `flavor` | `all` | `all`, `six`, `family` |
| `platform` | `all` | `all`, `ios`, `android` |
| `submit_ios_for_review` | **false** | Whether to submit the App Store version |

Defaults give the standard sequence with no input at all. The flavor/platform
narrowing is the manual-override path.

This workflow **never builds**. Both stores support promoting an existing
build:

- **Android** — `--track internal --track_promote_to <alpha|beta> --version_code N --skip_upload_aab`
- **iOS** — `deliver(build_number: N, skip_binary_upload: true)`

On success it pushes the record tag `26.7.1042`, using the version name read
back from the `build/N` annotation rather than one recomputed from today's date.

Both `org.blokada.sex` and `org.blokada.family` have `alpha` and `beta` tracks
in Play Console (confirmed 2026-07-28), so `promote_track` will not fail with
`Cannot promote from track 'X' - track doesn't exist`.

### Why the tag trigger is removed

The version is now an *output* of the build, not an input to it — the build
number does not exist until the allocator runs. A tag cannot declare a version
it cannot know. Leaving the old trigger would let someone push `26.2.23/six` and
get a binary named `26.7.1042`, with the tag permanently lying about it.

The 429 existing tags stay as history. New tags (`build/N`, `26.7.N`) never
collide, because every old tag contains a slash.

One cosmetic ambiguity: old minor was a quarter (1-4), new minor is a month
(1-12), so `26.2.x` could read either way. The patch disambiguates instantly —
old patches are <= 75, new ones start at 1000.

## Make targets and Fastlane lanes

| Target | Path | Change |
|---|---|---|
| `version` | both | unchanged |
| `publish-android` | merge | internal only; **remove** the promote loop added on this branch, and add the metadata skip flags |
| `promote-android` | release | **new** — the promote loop moves here, plus metadata/changelogs |
| `publish-ios-testflight` | merge | **new** — `upload_to_testflight` lane |
| `promote-ios` | release | **renamed from `publish-ios`** — `deliver` with `build_number`, `skip_binary_upload`, optional `submit_for_review` |

### iOS submission settings

```ruby
submit_for_review: <input>,        # default false
automatic_release: false,          # → "Pending Developer Release", manual click
submission_information: {
  content_rights_contains_third_party_content: false
}
```

Export compliance needs **nothing**: `ITSAppUsesNonExemptEncryption` is already
`<false/>` in `ios/App/Assets/Info-six.plist` and `Info-family.plist`, so App
Store Connect never asks. Content rights is answered explicitly rather than
relying on the console value, so CI is self-contained.

### Play release notes wrinkle

This is the fiddliest part of the split. Promotion copies the whole release
object, so a promoted release inherits the release notes of the internal
release — and under this design the internal upload skips changelogs, so there
are none. The release job must therefore upload changelogs against the promoted
track, by passing `--metadata_path metadata/android-<flavor>` with
`--skip_upload_images true --skip_upload_screenshots true` on the promote run.

## Platform behaviour this design depends on

Verified against fastlane 2.232.0 as installed, not from documentation.

- **`track_promote_to` does not remove the build from the source track.**
  `promote_track` in `supply/lib/supply/uploader.rb` reads the release from the
  source and calls only `client.update_track(track_promote_to, ...)`. This is
  what allows one build to sit on internal, alpha and beta at once.
- **`rescue_changes_not_sent_for_review` defaults to `true`.** On a *"Please set
  the query parameter changesNotSentForReview to true"* refusal, supply silently
  re-commits with the flag set and exits 0 — a green run with an unsubmitted
  build. Every promote run must set it to `false`.
- **`metadata_path` defaults to `(Dir["./fastlane/metadata/android"] + Dir["./metadata"]).first`.**
  This repo has `./metadata`, whose children are `android-six`, `ios-family`,
  etc. Omitting the flag makes supply treat those directory names as locale
  codes; the explicit skip flags avoid this regardless.
- **`deliver` refuses concurrent submissions** — `submit_for_review.rb` errors
  with *"A review submission is already in progress"*. Clean, legible failure.
- **`workflow_dispatch` requires the workflow file on the default branch**;
  `push` does not. This shapes the test plan below.
- **TestFlight builds expire after 90 days**, so promote-only has a shelf life.
  Irrelevant at 2-3 builds/day, but it means a very old build cannot be shipped.

## Testing before merge

`ci-release.yml` is testable from the branch by temporarily widening its
trigger:

```yaml
on:
  push:
    branches: [main, 'feat/release-pipeline']   # TEMPORARY
```

Push-triggered workflows run from the file on the pushed branch, so this
exercises the real flow: real builds, real uploads to Play internal and
TestFlight, real build numbers.

`release.yml` cannot be dispatched before it is on `main`. Because it is
dispatch-only it is **inert on main** — it cannot fire by itself — so merging it
early is safe and is the only way to test the workflow wiring rather than just
the make targets.

Two things to accept while testing: internal testers will see branch builds, and
build numbers get consumed (they are free).

**Removing the temporary trigger is a required final commit before merge.**

## Sequencing

| | Step | Rationale |
|---|---|---|
| 1 | Restructure the Play work: move promote out of `publish-android` into `promote-android` | Already written; wrong location under the new design |
| 2 | Versioning: allocator + `YY.M.BUILD` | Foundational and irreversible — codes only ever go up |
| 3 | `ci-release.yml` | Proves the upload path continuously |
| 4 | `release.yml`, submit off by default | Safest last; needs real builds from step 3 to promote |

## Failure semantics

A partial failure (Android uploaded, iOS not) leaves build N half-published.
The recovery is to merge again or re-run; either allocates a fresh number and
rebuilds everything. Build numbers cannot be reused, so there is no repair path
that reuses N, and none is needed.

An upload failure reds `main`. That is intended — catching publish-path
regressions is the whole point — but it means transient App Store Connect or
Play outages will occasionally red main, and the fix is a re-run.

## Rollback

Steps 3 and 4 are additive workflow files; deleting them or disabling them in
the Actions UI restores the previous behaviour. Step 2 is **not reversible** —
once a code of `669001000` is published, Play will never accept a lower one,
so the old `GITHUB_RUN_NUMBER` scheme cannot be restored. Reverting after that
point means picking a new counter above the highest published value.

## Known risks

- Forgetting to remove the temporary branch trigger (mitigated by making it the
  final commit).
- The first post-migration run must produce a code above `669000015`; the
  starting value of 1000 gives a wide margin.
- Store-listing changes reach production only via a release run, so a listing
  fix now requires a release rather than a merge.
