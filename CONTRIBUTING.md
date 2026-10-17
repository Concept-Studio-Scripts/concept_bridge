# Contributing

Create a focused branch from the latest `main` and submit a pull request. Use Conventional Commits for commit messages and the PR title, for example `fix(inventory): preserve item metadata`.

Run the [Lua checks](test/README.md) and release checks below before merging. Explain compatibility changes and verification in the PR. Preserve the license, credits and source notices.

```sh
node tools/check-release.mjs
node --test test/release-workflow.test.mjs
```

Keep user-facing API and configuration documentation in [conceptstudio-web](https://github.com/Concept-Studio-Scripts/conceptstudio-web/blob/master/content/docs/concept-bridge.md). Repository docs cover installation and contribution basics.

## Releases

1. Write release notes manually under `Unreleased` in `CHANGELOG.md`.
2. Release-please opens a version PR. It updates `version.txt`, the manifest and README version; it does not generate the changelog.
3. Before merging that PR, submit the applicable notes in a dated `CHANGELOG.md` section for its proposed version through a normal PR to `main`. The bot refreshes its branch; avoid editing that branch directly.
4. Merge the version PR after its checks pass. The release workflow tags the source, reruns checks, builds the complete source/resource ZIP and publishes it with the manual notes.

`fix:` proposes a patch, `feat:` a minor release, and `!` or a `BREAKING CHANGE:` footer a major release. GitHub Actions must be allowed to create pull requests. The workflows use `GITHUB_TOKEN`; no personal token is needed.

For local packaging, use PowerShell 7: `./tools/package-release.ps1`. Verify provider behavior on a FiveM development server before publishing. Run the **Release** workflow with an empty tag for an unpublished build artifact. To retry a failed publication, rerun the failed jobs or run **Release** with the existing tag. Normal releases do not require manually pushed tags.
