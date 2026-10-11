# Concept Bridge

Concept Studio's compatibility layer for FiveM frameworks, inventories, targeting, notifications and other providers. The runtime resource name is **concept_bridge**.

**Current release: 1.0.0** · 2026-10-10.

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

`Fuel`, `VehicleKey`, `Target` and `Phone` providers are detected from started
resources; they have no config key.

### Shared (`settings/sharedConfig.lua`)

| Key | Values | Notes |
|---|---|---|
| `Lang` | `auto` · locale name (`en`, `fr`, ...) | `auto` follows ox_lib locale selection |
| `DebugLevel` | `0` · `1` · `2` | |
| `Notify` | `auto` · `ox_lib` · `r_notify` · ... | |
| `HelpText` | `auto` · `ox_lib` · ... | |
| `Skills` | `auto` · `OT_skills` · `evolent_skills` · `pickle_xp` | |

### Consumer modules

QB/PS inventory adapters resolve Qbox item definitions through its QB compatibility bridge. Inventory mutations reject missing definitions before changing items. QB/Qbox metadata updates preserve item counts and use provider setters instead of removing/re-adding items; unsupported updates return a failure reason. See [inventory regression tests and API contracts](test/README.md) for supported paths and validation limits.

Origen, Core and Tgiann reads and selected mutation/opening paths follow their official website exports. [Provider contracts](test/PROVIDER_CONTRACTS.md) lists API mappings, slot/ID semantics and compatibility changes, including operations whose contract remains unsupported. Validate the exact provider versions and in-game behavior before deploying to production.

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

## Utility ownership (Unreleased)

Database access uses oxmysql directly through `@oxmysql/lib/MySQL.lua` on the
server and parameterized `MySQL.*` queries. The bridge does not expose a SQL utility.

ox_lib supplies callbacks, module loading, locales, points, zones, raycasts,
vehicle properties, table helpers, printing, random strings, asset streaming,
clipboard access, input dialogs and scaleforms. Use its APIs directly in each
consumer resource with `@ox_lib/init.lua` loaded.

The bridge retains provider adapters and extensions for replicated entities and
markers, shell management, object placement, animation completion tracking,
particle effects, cutscenes, geometry/easing and logging providers. These extensions use ox_lib for their underlying generic utilities.

Internal RPC uses `lib.callback.register` and `lib.callback.await`. Target players
are explicit for server-to-client calls; client calls pass `false` as the ox_lib
cooldown parameter. Handler permissions remain the responsibility of server code.

## Fallback shops (Unreleased)

Server `Shops.CreateShop(name, inventory, coords, groups?, options?)` registers the
bridge's fallback shop. The default inventory adapter forwards
`Inventory.RegisterShop` to this implementation. Native inventory shop providers
keep their own registration and transaction contracts.

Provide one coordinate or a list of coordinates with finite x/y/z values. Each
item needs a unique name and finite non-negative price. `count = nil` means
unlimited stock; a non-negative integer count is shared stock for the current
bridge session. Registration copies the data; re-registering a name does not
replenish stock. Stock resets when the bridge restarts and shops are registered.

Groups are minimum-grade maps such as `{police = 3}` or name lists. Nil/empty
groups allow any loaded character. Checks use the server's normalized job,
QB/Qbox gang or OX group membership. `options.distance` defaults to 3 metres
(maximum 20), and `options.bucket` defaults to 0. These requirements apply to
opening and every checkout; a displayed menu does not authorize a purchase.

Checkout accepts money/bank accounts and integer quantities from 1 to 100, uses
the registered price, and caps the total at 2,147,483,647. It serializes each
player's checkout, enforces a 500 ms server cooldown and reserves finite stock
before yielding payment operations. Confirmed failed delivery restores stock
and compensates payment; free items skip the debit.

Recovery records use server resource KVP under `concept_bridge:shop_checkout:`.
Server `Shops.GetPendingCheckout(src)` inspects the current character's record;
`Shops.RetryCheckoutRefund(src)` retries a confirmed outstanding refund, also
attempted before the character's next checkout. Confirmed completion cannot
refund again, including after a reconnect with a different source ID. Interrupted
or contradictory provider effects are retained as `review_required`; inspect the
record and reconcile the provider state before clearing it. No client event
accepts a refund recipient or amount. Do not delete unresolved journals as cleanup.

## Development and support

Use this repository's [issues](https://github.com/Concept-Studio-Scripts/concept_bridge/issues) and pull requests for Concept Bridge support. [Upstream documentation](https://theorderfivem.github.io/docs) remains a reference for inherited APIs, not a guarantee of identical contracts or support from upstream.

Run the commands in [test/README.md](test/README.md). For the NUI, run `npm ci`, `npm run lint` and `npm run build` from web/. The build is finite; web/dist is committed for normal resource installation. CI checks Lua regressions, NUI lint/build and packaging.

Tags such as `v1.0.0` build the NUI and publish a GitHub Release with a full-source,
prebuilt resource ZIP. Manual runs of the same Release workflow upload a ZIP
artifact without publishing. Manifest, NUI package and lockfile versions must
match the tag. [CHANGELOG.md](CHANGELOG.md) contains owner-facing notes;
[CHANGELOG.dev.md](CHANGELOG.dev.md) supplies the GitHub release notes.

For local packaging with PowerShell 7, run `./tools/package-release.ps1 -Build`. The ZIP includes
the GPL license, origin/credits, Lua and NUI source, tooling and tests, as well as
the prebuilt UI. Dependencies, local logs and repository metadata are excluded.
