# Contributing to Concept Bridge

Run the checks in [test/README.md](test/README.md). Install the UI dependencies
with `npm ci` in `web/`, then run `npm run lint` and `npm run build`.
Preserve the license and upstream attribution when changing or packaging source.

## Development and releases

1. Start a focused branch from the latest `main` and open a pull request.
2. Use a Conventional Commit PR title (`fix:`, `feat:`, or `refactor!:` for an API
   break). Squash merging uses that title as the commit message.
3. Write useful release notes manually in `CHANGELOG.md`. Keep implementation
   history and validation details in the PR. CI must pass before merging.
4. Release-please maintains a version PR. It updates `version.txt`, the resource
   manifest, UI package and lockfile, and annotated current-version documentation.
   It never writes the changelog.
5. When ready to release, move the applicable Unreleased notes into a dated
   section for the version proposed by the bot. Submit that changelog edit in a
   normal PR to `main`; the bot refreshes its version PR from the updated branch.
   Avoid editing the bot's branch directly, as a later refresh can replace edits.
6. Merge the green version PR. The workflow creates a tag and draft release,
   reruns CI on that exact commit, builds and verifies the ZIP, and publishes it
   with the manually written changelog section. Missing notes or failed checks
   prevent publishing.

`fix:` proposes a patch, `feat:` a minor release, and a breaking change marked
with `!` or a `BREAKING CHANGE:` footer proposes a major release. The manifest is
seeded from the existing release, so adoption does not reset versions or tags.

The built-in `GITHUB_TOKEN` starts CI explicitly on bot PRs and calls packaging
directly. No personal token or additional secret is needed. Repository Actions
must allow GitHub Actions to create pull requests; workflow permissions are
declared in the files rather than enabling write permissions globally.

Run **Release** manually with an empty tag for a build artifact without publishing.
If publishing failed after a release PR merged, rerun the failed workflow jobs,
or run **Release** with that existing tag. It rechecks the tagged source, replaces
the ZIP asset if needed, and publishes the same draft; it does not create another
version. Do not push version tags manually for normal releases.

Use `./tools/package-release.ps1 -Build` for local packaging. Verify provider
behavior on a separate FiveM development server before publishing a release.
