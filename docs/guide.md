# Concept Bridge (`concept_bridge`)

Concept Studio's open-source compatibility layer for FiveM frameworks and providers. Consumer resources use one module API for framework data, inventory, fuel, targeting, notifications, voice, seatbelts and weapons.

[Source and download](https://github.com/Concept-Studio-Scripts/concept_bridge) · [Report an issue](https://github.com/Concept-Studio-Scripts/concept_bridge/issues) · [Concept HUD documentation](/docs/concept-hud)

Use this guide with your installed version's changelog. See the [latest release](https://github.com/Concept-Studio-Scripts/concept_bridge/releases/latest) and [release history](https://github.com/Concept-Studio-Scripts/concept_bridge/releases) for version-specific changes.

## Dependencies and dialogue

Use ox_lib directly for callbacks, locales and shared utilities, and oxmysql for database access. Both are hard dependencies of the bridge.

The bridge does not provide a web app or `Dialogue` module. Scripts using `Dialogue()`, `Bridge().Dialogue`, `Dialogue.Open` or `Dialogue.Close` need their own UI or a separate dialogue resource. There is no bridge frontend to build.

## Installation

Use a folder named **`concept_bridge`**. Download the full resource ZIP from [the latest release](https://github.com/Concept-Studio-Scripts/concept_bridge/releases/latest), or clone the repository. You do not need Tebex, Asset Escrow or a frontend build to install the bridge itself.

Start your database library, ox_lib and chosen providers before the bridge, then start consumer resources:

```cfg
ensure oxmysql
ensure ox_lib
# Start your framework, inventory and other providers here.
# For example: ensure qbx_core, then ensure ox_inventory (separate lines).
ensure concept_bridge
# Start your consumer resources after the bridge.
```

The manifest requires OneSync and server artifact 6116 or newer. It declares both `ox_lib` and `oxmysql` as dependencies and imports `@oxmysql/lib/MySQL.lua` on the server. Each provider keeps its own installation requirements. Start one bridge implementation.

In a consumer's `fxmanifest.lua`, declare the bridge dependency:

```lua
dependency 'concept_bridge'
```

## Providers and standalone behavior

Framework adapters exist for `ox_core`, `qbx_core`, `qb-core` and `es_extended`. Inventory adapters include `ox_inventory`, `qb-inventory`, `ps-inventory`, `tgiann-inventory`, `origen_inventory`, `core_inventory`, `codem-inventory`, `qs-inventory`, `one_inventory` and `jpr-inventory`.

Target adapters include `ox_target`, `qb-target` and `sleepless_interact`. Additional modules cover dispatch, doors, phones, banking, clothing, housing, progress bars, menus, input, weather, skills and vehicle keys. See the [source adapters](https://github.com/Concept-Studio-Scripts/concept_bridge/tree/main/modules) for the exact provider names and implemented operations.

Only started providers are eligible. Adapters refresh automatically when providers start, stop or restart: you do not need to restart the bridge after starting, stopping or switching a provider. When several providers run in one domain, the [provider catalog](https://github.com/Concept-Studio-Scripts/concept_bridge/blob/main/lib/providers/shared/catalog.lua) defines their precedence and compatibility overrides.

The `_default` modules provide selected fallbacks. They do not implement a complete standalone economy or inventory: some functions depend on framework methods. Concept HUD can render without a framework using its seed values and push exports. Custom consumers must check the functions they need and handle unavailable operations.

## Configuration

Edit the bridge's `settings/` files, then restart the resource to reload them.

| File | Settings |
|---|---|
| `settings/sharedConfig.lua` | `Lang`, `DebugLevel`, `Providers`, `Notify`, `HelpText`, `Skills` |
| `settings/clientConfig.lua` | `InputSystem`, `MenuSystem`, `ProgressBarSystem`, `Seatbelt`, `Voice`, `Debug` |
| `settings/serverConfig.lua` | `MaxInventorySlots`, `LogSystem`, logging credentials, branding and `CanSendDispatch` |

`auto` selects a running provider. Use `BridgeSharedConfig.Providers` to override any domain, for example `{ Inventory = 'ox_inventory', Fuel = 'ox_fuel' }`. An explicit choice takes precedence over the older client/shared selector; `none` or an unavailable choice uses the domain's default.

| Setting | Choices |
|---|---|
| `Seatbelt` | `auto`, `qbx_seatbelt`, `qb-smallresources`, `esx_cruisecontrol`, `concept_seatbelt`, `none` |
| `Voice` | `auto`, `pma-voice`, `none` |
| `InputSystem` | `auto`, `ox_lib`, `lation_ui`, `qb-input` |
| `MenuSystem` | `auto`, `ox_lib`, `wasabi_uikit`, `lation_ui`, `qb-menu` |
| `ProgressBarSystem` | `auto`, `ox_lib`, `wasabi_uikit`, `lation_ui`, `ZSX_UIV2`, `keep-progressbar`, `progressbar`, `msk_core` |
| `Lang` | `auto` (follows ox_lib locale selection) or an explicit locale such as `en` |
| `DebugLevel` | `0` (off), `1`, `2` |
| `LogSystem` | `none`, `built-in`, `qb`, `fivemerr`, `fivemanage`, `ox_lib` |

`Seatbelt = 'none'` leaves buckle state unavailable. `Voice = 'none'` uses native proximity. `Debug` enables client module logging. The source files list the notification, help-text and skill provider choices beside their settings.

Server configuration is excluded from client downloads. Keep credentials in `settings/serverConfig.lua`; client/shared settings are public. `CanSendDispatch` is unset by default: see [Dispatch](#dispatch) before using a client relay.

Consumers that cache module exports or create provider-owned targets/shops should handle
`Bridge:Refresh` (domain, module, generation, owner) and refresh or re-register their own
state when owner is `concept_bridge`. `Bridge.Providers.GetStatus()` reports the selected
resources, generations, active alternatives and adapter load errors.

## Export entry points

Exports are available on the client and server where their modules are registered. A module getter returns a table; call its methods with a dot. Use a colon for the FiveM export call:

```lua
local bridge = exports.concept_bridge:Bridge()
local framework = exports.concept_bridge:Framework()
local inventory = exports.concept_bridge:Inventory()

print(framework.GetResourceName())
print(inventory.GetResourceName())
```

| Export | Purpose |
|---|---|
| `Bridge()` | Returns the registered module table, for example `bridge.Framework` |
| Module getters | Return one registered module, for example `Framework()`, `Inventory()`, `Fuel()` |
| `RegisterModule(name, methods)` | Merges methods into a module on the calling side and registers its getter |
| `cLib()` | Returns utility modules registered by `lib/init.lua` |

Load `@ox_lib/init.lua` in each consumer for shared utilities such as callbacks, locales and zones. Use oxmysql directly for server database queries. The bridge's `cLib()` export provides its entity, marker, shell, placement, animation and other extensions.

The client also registers `Fuel`, `Input`, `ProgressBar`, `VehicleKey`, `Weather`, `Target`, `Menu`, `Seatbelt`, `Voice` and `Weapons`. `Banking` is server-only. Other modules and utilities vary by side and provider; inspect the relevant adapter before using provider-specific functions.

## Framework reads

Framework adapters implement these calls; the default module does not supply every getter.

| Method | Client signature | Server signature |
|---|---|---|
| `GetResourceName` | `()` | `()` |
| `GetPlayerJobData` | `()` | `(src)` |
| `GetAccountBalance` | `(account)` | `(src, account)` |
| `GetHunger` | `()` | `(src)` |
| `GetThirst` | `()` | `(src)` |
| `GetIsPlayerDead` | `()` | `(src)` |
| `GetIsPlayerDown` | `()` | `(src)` |

Client adapters expose `GetIsPlayerLoaded()` as a readiness check; on ox_core it follows the loaded character, including character selection and logout. QBCore, Qbox and ESX getters can return nil or empty data before a character is loaded. Account names and extra metadata functions depend on the adapter. Preserve an unavailable balance instead of displaying a new zero balance.

`GetIsPlayerDown` includes death and last stand where the framework supports them. `GetIsPlayerDead` retains the framework's dead-state meaning.

```lua
-- client.lua
local framework = exports.concept_bridge:Framework()
if framework.GetIsPlayerLoaded and framework.GetIsPlayerLoaded() then
    local balance = framework.GetAccountBalance('bank')
    if type(balance) == 'number' then
        print(('Bank: %s'):format(balance))
    end
end
```

## Inventory reads and mutations

| Method | Client signature | Server signature |
|---|---|---|
| `HasItem` | `(item, requiredCount?)` | `(src, item, requiredCount?)` |
| `GetItemCount` | `(item)` | `(src, item, metadata?)` |
| `GetPlayerInventory` | `()` | `(src)` |
| `GetItemInfo` | `(item)` | `(item)` |
| `GetImagePath` | `(item)` | `(item)` |
| `AddItem` | Server only | `(src, item, count, slot?, metadata?)` |
| `RemoveItem` | Server only | `(src, item, count, slot?, metadata?)` |
| `CanCarryItem` | Server only | `(src, item, count)` |
| `SetMetadata` | Server only | `(src, item, slot, metadata)` |

Optional filters and return values vary by provider. Check the selected adapter's contract and handle failure. `CanCarryItem` is a preflight check, not a guarantee that `AddItem` will succeed. Metadata setters use supported provider APIs; unsupported operations can return a failure reason. The slot argument is not honored by every provider.

Client additions include `GetCurrentWeapon(ped?)`, `InvalidateWeaponCache()`, `GetItemWorth(item, metadataKey?)` and `IsOpen()`. Worth sums item counts multiplied by the selected metadata value; the default key is `worth`.

`SavePlayerInventory(src)` is a server method supported for qb-inventory, ps-inventory and jpr-inventory. Other providers return `false, 'unsupported'`; ox_inventory manages its own save schedule.

Perform inventory and money mutations on the server after checking permissions and validating player input. Opening or searching another inventory also requires authorization in your server code.

### Inventory provider details

| Provider | Integration requirements |
|---|---|
| QB/PS with Qbox | Qbox's QB compatibility exports must provide `Shared.Items`. Missing definitions can return `false, 'item_registry_unavailable'` or `false, 'unknown_item'` before add/remove operations |
| QB/Qbox metadata | `Inventory.SetMetadata(src, item, slot, metadata)` changes the selected slot while preserving other items/counts. All units in the slot share its metadata. Check its boolean result and optional failure reason; unsupported updates do not remove/re-add items |
| Origen | Stash IDs remain the IDs passed to `RegisterStash`. Owner/group/coordinate restrictions return `false, 'unsupported_stash_restrictions'`. `AddTrunkItems` returns `false, 'unsupported_trunk_items'` |
| Core | Content IDs may be opaque strings, while metadata requires a numeric slot. Missing mappings return `item_id_unavailable` or `slot_unavailable`. Configure stash capacity through the provider's inventory type; bridge bookkeeping alone does not resize it. Owner/group/coordinate restrictions return `false, 'unsupported_stash_restrictions'` |
| Tgiann | Definition reads use `Items`; inventory/slot/metadata calls use the provider's numeric slot contracts. Empty slot sentinels are normalized to empty tables |

Origen/Core metadata filters match supplied fields recursively. When removing by metadata without a slot, one matching stack must hold the requested amount; the bridge does not combine partial removals across several stacks. Core's metadata setter returns no value; nil does not establish whether an update persisted.

QB/PS snapshot metadata setters are synchronous and must not yield while applying inventory state. A successful in-memory update does not guarantee database persistence. A provider with different concurrency or persistence requirements needs its own adapter.

Origen server definitions use its documented `Items()` integration; client definitions use the framework registry. Provider-only custom items need matching framework definitions for client lookups. Verify Core slot/ID mappings and provider-specific stash/vehicle inventory identifiers against your installed provider.

The adapters use these provider API references: [Origen inventory](https://docs.origennetwork.com/scripts/origen_inventory/exports), [Origen definitions integration](https://docs.origennetwork.com/scripts/origen_reports/custom), [Core exports](https://docs.c8re.store/core-inventory/exports), [Core item structure](https://docs.c8re.store/core-inventory/item-structure), [Tgiann shared](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/shared-client-and-server), [Tgiann server](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/server), [Tgiann client](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/client), [Qbox compatibility](https://docs.qbox.re/faq), [QB inventory](https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-inventory) and [PS inventory](https://github.com/Project-Sloth/ps-inventory/blob/main/server/main.lua). Check the exact versions you run; supported operations vary by provider.

## Dispatch

Send gameplay alerts from server code after validating the incident there. The bridge routes alerts to the selected provider; it cannot establish that a client-reported robbery or other incident happened.

Server methods are provider-specific:

| Selected provider | Server call and payload |
|---|---|
| `default` | `Dispatch.SendAlert(data)` with `jobs`, `coords`, `message`, `code`, `sprite`, `color`, `scale`, and `time` in milliseconds |
| `lb-tablet` | `Dispatch.SendAlert(data)` with LB's `priority`, `code`, `title`, `description`, `location = { label, coords }`, `time` in seconds and optional `job` |
| `redutzu-mdt` | `Dispatch.SendAlert(data)` with `code`, `message`, `street`, `time` and `coords` |
| `emergencydispatch` | `Dispatch.SendAlert(data)` with `job` or `jobs`, `message` and `coords` |
| `piotreq_gpt` | `Dispatch.SendAlert(src, data)` with `message`, `code` and optional `icon`, `blipData`, `priority` |

For example, after your server has validated an incident, this sends an LB Tablet alert:

```lua
-- server.lua; incident validation belongs to your gameplay script.
local dispatch = exports.concept_bridge:Dispatch()
if dispatch.GetResourceName() == 'lb-tablet' then
    dispatch.SendAlert({
        priority = 'high',
        code = '10-90',
        title = 'Store robbery',
        description = 'A store robbery has been confirmed.',
        location = { label = 'Store', coords = vector2(25.7, -1347.3) },
        time = 300,
        job = 'police',
    })
end
```

Other providers may offer only client integrations. Check the selected adapter before using a server method. Payloads accepted by a provider's client and server methods can differ; do not forward a client payload blindly.

Bridge-owned client relays for default/LB/Redutzu/emergencydispatch/Piotreq are disabled until `BridgeServerConfig.CanSendDispatch(src, provider, data)` returns `true`. If an integration needs client reports, implement that hook in `settings/serverConfig.lua` and match the actual caller and validated report against server-owned gameplay state. Missing, false or failing hooks deny the request.

Authorized client reports are limited to one per player per five seconds. Payload checks retain the bridge-generated provider fields; additional provider-specific options belong in trusted server calls. Trusted server dispatch bypasses the client authorization hook and quota. Provider-owned client endpoints have their own security requirements.

## Phone, appearance and usable items

`Phone.SendEmail` uses `(email, title, message)` on the client and `(src, email, title, message)` on the server. With okokPhone, `email` is the recipient and the sender belongs to `src`. With QB/LB/YSeries, `email` is the sender label and the mail is delivered to `src`'s character or phone. Check provider-specific return values.

`Clothing.GetAppearance(src)` is a server read. Its client callback reads only the calling player's appearance; it does not accept another player ID. Appearance received from a client is data, not permission to change server state.

`Framework.RegisterUsableItem(itemName, callback)` calls the server callback with `(src, itemData)`. Native inventory integrations keep their own item-use checks. With OX and no ox_inventory, the fallback event name is `'ox_core:useItem:' .. itemName` and is server-local: a trusted server inventory must validate ownership/use before calling `TriggerEvent(eventName, src, itemData)`. Client scripts cannot assert item ownership through that fallback.

### Client request limits

| Bridge-owned request | Limit per player |
|---|---|
| Email through okokPhone/QB/LB/YSeries | One per five seconds; sender label/recipient up to 254 bytes, subject 256 bytes, body 8192 bytes |
| Appearance reads through QB/ESX/FiveM/Illenium adapters | Four per second |
| ESX/OX job definitions; ESX item definitions | Four per second for each definition list |
| OX account reads | Eight per second, allowing cash/bank/custom-item bursts |

Use module APIs rather than calling internal callback names. Invalid, excessive, unavailable or outdated client requests can fail or return no data. Email bodies may contain line breaks; empty subjects/bodies are accepted. Character-dependent requests require a loaded character. Job/item definitions remain available before character selection.

The bridge rechecks player, character and provider state around yielding work and discards outdated results. Client appearance replies must contain bounded plain data. Trusted server phone calls bypass client quotas; direct framework getters retain their own contracts. ox_lib owns callback transport and timeouts; use ox_lib directly in your own scripts.

## Target lifecycle and removal

`canInteract` results are cached per option and target entity for up to one second. The bridge tracks each target zone under the resource that creates it, so another resource stopping does not remove your zones. When the target provider restarts, recreate your own targets in response to `Bridge:Refresh`.

Global target removal uses the provider's identifiers: QB option labels, and OX/Sleepless option names. If a QB option's `name` differs from its `label`, pass the label. An empty removal request does not clear every global option. Keep the identifiers for options your resource creates and remove them during cleanup.

## Shops, housing and shells

- **Fallback shops:** register stock, coordinates and allowed groups on the server with `Shops.CreateShop(name, inventory, coords, groups, options)`. `options.distance` defaults to 3 metres and `options.bucket` to 0. Opening and checkout enforce server-side access; do not use client-supplied prices or stock as authority.
- **Housing:** inside/outside notifications are informational. They do not prove property ownership or grant entry, stash access or permission to change server state.
- **Shells:** put private access checks in the shell's server `onEnter(src, shellId)` hook. Client entry requests also require a linked entrance and proximity. Trusted server entry can teleport a player remotely, so validate the gameplay action before calling it.

Shell routing buckets must be positive integers; bucket 0 is not a shell destination. A configured `onEnter` hook must allow entry, and a failing hook denies it. Leaving a shell restores the player's previous routing bucket; switching shells retains the original return location.

## Fuel, seatbelt, voice and weapons

These are client modules:

| Module | Methods | Result |
|---|---|---|
| `Fuel` | `GetResourceName()`, `GetFuel(vehicle)`, `SetFuel(vehicle, fuel, type?)` | Provider name and fuel level; setter behavior varies by provider |
| `Seatbelt` | `GetResourceName()`, `HasSeatbelt(vehicle)`, `GetState()` | Capability boolean; buckle state is `true`, `false` or `nil` |
| `Voice` | `GetResourceName()`, `GetProximity()` | `{ index, mode, distance }`; fields can be unavailable |
| `Weapons` | `GetResourceName()`, `GetCurrentWeapon(ped?)`, `Invalidate(notify?)` | Weapon pack or `nil` when holstered |

A weapon pack has `name`, `label`, `hash`, `group`, `image`, `images`, `clip` and `reserve`. `ox_inventory` is authoritative when running; otherwise supported QB caches and native reads provide fallbacks. `Invalidate(true)` clears the read cache and emits an update.

```lua
-- client.lua
local voice = exports.concept_bridge:Voice()
local proximity = voice.GetProximity()
print(proximity.distance)

local seatbelt = exports.concept_bridge:Seatbelt()
local state = seatbelt.GetState()
-- nil means unknown/unavailable; it does not mean unbuckled.
```

## Normalized events

Subscribe to bridge events with `AddEventHandler`. They are adapter notifications; emission coverage varies by provider.

| Client event | Payload |
|---|---|
| `concept_bridge:Client:OnPlayerLoaded` | No arguments |
| `concept_bridge:Client:OnPlayerUnload` | No arguments |
| `concept_bridge:Client:OnPlayerJobUpdate` | `name, label, gradeName, grade` |
| `concept_bridge:Client:OnNeedsUpdate` | Optional `{ hunger, thirst, stress }` |
| `concept_bridge:Client:OnInventoryUpdate` | Optional `{ resource, reason }` |
| `concept_bridge:Client:OnInventoryOpenChange` | `open` boolean |
| `concept_bridge:Client:OnWeaponUpdate` | Weapon pack, or `nil` |
| `concept_bridge:Client:OnVoiceUpdate` | `{ index, mode, distance }` |
| `concept_bridge:Client:OnSeatbeltUpdate` | Buckle boolean, or `nil` |
| `concept_bridge:Client:OnAccountUpdate` | `{ account, action?, amount? }` |

| Server event | Payload |
|---|---|
| `concept_bridge:Server:OnPlayerLoaded` | `src` |
| `concept_bridge:Server:OnPlayerUnload` | `src` |
| `concept_bridge:Server:OnPlayerJobChange` | `src, jobName` |

`OnAccountUpdate` is a hint to re-read the local character's account balance; it does not contain the balance. ox_core emits bank updates and ESX emits account updates; additional fields depend on the adapter. Retain a polling or refresh path for providers that do not emit the hint.

```lua
-- client.lua
AddEventHandler('concept_bridge:Client:OnVoiceUpdate', function(proximity)
    print(proximity.distance)
end)
```

Local event payloads are notifications, not proof of permission for server-side mutations.

## Custom modules and restart handling

Start your integration resource after the bridge. Register only the methods you implement, on the client or server side that consumes them:

```lua
-- client.lua in your integration resource
exports.concept_bridge:RegisterModule('Framework', {
    GetResourceName = function() return 'my_framework' end,
    GetIsPlayerLoaded = function() return LocalPlayer.state.loaded == true end,
    GetHunger = function() return 100 end,
})
```

Registration merges methods into the existing table; it does not clear other adapter methods. Complete the contracts your consumers require. A bridge restart resets registrations: re-register your integration and re-acquire consumer module tables when the bridge starts again. Drop cached references when it stops.

Provider lifecycle refreshes emit `Bridge:Refresh(domain, module, generation, owner)` with owner `concept_bridge`. Custom module registration emits the same local event with `moduleName, moduleTable` only. Check the owner when responding specifically to provider changes.

## Troubleshooting

- **Missing dependency:** check `ox_lib`, `oxmysql`, OneSync and server artifact requirements, then start providers before `concept_bridge`.
- **Missing export or module:** confirm the resource folder is exactly `concept_bridge` and the resource is started. Check that the module exists on the calling side.
- **Provider shows `default`:** verify its resource name, started state, selection override and adapter support. Inspect `Bridge.Providers.GetStatus()` for load errors; the bridge detects provider starts and stops automatically.
- **Client dispatch sends nothing:** use a validated server dispatch call or configure `CanSendDispatch` against server-owned incident state.
- **HUD data remains empty:** use `/hudbridgestatus` with its command permission granted; see the [HUD documentation](/docs/concept-hud).
- **Inventory operation fails:** check item definitions, capacity, metadata and the selected provider's supported contract. Log the returned failure reason.
- **Data stops after a restart:** refresh cached module references and custom registrations.

## License and support

Concept Bridge is distributed under the preserved **GPLv3 license**, with credits to The Order of the Sacred Framework and contributors. Its source is derived from [Community Bridge](https://github.com/TheOrderFivem/community_bridge); the repository keeps the [origin and attributions](https://github.com/Concept-Studio-Scripts/concept_bridge/blob/main/ORIGIN.Md). Use the [Concept Bridge issue tracker](https://github.com/Concept-Studio-Scripts/concept_bridge/issues) for bridge-specific support.
