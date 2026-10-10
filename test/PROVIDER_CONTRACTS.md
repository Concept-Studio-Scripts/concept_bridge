# Origen, Core and Tgiann inventory contracts

Official websites checked on 2026-10-10. This change targets their currently documented exports. No installed copy/version of these three providers was available for verification. The fixtures check the bridge against documentation, not proprietary provider implementations or a running FiveM server.

## Export mapping

| Provider | Bridge operation | Native contract used |
| --- | --- | --- |
| Origen client | Inventory/count | `getPlayerItems()`; count is summed locally across all stacks. Client `search(target)` opens a search UI. |
| Origen server | Inventory/count/slot | `getItems(source)`, `getItemCount(source, item)`, `getSlot(source, numericSlot)` |
| Origen server | Add/remove/metadata | `addItem(source, item, count, slot, info)`, `removeItem(source, item, count, slot)`, `setMetadata(source, slot, metadata)` |
| Origen server | Stash/open/clear | `registerStash(id, {label, slots, maxweight})`, `OpenInventory(source, identifier)`, `OpenInventoryById(source, target)`, `clearInventory(identifier)` |
| Core both sides | Definitions | `getItemsList()` |
| Core server/client | Inventory/count | Server `getInventory(source).content`; client `getPlayerItems()`; `getItemCount(source, item)` / `getItemCount(item)` |
| Core server | Slot/remove/metadata | `getItemBySlot(source, numericSlot)`, `removeItemExact(source, uniqueId, count)`, `setMetadata(source, numericSlot, metadata)` |
| Core server | Add/capacity/open | `addItem(source, item, count, metadata)`, `canCarry(source, item, count)`, `openInventory(source, id, type, label, nil, true)`, `openOtherPlayerInventory(source, target)` |
| Tgiann both sides | Definitions/inventory | Canonical `Items(name?)`, `GetPlayerItems(source)` / `GetPlayerItems()` |
| Tgiann server/client | Count | `GetItemCount(source, item, metadata)` / `GetItemCount(item, nil, false)`; server retains documented default strict matching. |
| Tgiann server | Slot/add/remove | `GetItemBySlot(source, slot)`; existing QB-style `AddItem(source, item, count, slot, info, false)` and `RemoveItem(source, item, count, slot, info)` |
| Tgiann server | Metadata | `UpdateItemMetadata(source, item, numericSlot, info)` after checking slot identity |

Sources: [Origen inventory exports](https://docs.origennetwork.com/scripts/origen_inventory/exports), [Origen's Reports integration reference](https://docs.origennetwork.com/scripts/origen_reports/custom), [Core exports](https://docs.c8re.store/core-inventory/exports), [Core item structure](https://docs.c8re.store/core-inventory/item-structure), [Tgiann shared exports](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/shared-client-and-server), [Tgiann server exports](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/server), [Tgiann client exports](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/client).

## Bridge behavior and compatibility changes

- Inventory rows retain label, weight, description, count and metadata. QB-style amount/info and alternate count/metadata are accepted. Explicit false close/stack flags remain false. Unloaded inventories and missing slots return empty tables; Tgiann's unnamed `{amount = 0}` sentinel is empty. Definition reads retain complete data and boolean stackability. Core's client cache no longer freezes definitions or drops their fields.
- Core's server content is traversed once, avoiding duplicate expansion of same-name stacks. Content keys are retained as `id`; numeric provider slots become `slot`. If a content row has no numeric slot, `slot` retains its content key for compatibility. Client arrays retain an explicit item ID when available. Legacy opaque IDs are accepted for lookup/removal. Numeric lookup uses the native slot export; targeted removal requires an established content key. Missing mappings return `false, 'item_id_unavailable'`. Metadata always uses a numeric slot, returning `false, 'slot_unavailable'` when an opaque ID cannot be mapped. No string conversion can substitute for that mapping.
- Origen/Core metadata count filters compare supplied fields recursively rather than table identity. Metadata-filtered removal without a slot requires one matching stack large enough for the requested amount. It fails before mutation if matching items are split across smaller stacks; no multi-step removal/rollback is attempted. Unfiltered removal keeps the native total-removal API. Targeted removals check the item name and metadata, and success notifications follow successful native results.
- Origen metadata updates return the native boolean. Core's documented metadata setter returns void, which stays nil; invocation is not represented as a verified boolean success. Both check selected item identity before calling the setter.
- Origen stash registration uses the documented data object. Clear/open retain the registered stash ID and clear retains its registration. Existing trunk/glovebox identifier prefixes are retained; their actual provider storage mapping still needs runtime confirmation. Origen/Core owner, group or coordinate restrictions return `false, 'unsupported_stash_restrictions'`: these wrappers cannot establish those access guarantees from the documented signatures. Authorization for opening/searching inventories remains the caller's responsibility.
- Core stash registration stores the supplied capacity for bridge bookkeeping. Native opening uses a configured inventory type, label and UI flag. Custom capacity is **not applied** through undocumented positional parameters. Configure the provider's inventory type before using these stashes; supporting per-stash capacity needs a separately verified size/config mapping.
- Origen `AddTrunkItems` now returns `false, 'unsupported_trunk_items'`. The old path created a stash and sent an undocumented trunk/bulk-metadata payload while reporting success without checking the result. The current website does not establish that operation; it cannot be certified using a guessed export. Callers depending on it must be migrated before release.

## Documentation gaps and remaining validation

Origen's inventory export page does not list a global definition registry. Its own Reports integration page explicitly references server `exports.origen_inventory:Items()`. Server enumeration retains that documented integration and indexes its result for definition reads. A client registry export is not established, so the client retains the existing bridge framework registry with safe empty reads when unavailable. Provider-only custom items absent from the framework registry are not certified on the client.

Core documents opaque content keys, numeric lookup and numeric metadata arguments, but does not fully specify every returned row's slot/ID fields. Fixtures cover supplied slot mappings, explicit IDs and absent mappings; missing mapping is rejected for operations that require it. Category-only stack limits cannot be inferred from item definitions without provider category data. Native stack/unique fields are normalized when supplied.

The suite covers the mapped reads, relevant mutation signatures/failures, capacity and opening calls. It does not certify untouched vehicle-plate SQL, Tgiann secondary-inventory persistence, every inherited bridge method, access control, image file layouts, concurrent provider changes or database durability. Pin actual versions and exercise the mapped exports, identifiers, custom definitions and stack/slot mappings before release. In-game checks remain deferred as requested.
