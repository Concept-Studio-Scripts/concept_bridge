# Concept Bridge

Concept Studio's compatibility layer for FiveM frameworks, inventories, targeting, notifications and other providers. The runtime resource name is **concept_bridge**.

**Current release: 1.0.0** <!-- x-release-please-version -->

Derived from [Community Bridge](https://github.com/TheOrderFivem/community_bridge),
originally developed by The Order of the Sacred Framework and contributors.
See [origin and attributions](ORIGIN.Md) and the preserved [GPLv3 license](LICENSE).

## Installation

Download the prebuilt resource ZIP from [releases](https://github.com/Concept-Studio-Scripts/concept_bridge/releases/latest) and extract its `concept_bridge` folder into your resources directory. You can also clone the repository with its committed NUI build. Start ox_lib and your framework/inventory providers before it, and your consumers afterward:

```cfg
ensure oxmysql
ensure ox_lib
# ensure your framework and inventory resources here
ensure concept_bridge
ensure concept_hud
```

Requires OneSync, server artifact 6116 or newer, ox_lib and oxmysql. Consumers use `exports.concept_bridge:Bridge()` and the `concept_bridge:` event namespace. Run one bridge implementation.

Use ox_lib directly for shared utilities and oxmysql for database access.

## Features

### Framework Compatibility

* Supports ox_core, QBCore (`qb-core`), Qbox (`qbx_core`) and ESX (`es_extended`)
* Custom frameworks can register their own module methods (see below)
* Provides a unified API to standardize resource interaction

### Inventory Systems

* Adapters for `ox_inventory`, `qb-inventory`, `ps-inventory`, `codem-inventory`, `core_inventory`, `origen_inventory`, `tgiann-inventory`, `qs-inventory`, `one_inventory` and `jpr-inventory`

### Dispatch and MDT

* Integrates with ps-dispatch, cd\_dispatch, lb-tablet, bub\_mdt, and other dispatch systems
* See [dispatch adapters](modules/dispatch) for provider-specific calls

### Targeting Systems

* Works with qb-target, ox\_target, sleepless_interact, and similar targeting resources

### Doorlock and Security

* Adapters for `ox_doorlock`, `qb-doorlock`, `rcore_doorlock` and `doors_creator`

### Vehicle Keys and Locking

* Adapters for QB, Qbox, Renewed, CD Garage and other [vehicle key providers](modules/vehiclekey)

### Fuel Systems

* Adapters for `LegacyFuel`, `ox_fuel`, `qb-fuel`, `ps-fuel` and other [fuel providers](modules/fuel)

### Clothing and Appearance

* Integrates with illenium-appearance, fivem-appearance, qb-clothing, esx\_skin, rcore\_clothing and default fallback clothing systems

### Additional Features

* Progress bars, notifications, weather synchronization, and skill system integration
* Seatbelt providers (qbx\_seatbelt, qb-smallresources, esx\_cruisecontrol, concept\_seatbelt), voice proximity (pma-voice), and normalized current-weapon/ammo reads
* Developer tools including replicated entities and markers, cutscene management, particle effects, and advanced object placement

---

## Configuration

### Client (`settings/clientConfig.lua`)

| Key | Values | Notes |
|---|---|---|
| `InputSystem` | `auto` · `ox_lib` · `lation_ui` · `qb-input` | Explicit selection or auto-detect |
| `MenuSystem` | `auto` · `ox_lib` · `wasabi_uikit` · `lation_ui` · `qb-menu` | |
| `ProgressBarSystem` | `auto` · `ox_lib` · `wasabi_uikit` · `lation_ui` · `ZSX_UIV2` · `keep-progressbar` · `progressbar` · `msk_core` | |
| `Seatbelt` | `auto` · `qbx_seatbelt` · `qb-smallresources` · `esx_cruisecontrol` · `concept_seatbelt` · `none` | `none` disables buckle events |
| `Voice` | `auto` · `pma-voice` · `none` | `none` falls back to native proximity |
| `Debug` | `true` · `false` | Extra module registration logging |

Only started providers are selected. The explicit order and compatibility overrides
are defined in [the provider catalog](lib/providers/shared/catalog.lua). Set
`BridgeSharedConfig.Providers` to override a domain, for example
`{ Inventory = 'ox_inventory', Fuel = 'ox_fuel' }`; `none` selects its default.
Existing client/shared selectors still apply unless overridden there.

Adapters refresh on provider starts, stops and restarts. `Bridge.Providers.GetStatus()`
reports each selected resource, generation, other active candidates and load errors.
Consumers that cache exports or register provider-owned targets/shops should listen to
`Bridge:Refresh` (domain, module, generation, owner) and refresh or re-register their
own state when owner is `concept_bridge`.

### Shared (`settings/sharedConfig.lua`)

| Key | Values | Notes |
|---|---|---|
| `Lang` | `auto` · locale name (`en`, `fr`, ...) | `auto` follows ox_lib locale selection |
| `DebugLevel` | `0` · `1` · `2` | |
| `Notify` | `auto` · `ox_lib` · `r_notify` · ... | |
| `HelpText` | `auto` · `ox_lib` · ... | |
| `Skills` | `auto` · `OT_skills` · `evolent_skills` · `pickle_xp` | |

### Server (`settings/serverConfig.lua`)

`CanSendDispatch(src, provider, data)` authorizes client dispatch relays and must return `true` to allow a request. The default checks the `concept_bridge.dispatch` ACE; replace it with a server-owned mission/job eligibility check where appropriate. Trusted server dispatch calls retain their provider contracts and bypass this client hook. [Request contracts](test/REQUEST_SECURITY.md) describe the network limits and server inventory integration.

### Consumer modules

See the [API documentation](https://conceptstudio.store/docs/concept-bridge) for module usage and [provider contracts](test/PROVIDER_CONTRACTS.md) for inventory export mappings.

| Module | API (`exports.concept_bridge:<Module>()` or `Bridge.<Module>`) |
|---|---|
| `Framework` | players, job/grade, money, hunger/thirst/stress, `GetIsPlayerDead`, `GetIsPlayerDown` (dead or last stand; server takes `src`) |
| `Inventory` | items, worth, current weapon, open state, image paths, `SavePlayerInventory(src)` (qb / ps / jpr; `false, 'unsupported'` elsewhere) |
| `Seatbelt` | `GetResourceName`, `HasSeatbelt(vehicle)`, `GetState()` |
| `Voice` | `GetResourceName`, `GetProximity()` |
| `Weapons` | `GetCurrentWeapon(ped?)`, `Invalidate(notify?)` |

Normalized events (stable, additive):

| Side | Event | Payload |
|---|---|---|
| client | `concept_bridge:Client:OnPlayerLoaded` | — |
| client | `concept_bridge:Client:OnPlayerUnload` | — |
| client | `concept_bridge:Client:OnPlayerJobUpdate` | `name, label, gradeName, grade` |
| client | `concept_bridge:Client:OnNeedsUpdate` | `{ hunger, thirst, stress }?` |
| client | `concept_bridge:Client:OnInventoryUpdate` | `{ resource, reason }?` |
| client | `concept_bridge:Client:OnInventoryOpenChange` | `open: boolean` |
| client | `concept_bridge:Client:OnWeaponUpdate` | weapon pack, or `nil` when holstered |
| client | `concept_bridge:Client:OnVoiceUpdate` | `{ index, mode, distance }` |
| client | `concept_bridge:Client:OnSeatbeltUpdate` | `buckled: boolean?` |
| client | `concept_bridge:Client:OnAccountUpdate` | `{ account: 'bank', action: string, amount: number? }` |
| server | `concept_bridge:Server:OnPlayerLoaded` | `src` |
| server | `concept_bridge:Server:OnPlayerUnload` | `src` |
| server | `concept_bridge:Server:OnPlayerJobChange` | `src, jobName` |

`OnAccountUpdate` is a hint that the local character's own bank account has
changed (ox_core: deposit/withdraw/transfer/balance updates). It carries no
balance — consumers re-read `Framework.GetAccountBalance('bank')`. Adapters
that do not emit it leave consumers on their polling cadence.

### Custom frameworks

Custom frameworks integrate without a bridge config key: register (or extend)
a `Framework` module from your own resource, on the side(s) you need.

```lua
exports.concept_bridge:RegisterModule('Framework', {
    GetResourceName = function() return 'my_framework' end,
    GetIsPlayerLoaded = function() return LocalPlayer.state.loaded == true end,
    GetHunger = function() return 100 end,
    -- ... any other Framework functions you support
})
```

Registered functions merge over the `_default` fallbacks, so consumers only ever
talk to concept_bridge.

## Development and support

Use this repository's [issues](https://github.com/Concept-Studio-Scripts/concept_bridge/issues) and pull requests for Concept Bridge support. [Upstream documentation](https://theorderfivem.github.io/docs) remains a reference for inherited APIs, not a guarantee of identical contracts or support from upstream.

Run the commands in [test/README.md](test/README.md). For the NUI, run `npm ci`, `npm run lint` and `npm run build` from web/. The build is finite; web/dist is committed for normal resource installation. CI checks Lua regressions, NUI lint/build and packaging.

Releases include a full-source resource ZIP with a prebuilt UI.
[CHANGELOG.md](CHANGELOG.md) contains the release notes;
[CONTRIBUTING.md](CONTRIBUTING.md) explains development and releases.

For local packaging with PowerShell 7, run `./tools/package-release.ps1 -Build`. The ZIP includes
the GPL license, origin/credits, Lua and NUI source, tooling and tests, as well as
the prebuilt UI. Dependencies, local logs and repository metadata are excluded.
