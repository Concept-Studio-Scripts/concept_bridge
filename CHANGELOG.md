# Changelog

## [Unreleased]

### Added

- `Framework.GetIsPlayerDown(src)` on the server and `Framework.GetIsPlayerDown()`
  on the client for ESX, OX, QBCore and Qbox. It includes both death and last stand;
  `GetIsPlayerDead` keeps its existing behavior.
- `Inventory.SavePlayerInventory(src)` saves one player's inventory immediately
  for qb-inventory, ps-inventory and jpr-inventory. Other providers return
  `false, 'unsupported'`; provider failures return `false, 'provider_error'`.

### Fixed

- Return the shells library table so the bridge starts correctly with ox_lib's
  module loader. Invalid module results are logged and skipped during startup.
- Bind housing notifications to their sender, validate property identifiers and
  active adapters, normalize exits, and recognize qb-apartments correctly.
- Authorize fallback shop opening and checkout using server character, position,
  routing bucket and group grades. Reject invalid quantities and accounts and
  reserve finite stock before payment.
- Restore stock and refund payment when shop delivery fails. Retain unresolved
  payment and refund records across bridge restarts to avoid duplicate refunds.
- Allow configured free items through the fallback shop quantity menu.

### Breaking changes

- Remove duplicate utility exports, including `Require`, `Callback`,
  `RegisterCallback`, `TriggerCallback`, `RegisterRebound`, `Language`, `Point`,
  `Zones`, `Raycast`, `Vehicles`, `Tables`, `Table`, `Prints`, `Ids` and `Scaleform`.
  Consumers must use ox_lib directly for those utilities.
- Remove the deprecated SQL wrapper and exports; use oxmysql directly.

### Changed

- Keep provider adapters, bridge-specific world and animation extensions, and the
  dialogue UI. Retained extensions use ox_lib for streaming and proximity work.

## [1.0.0] - 2026-10-10

First Concept Bridge release.

- Provides the `concept_bridge` compatibility layer for FiveM frameworks,
  inventories and other providers, including HUD seatbelt, voice and weapon data.
- Includes a prebuilt UI and complete editable Lua and UI source in the resource ZIP.
- Preserves GPLv3 licensing and upstream attribution in `ORIGIN.Md`.
