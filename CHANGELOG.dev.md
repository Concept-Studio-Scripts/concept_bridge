# Developer changelog

## [Unreleased]

### Added

- `Framework.GetIsPlayerDown(src)` (server) and `Framework.GetIsPlayerDown()` (client) on es_extended, ox_core,
  qb-core and qbx_core: dead OR in last stand, by one shared rule (`lib/framework/shared/player_down.lua`).
  `GetIsPlayerDead` is unchanged. (The Qbox server module's `GetIsPlayerDead` reads `metadata.isdead` only, while
  its client and the QBCore module include last stand: a consumer that means "cannot act" asks `GetIsPlayerDown`.)
- `Inventory.SavePlayerInventory(src)`: writes one player's inventory to the database now on qb-inventory,
  ps-inventory and jpr-inventory; `false, 'unsupported'` on every other provider (ox_inventory has no export for
  one player), `false, 'provider_error'` when the provider throws.
- `test/consumer_contracts.lua` covers both.

### Fixed

- Authorize fallback shop opening and checkout from server character, position,
  routing bucket and group grades. Reject invalid quantities/accounts and reserve
  finite stock before payment; failed delivery restores stock and refunds payment.
- Serialize checkout and retain unresolved payment/refund records per character
  across bridge restarts, preventing blind duplicate compensation.
- Allow configured free items through the fallback shop quantity menu.

### Changed

- Remove the deprecated SQL wrapper and exports; use oxmysql directly for database access.

- Delegate generic utilities to the required ox_lib dependency. Remove duplicate
  callback, loader, point/zone, locale, table, print, ID, vehicle-property and
  scaleform APIs; consumers use ox_lib directly.
- Keep provider adapters and bridge-specific world/animation extensions, using
  ox_lib for streaming, proximity scheduling, cloning and interpolation.

### Tests

- Replace custom transport fixtures with callback forwarding, entity point
  lifecycle and marker contracts. Retain inventory/provider/audit regressions.

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
