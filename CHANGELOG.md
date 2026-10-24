# Changelog

## [Unreleased]

### Maintenance

- Align contributor guidance and verify the manual, patch-only release policy in CI.

### Fixed

- Make extension exports callable so consumers can retrieve their module tables.
- Keep ESX identity, job, metadata and account reads safe before character load,
  and return zero for missing server hunger/thirst entries.
- Report missing or invalid version-check metadata without throwing.
- Initialize the client skill registry before creating skills.
- Correct particle native arguments and asset cleanup, use boolean ped prop flags,
  and ignore invalid numeric entity rotations.

## [1.1.1] - 2026-10-22

### Fixed

- Preserve negative Qbox cash, bank and other account balances on the server and
  client, and negative ESX client account balances, including the cash/money alias.
  Consumers receive the signed balance instead of zero.

## [1.1.0] - 2026-10-20

### Removed

- Remove the built-in `Dialogue` module, its NPC dialogue UI and the unused clipboard
  listener. Scripts using `Dialogue()`, `Bridge().Dialogue`, `Dialogue.Open` or
  `Dialogue.Close` must use a separate dialogue resource. Bridge no longer ships a
  web app or requires frontend dependencies/builds for installation or releases.

- Remove the unused entity-action extension, which depended on a missing action engine.

### Changed

- Clients download only client and shared code; server modules are no longer sent to them.

- Lower client cost: QBCore, Qbox and ESX player data is cached and follows the framework's
  update events, public calls no longer ask the game for the provider state each time, and
  target `canInteract` checks are freed with their entity or zone.

### Fixed

- Target `canInteract` results are cached per option and per target entity, so looking from one
  player to another within a second no longer shows the first player's options.

- ox_core: `LocalPlayer.state.isLoggedIn` and `GetIsPlayerLoaded` follow the loaded character
  instead of always reporting a loaded player, including on the character select screen.

- QBCore and Qbox: client getters return nil or an empty value before a character is loaded
  instead of erroring, and QBCore `GetPlayerDob` reads the birth date from the player data.

- ox_core: account balances requested at the same time (for example cash and bank) are all
  answered; the request limit still applies.

- `oxmysql` is listed as a dependency; the bridge loads its MySQL library on the server.

- Target zones: a stopping resource removes only its own zones. Zones of other resources stay
  tracked and removable (ox_target forgot all of them on any stop, which left ghost options and
  duplicate zones after a restart), and a restarted target system no longer receives stale zone ids.

- sleepless_interact zones: box and sphere zones are added as coords points the way the
  provider expects (box zones were never registered, sphere zones called a missing export) and
  each zone removes only its own options at a shared position.

- Clear ESX needs caches across character changes and status-resource restarts,
  and discard delayed status results from previous sessions.

- Validate sensitive client requests, authorize dispatch relays on the server, and
  reject stale identity/provider results and client assertions of inventory-less item use.
  Keep server configuration out of the client download.

- Select only running providers, resolve conflicts consistently, and refresh adapters
  when providers start, stop or restart. Consumers that cache provider state must
  handle `Bridge:Refresh` to update their own caches.

- Preserve server shell permission hooks and configured buckets; validate client
  entry and exit points and restore the original player bucket on exit or cleanup.

- Restore the previous shell entrance when switching directly between shells.

- Keep clients synchronized when bulk shell creation fails after earlier entries succeed,
  and return an explicit success result for completed batches.

- Reject bucket 0 as a shell destination while preserving return to a player's
  original world bucket on exit.

- Reject repeated shell entry when the recorded visit or current routing bucket
  no longer matches, preserving explicit server recovery after another resource moves a player.

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
