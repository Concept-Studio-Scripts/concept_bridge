# Contributing

Create a focused branch from the latest `main` and submit a pull request. Use Conventional Commits for commit messages and the PR title, for example `fix(inventory): preserve item metadata`.

Run the [Lua checks](test/README.md) and release checks below before merging. Explain compatibility changes and verification in the PR. Preserve the license, credits and source notices.

```sh
node tools/check-release.mjs
node --test test/release-workflow.test.mjs test/manual-changelog.test.mjs test/release-policy.test.mjs
node --test test/lua-analysis.test.mjs
```

For full-resource Lua analysis, install the LuaLS version and FiveM addon revision pinned in `tools/lua-analysis-config.json` (CI shows the setup). Set `LUA_LS` to the executable and `CFX_LUALS_ADDON` to the clean addon checkout, then run `node tools/check-lua.mjs`.

The check separates client/server code and accepts only individually reviewed legacy diagnostics. New warnings and errors fail; resolved baseline entries must be removed. Review any baseline change with its reason. Reports stay in ignored `release/lua-analysis/`.

Keep the owner guide in [docs/guide.md](docs/guide.md) and update it in the same PR as the behavior it describes. The website publishes the guide from the latest release; release ZIPs do not include it.

Organization members can merge a green PR without another approval. Resolve valid review findings before merging.

## Releases

1. Write release notes manually under `Unreleased` in `CHANGELOG.md`.
2. Release-please opens a version PR and updates version files, the manifest and annotated docs. The workflow moves your `Unreleased` notes into that PR's dated version section, preserving their text, order, formatting and line endings. It leaves an empty `Unreleased` section for the next release; it never generates notes from commits.
3. Review the version and notes in the release PR. Keep editing notes through normal PRs to `main`; the bot refreshes its copy from there. The workflow keeps an existing section for the proposed version as written. Missing or empty notes block publishing. Do not edit the bot branch directly.
4. Merge the version PR after its checks pass. The release workflow tags the source, reruns checks, builds the complete source/resource ZIP and publishes it with the manual notes.

Automatic releases increment only the patch number, including `feat:`, `!` and `BREAKING CHANGE:` commits. Keep breaking-change markers and compatibility notes for contributors; they do not automatically select a new major version. Allow GitHub Actions to create pull requests. The workflows use `GITHUB_TOKEN`, so you don't need a personal token.

For local packaging, use PowerShell 7: `./tools/package-release.ps1`. Verify provider behavior on a FiveM development server before publishing. Run the **Release** workflow with an empty tag for an unpublished build artifact. To retry a failed publication, rerun the failed jobs or run **Release** with the existing tag. Normal releases do not require manually pushed tags.

CI validates resource ZIPs without uploading routine package copies. Explicit Release previews retain their Actions artifact for one day. Tagged releases attach the verified ZIP directly to the GitHub release, so publishing does not depend on Actions artifact storage.
