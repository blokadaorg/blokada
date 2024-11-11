## Metadata instructions

Our CI (on next release) will pull metadata specified in this repo. Path:

`/fastlane/metadata`

There are separate directiories for each app, and then a directory for each locale.

Structure is important, also most fields have length limits (see the Apple panel).

There is no checks for the validity of the texts entered, the CI build will fail on upload.

Please note that any manual changes in the Apple panel will be overwritten on next relase.

To make a (testflight) release, this repo has to be tagged with version (using ./release.sh).
Then, the actual build upload is done in `blokadaorg/blokada` repo (using ./publish.ios.sh).

This will make the new build and upload it to testflight, at the same time making the listing updates (a draft listing will be created). If there is a draft listing already, it should update it instead.

CI build progress and result can be checked in Actions tab of respective repos in github.
