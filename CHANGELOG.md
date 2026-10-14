# Changelog

## [Unreleased]

### Fixed

- Preserve server shell permission hooks and configured buckets; validate client
  entry and exit points and restore the original player bucket on exit or cleanup.

- Restore the previous shell entrance when switching directly between shells.

## [1.0.0] - 2026-10-14

First Concept Bridge release.

### Added

- Framework, inventory and provider adapters for FiveM, including OX, QBCore,
  Qbox and ESX integrations.
- Seatbelt, voice and weapon data used by Concept HUD, plus the dialogue UI.
- `Framework.GetIsPlayerDown(src)` on the server and `Framework.GetIsPlayerDown()`
  on the client. It includes death and last stand; `GetIsPlayerDead` retains its
  existing behavior.
- `Inventory.SavePlayerInventory(src)` for qb-inventory, ps-inventory and
  jpr-inventory. Other providers return `false, 'unsupported'`; provider failures
  return `false, 'provider_error'`.

### Fixed

- Return the shells library table so the bridge starts correctly with ox_lib's
  module loader. Invalid module results are logged and skipped during startup.
- Bind housing notifications to their sender, validate property identifiers and
  active adapters, normalize exits, and recognize qb-apartments correctly.
- Authorize fallback shop opening and checkout using server character, position,
  routing bucket and group grades. Reject invalid quantities and accounts and
  reserve finite stock before payment.
- Restore stock and refund payment when shop delivery fails. Retain unresolved
  payment and refund records across restarts to avoid duplicate refunds.
- Allow configured free items through the fallback shop quantity menu.

### Dependencies

- Use ox_lib directly for callbacks, loading, locales, points, zones, raycasts,
  vehicle properties, tables, printing, IDs and scaleforms.
- Use oxmysql directly for database access. Provider adapters and bridge-specific
  world and animation extensions remain available.

### Distribution

- Includes the prebuilt UI, complete editable Lua and UI source, build tooling
  and locked dependencies in the downloadable resource ZIP.
- Preserves GPLv3 licensing and upstream attribution in `ORIGIN.Md`.
- Release notes are manually maintained in this changelog.
