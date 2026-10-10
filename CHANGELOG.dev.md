# Developer changelog

## [Unreleased]

## [1.0.0] - 2026-10-10

First Concept Bridge release.

### Added

- Canonical `concept_bridge` resource, loader, exports, events and state-bag namespaces.
- Framework/inventory adapter corrections and the seatbelt, voice and weapon modules used by Concept HUD.
- Four Lua regression suites covering inventory adapters, documented provider APIs,
  event/target/capacity behavior and runtime identity.
- Tag-driven releases and manual ZIP artifacts using the shared PowerShell packager.
- Owner and developer changelogs and installation guidance for prebuilt releases.

### Changed

- Manifest, NUI package and lockfile versions are aligned at 1.0.0.
- Origin, licensing and inherited credits are consolidated in `ORIGIN.Md`.
- NUI builds finish without watch mode; the source lockfile uses version 3.
- Packaging includes GPL licensing, attribution, complete source and prebuilt UI.

### Validation limits

Automated fixtures, NUI lint/build and packaging checks do not establish deployed
provider behavior or full FiveM acceptance. Existing security and dependency
priorities remain open; in-game checks are deferred.
