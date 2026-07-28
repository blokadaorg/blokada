# Release pipeline

Design and runbook for how Blokada builds, versions and ships to the App Store
and Google Play.

The shape is continuous delivery to internal channels, plus a separate
promote-only release step:

- **Every merge to `main`** builds all four artifacts (six + family, iOS +
  Android) and uploads them to Play **internal** and **TestFlight**. Nothing is
  published and nothing is submitted for review.
- **Releasing** never builds. It takes a build number that is already uploaded
  and releases it: to Play `alpha` + `beta`, and to an App Store version that is
  optionally submitted for review. Publishing is always a manual click.

The pipeline stops at Play `alpha`/`beta` and at an App Store version in
Pending Developer Release. **Neither reaches production.** Promoting an
alpha/beta release to Play `production`, and releasing an approved App Store
version, are console actions with no automation here at all — see
[Reaching production](#reaching-production).

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
- **Re-run safe** — *"Re-run all jobs"* re-runs `allocate` and takes a fresh
  number, which is correct. *"Re-run failed jobs"* does **not**: it reuses the
  cached output of the successful `allocate` job and carries the same number.
  That is harmless when the upload never happened (the point of the re-run),
  and a duplicate-version-code rejection from Play when it did. If an upload
  succeeded, re-run *all* jobs.
- **Atomic** — the tag push either wins or fails, so it doubles as the lock.
- **Auditable** — `build/1042` points at the exact commit that produced it, and
  `release.yml` puts the human-facing `26.7.1042` tag on that same commit
  rather than on whatever `main` happens to be at release time.

Failed runs leave an orphan `build/N` with no matching release tag. That is
expected; numbers are cheap and gaps are meaningless. It does mean
`build_number: latest` can name a build that was never uploaded — see
[Releasing](#workflow-b--releaseyml).

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
  group: store-publish
  cancel-in-progress: false
```

Cancelling mid-flight would strand a consumed build number and a half-finished
upload, so runs queue instead.

The group is **shared with `release.yml`**, deliberately. Both workflows write
the same Play packages, and Play invalidates an open edit whose underlying app
state changed, so a merge landing mid-release would break one side or the other
with a confusing error. The consequence to accept: a merge to `main` that lands
during a release waits for the whole release to finish before it starts
building, and a release dispatched during a merge build waits for that build.

`cancel-in-progress: false` protects the *running* job, not the queue. GitHub
keeps at most one **pending** run per group: when a second merge lands while a
release still holds `store-publish`, the first merge's pending run is cancelled
outright, and that commit is never built or uploaded. Only the newest queued
commit survives the wait.

That partially undercuts the "no path filters, every commit on `main` is proven
publishable" decision above: during a release window, intermediate commits can
be skipped. What still holds is that whatever *does* get built is built from a
real commit on `main` with nothing filtered out of it, and the skipped commits
are covered by the later build that supersedes them — a regression introduced
in a skipped commit still surfaces, just attributed to the newer build number.
Bisecting a release window to a single commit is the thing that stops working.

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
free. **The tags are not noise and must not be pruned** — they are the
counter's only persistent state. `highest()` reads them off the remote, so
deleting the highest one makes the next allocation fall back to `--start 1000`
and re-issue store codes that are already published, which Play will reject
forever after. If tags are ever pruned anyway, the `--start` floor in
`ci-release.yml` must be raised above the highest build number ever published,
in the same commit.

## Workflow B — `release.yml`

Trigger: `workflow_dispatch` only.

| Input | Default | Meaning |
|---|---|---|
| `build_number` | latest | Which already-uploaded build to release |
| `flavor` | `all` | `all`, `six`, `family` |
| `platform` | `all` | `all`, `ios`, `android` |
| `submit_ios_for_review` | **false** | Whether to submit the App Store version |

Defaults give the standard sequence with no input at all. The flavor/platform
narrowing is the manual-override path.

**`latest` resolves the newest *tag*, not the newest successful build.** The
number is allocated before anything is built, so if that `ci-release` run
failed, `build/N` is an orphan: nothing was uploaded under it and the release
fails. Before dispatching with the default, check that the `ci-release` run for
that build number was green. `build_number` also accepts an explicit number,
which is the way to release a specific older build.

This workflow **never builds**. Both stores support releasing an existing
build:

- **Android** — write the target track directly:
  `--track <alpha|beta> --version_codes_to_retain N --skip_upload_aab --skip_upload_apk`
- **iOS** — `deliver(build_number: N, skip_binary_upload: true)`, then attach
  the build to the version explicitly (see below)

On success it pushes the record tag `26.7.1042` **on the commit `build/1042`
points at**, not on `main` at release time — those differ by however many
merges landed during the soak. The version name comes from the `build/N`
annotation rather than being recomputed from today's date.

Both `org.blokada.sex` and `org.blokada.family` have `alpha` and `beta` tracks
in Play Console (confirmed 2026-07-28).

### Reaching production

**The pipeline never touches production on either store.** `release.yml` ends
with:

- Play: a release on `alpha` and `beta`, submitted for review.
- App Store: a version with the build attached, either still editable or — with
  `submit_ios_for_review: true` and once approved — in Pending Developer
  Release.

Getting from there to users is entirely manual, in the two consoles:

- **Play production** — Play Console → *Production* → *Create new release* →
  add the reviewed version code → *Start rollout*. There is no make target, no
  lane and no workflow input for this, by design.
- **App Store** — App Store Connect → *Release this version*, because
  `automatic_release: false`.

"Publishing is always a manual click" refers to exactly these two actions.

### Why Android writes the track instead of promoting

The obvious mechanism — `--track internal --track_promote_to alpha` — only
works for the newest build, which makes it useless here.

`promote_track` (`supply/lib/supply/uploader.rb`) reads
`client.tracks('internal').first.releases` and filters by version code. But
every continuous upload calls `update_track`, which assigns
`track.releases = [track_release]`, and Play's `edits.tracks.update` drops
releases that are omitted. So the moment the next merge uploads build N+1,
build N is no longer on internal, and promoting it fails with
*"Track 'internal' doesn't have any releases"*. At 2-3 merges per working day
that is the normal soak-then-release case, not an edge case.

Writing the target track directly needs no source-track membership. With both
uploads skipped, `perform_upload` starts from an empty `apk_version_codes`,
`apk_version_codes.concat(version_codes_to_retain)` makes it `[N]`, and the
non-empty branch calls `update_track` on the target track followed by
`perform_upload_meta([N], <target>)` — so changelogs still attach exactly as
they did on the promote path.

`make promote-android` runs `scripts/verify-play-version-code.rb` first, which
lists the package's uploaded bundles and APKs and fails naming the code if it
is not among them. Without it, a code that was never uploaded surfaces as a
generic Play track error that says nothing about where the code should have
come from.

It uses fastlane's own client — `Supply::Client#aab_version_codes` and
`#apks_version_codes` (`supply/lib/supply/client.rb:268-283`), authenticated by
`Supply::Client.make_from_config` from the same `blokada-gplay.json` supply
uses. It opens and deletes a throwaway edit of its own, because the check has
to finish before supply opens the edit it will commit. Every error path —
auth, network, unexpected response — exits non-zero, so a broken check blocks
the release rather than waving it through.

### Why iOS attaches the build explicitly

`deliver` selects a build **only** inside its submit-for-review step:
`Runner#run` calls `submit_for_review` under
`if options[:submit_for_review] && precheck_success` (runner.rb:71), and
`options[:build_number]` is read nowhere else in deliver. With
`submit_for_review: false` — the default — deliver would create the App Store
version, upload the metadata, report success, and leave the version with **no
binary attached**.

So each promote lane attaches the build itself after `deliver`, using the same
`Spaceship::ConnectAPI` calls deliver's own `select_build` uses: find the app by
bundle id, take the editable App Store version for iOS, look the build up by
`app_version` + `build_number`, select it on the version. Re-selecting an
already-selected build is the same PATCH with the same value, so re-runs are
safe. A build that has not finished processing fails with a message saying so.
The step is skipped when `submit_for_review` is on, because deliver's own
submit flow selects the build and then moves the version out of an editable
state.

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
| `promote-android` | release | **new** — preflight the code, then write `alpha`/`beta` directly with `--version_codes_to_retain`, plus metadata/changelogs |
| `publish-ios-testflight` | merge | **new** — `upload_to_testflight` lane |
| `promote-ios` | release | **renamed from `publish-ios`** — `deliver` with `build_number`, `skip_binary_upload`, optional `submit_for_review`, then an explicit build attach |
| `test-scripts` | neither | **new** — runs `test-build-number.sh` and `test-version.sh`; wired into PR CI on `ubuntu-latest` |

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

This is the fiddliest part of the split. The internal upload deliberately skips
changelogs, so nothing the release step could inherit carries release notes.
The release job therefore uploads changelogs against the track it writes, by
passing `--metadata_path metadata/android-<flavor>` with
`--skip_upload_images true --skip_upload_screenshots true`.

That still works when the track is written directly rather than promoted:
`perform_upload_meta` is called with the version codes and the track that
`perform_upload` just updated, so it finds the release it created a moment
earlier and attaches the notes to it.

## Platform behaviour this design depends on

Verified against fastlane 2.232.0 as installed, not from documentation.

- **`update_track` replaces a track's release list.** `uploader.rb#update_track`
  assigns `track.releases = [track_release]`, and Play drops releases omitted
  from `edits.tracks.update`. So internal only ever holds the newest build, and
  `--track_promote_to` — which reads the source track's releases — can only
  promote that one. This is why the release step writes the target track
  directly instead.
- **`version_codes_to_retain` alone is enough to write a track.**
  `perform_upload` concatenates it into `apk_version_codes` after the (skipped)
  uploads, so a non-empty list routes to `update_track` on `--track` and then
  `perform_upload_meta(codes, track)`. No source track is read at any point.
- **`rescue_changes_not_sent_for_review` defaults to `true`.** On a *"Please set
  the query parameter changesNotSentForReview to true"* refusal, supply silently
  re-commits with the flag set and exits 0 — a green run with an unsubmitted
  build. Every release run must set it to `false`.
- **`deliver` attaches a build only when submitting for review.**
  `Runner#run` (runner.rb:71) calls `submit_for_review` under
  `if options[:submit_for_review] && precheck_success`, and `build_number` is
  consumed only inside `submit_for_review.rb`. With submit off, deliver uploads
  metadata and reports success without attaching any binary, so the lane has to
  attach it itself.
- **`CommandLineHandler.convert_value` coerces `true`/`false` on the CLI.**
  `fastlane <lane> submit_for_review:true` reaches the lane as the Ruby boolean
  `true`, not the string, so lane options have to be compared with `.to_s`.
- **`metadata_path` defaults to `(Dir["./fastlane/metadata/android"] + Dir["./metadata"]).first`.**
  This repo has `./metadata`, whose children are `android-six`, `ios-family`,
  etc. Omitting the flag makes supply treat those directory names as locale
  codes; the explicit skip flags avoid this regardless.
- **`deliver` refuses concurrent submissions** — `submit_for_review.rb` errors
  with *"A review submission is already in progress"*. Clean, legible failure.
- **`workflow_dispatch` requires the workflow file on the default branch**;
  `push` does not. This shaped the pre-merge validation below.
- **TestFlight builds expire after 90 days.** This is an **iOS-only** limit: a
  build older than 90 days is gone from TestFlight and cannot be attached to an
  App Store version, so release-only has a shelf life on that platform.
- **Android has no equivalent expiry, but internal membership is not durable.**
  An uploaded bundle stays in Play's bundle explorer indefinitely and stays
  releasable by version code for as long as it satisfies Play's minimum
  `targetSdk` policy for new releases. What it does *not* keep is its place on
  the internal track — the next merge evicts it (see `update_track` above) —
  which is why nothing in the release path reads a source track.

## How this was validated before merge

Historical record, not an instruction. Nothing here is pending.

`ci-release.yml` was exercised from the branch by temporarily adding
`feat/release-pipeline` to its `push.branches`. Push-triggered workflows run
from the file on the pushed branch, so this ran the real flow rather than a
simulation: real builds, real uploads, real build numbers. The run was green
and allocated `build/1000`, annotated `26.7.1000`, with all four artifacts
(six + family × iOS + Android) uploaded to Play internal and TestFlight. The
branch trigger was then removed in `958d8f98`, and `ci-release.yml` fires on
`main` only.

`release.yml` could not be dispatched before merge — `workflow_dispatch`
requires the workflow file on the default branch. It is inert on `main` (it
cannot fire by itself), so it lands unexercised by design; its first real run
is the first release.

Accepted while validating: internal testers saw branch builds, and build
numbers were consumed (they are free).

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

- The first post-migration run must produce a code above `669000015`; the
  starting value of 1000 gives a wide margin.
- Store-listing changes reach production only via a release run, so a listing
  fix now requires a release rather than a merge.
- Deleting `build/*` tags breaks the allocator irrecoverably. See
  [Cost](#cost).
- A release and a merge now serialise on one concurrency group, so a merge that
  lands mid-release waits for the whole release to finish.
