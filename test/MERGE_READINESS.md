> Historical record from the source community_bridge fork before the Concept Bridge runtime migration. Its commit links and validation results refer to that source repository. See [origin and attributions](../ORIGIN.Md) for project provenance.

# Audit branch pre-merge validation

Reviewed on 2026-10-10 against main `07d6bd9ad9696f587c676eb4c3a10f4ee9e6e1af`. Candidate includes original audit 857a0d6, main synchronization ac04001, metadata/registry remediation a80aed3, provider documentation corrections 4b8b224 and this validation follow-up.

## Recommendation

Merge this branch into the fork's main as a development baseline once its final inventory regression CI succeeds. No additional code-merge blocker was found in the reviewed delta after correcting the legacy QB slot-capacity defect below. This recommendation does not approve a production release or certify every provider.

Main is fully contained in the candidate, so no merge conflicts are expected. Frontend source/package/lock/build assets are unchanged relative to main. No HUD runtime source or deployed resource was changed during validation.

## Checks

- Three committed bridge suites: `inventory_regressions.lua`, `provider_docs.lua`, `audit_regressions.lua`. Run all three with Lua 5.4 from the bridge root. CI runs all three on pushes and pull requests.
- Framework client contract fixtures across QB, Qbox, OX, ESX and standalone: 37 passing assertions.
- Current HUD Lua suite: 348 assertions; direct-provider guard: 40 files without violations; manifest check: 41 paths. HUD typecheck and Biome pass; 24 Vitest suites / 195 tests pass. HUD production build passes in a temporary snapshot using existing dependencies.
- Bridge finite Vite build passes using existing cached dependencies. Bridge ESLint still fails on the same two pre-existing unused `count`/`setCount` variables in dialogue.jsx. The unchanged web tree establishes that this branch did not introduce those failures. This is a known baseline exception, not an all-green repository result. Dependency freshness and a fresh-install release build are not re-certified here.
- Changed Lua files compile with stock Lua 5.4; workflow YAML and diff whitespace checks pass. Full CfxLua/runtime behavior remains outside these static checks.

Expanded legacy QB capacity checks reproduced a failure when a stackable item already occupied the last slot: the helper unnecessarily demanded another slot. The follow-up counts populated slots without relying on array length, requires no new slot for an existing stack, reserves one slot per unique item, retains exact-fit weight acceptance, and rejects unknown items/invalid counts. The new current-branch regression suite also covers event source binding, local server event callers, usable-item callback shapes and target removal using QB labels versus OX/Sleepless names.

## Compatibility and release limits

Read [PROVIDER_CONTRACTS.md](PROVIDER_CONTRACTS.md) before upgrading consumers. Origen bulk trunk insertion and Origen/Core stash access restrictions fail explicitly; Core per-stash capacity requires provider configuration. Filtered removals require one sufficient matching stack. Native metadata return semantics and Core slot/opaque-ID mapping are documented there. No affected calls were found in concept_hud runtime source; external consumers are not exhaustively inventoried.

Framework source binding prevents selecting a different player's ID. It does not authenticate supplied job/group data or client-requested lifecycle transitions. The wider callback/shop/housing/shell/provider-selection security findings from the codebase review remain open and must not be described as fixed by this branch.

Exact installed provider versions, proprietary provider implementations, resource lifecycle/concurrency, client custom-item registries, inventory persistence, image layouts and in-game behavior remain unverified. Complete the existing smoke matrix and applicable security backlog before deploying a production release. In-game checks were deferred at the user's request.
