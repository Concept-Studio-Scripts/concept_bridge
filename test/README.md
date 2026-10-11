# Bridge regression checks

Run `lua test/runtime_identity.lua` for explicit ox_lib module resolution and retained bridge/provider exports. Run `./tools/package-release.ps1 -Build` to build and verify the complete source/runtime archive, including version parity, the original license and prebuilt UI assets. All six Lua suites and frontend checks run in Concept Bridge CI.

Stock Lua syntax compilation applies to the standard-Lua inventory helpers and fixtures. Twenty inherited runtime files use extended syntax that stock Lua 5.4 cannot parse; full runtime syntax/behavior requires the appropriate FiveM environment and is not established by this CI gate.

From the bridge root, run `lua test/inventory_regressions.lua` with Lua 5.4. These isolated fixtures load actual framework/inventory adapters and shared helpers. They never connect to FiveM or mutate game state.

Also run `lua test/provider_docs.lua` for Origen/Core/Tgiann export contracts. Its fixtures reject unexpected export names and enforce argument counts/order, duplicate-stack totals, numeric slots versus opaque IDs, missing mappings, item definitions, metadata matching, failed mutations and stash/opening calls. [PROVIDER_CONTRACTS.md](PROVIDER_CONTRACTS.md) records the official website sources, compatibility changes and unverified boundaries. Both suites run in CI.

Run `lua test/audit_regressions.lua` for the remaining original audit changes: event source binding on QB/Qbox/ESX/OX for network and local server callers, usable-item callback normalization, named/list/empty/repeated target removal, and legacy QB weight/slot capacity. All three suites run in CI. These source-binding tests do not establish authoritative job/group values or authenticate client-requested lifecycle transitions; the wider security backlog remains open.

Target removal forwards native identifiers: QB labels and OX/Sleepless option names. If a QB option's name differs from its label, callers must pass its label. Nil/empty removal does not clear all global options. Official implementations: [QB registration](https://github.com/qbcore-framework/qb-target/blob/main/registration.lua), [OX API](https://github.com/overextended/ox_target/blob/master/client/api.lua), [Sleepless API](https://github.com/Sleepless-Development/sleepless_interact/blob/main/client/api.lua). The provider fixtures model those identifier contracts; they do not certify installed versions or cross-resource ownership.

The suite covers QB and Qbox with QB/PS inventories on server and client: definition reads/enumeration, complete ItemBox payloads, unknown/missing registries, disabled/recovered Qbox compatibility exports, stackability, rejected operations, duplicate item names across slots, nested metadata copies, unchanged counts/other slots, provider errors/no-op/rejection, post-apply exceptions, missing players, legacy setters and the Qbox/OX metadata path.

## Contracts and limits

Qbox definitions come from its QB compatibility `exports['qb-core']:GetCoreObject().Shared.Items`. QB/PS installations using Qbox require that compatibility bridge and a compatible inventory integration; missing definitions cause add/remove to return `false, 'item_registry_unavailable'` or `false, 'unknown_item'` before calling the inventory. Reads remain empty-table compatible. This does not certify arbitrary QB/PS builds on Qbox.

QB/Qbox `Framework.SetMetadata` retains its arguments and boolean first result. Failure adds a reason string: invalid_metadata_request, player_unavailable, item_not_found, unsupported_metadata_update, provider_error, update_rejected or update_not_applied. QB/PS use their native SetInventory on a copied inventory, changing only the selected slot's metadata and preserving counts. Both info and an existing metadata field are synchronized; all units in that slot share the updated metadata. Legacy injected SetInventory is also supported. OX uses its native slot metadata export.

No remove/add fallback remains. Unsupported or rejected updates retain items for retry. SetInventory often returns nil, so success is checked against authoritative player data. If a provider raises after applying the update, verified state determines success; QB/PS cases also emit a diagnostic. These synchronous setters must not yield while applying the inventory snapshot. Providers with a different persistence/concurrency contract need a dedicated adapter rather than this fallback. This is an in-memory API result, not a guarantee that subsequent database persistence cannot fail.

Reference contracts inspected for this change:

- [Qbox QB compatibility FAQ](https://docs.qbox.re/faq), [server export implementation](https://github.com/Qbox-project/qbx_core/blob/main/bridge/qb/server/main.lua), [client implementation](https://github.com/Qbox-project/qbx_core/blob/main/bridge/qb/client/main.lua).
- [QB inventory exports](https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-inventory), [implementation](https://github.com/qbcore-framework/qb-inventory/blob/main/server/functions.lua).
- [PS SetInventory implementation](https://github.com/Project-Sloth/ps-inventory/blob/main/server/main.lua).

These are upstream contracts; exact deployed versions and in-game validation remain to be checked before release. General source-binding security and other audit findings are outside this suite.

## ox_lib integration contracts

Run `lua test/ox_lib_contracts.lua` for client/server callback argument forwarding,
appearance replies, preserved entity IDs, point removal and coordinate reindexing,
and replicated marker proximity/cleanup. These fixtures exercise bridge callers;
ox_lib owns RPC transport and timeout semantics.

The support file supplies narrow dependency doubles. It does not certify the
installed ox_lib runtime or replace FiveM acceptance.


## Fallback shop transactions

Run `lua test/shop_transactions.lua`. The suite covers server access checks,
bounded quantities and totals, registration ownership, finite/unlimited stock,
real coroutine concurrency, payment/delivery failures, compensation and recovery
journals, and source/character changes during provider calls. It runs in CI.
KVP, framework and inventory doubles exercise the actual shop implementation;
installed-provider persistence and live FiveM acceptance remain separate checks.
