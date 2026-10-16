# Network request contracts

ox_lib owns callback registration, correlation and transport. The private security helpers validate domain requests; they do not expose another callback API or dispatcher.

## Server handlers

| Entry point | Caller, payload and authority | Boundaries |
|---|---|---|
| `concept_bridge:Callback:okokPhone:sendEmail` | Callback source owns the sender address; recipient/title/body are validated strings; no caller-supplied player target | One network email per source per 5 seconds; loaded character and active provider required; rechecked after provider lookup. Trusted server `Phone.SendEmail(src, ...)` retains its arguments/results and bypasses network quotas |
| `concept_bridge:Server:genericEmail` (QB/LB/YSeries) | Network source owns the receiving character/phone. Sender label/title/body retain their provider-specific meaning; injected player fields are ignored | Same email quota/readiness/lifetime checks. Strings are bounded to 254/256/8192 bytes; body may contain line breaks. Lookup failures/retired requests cause no subsequent provider send |
| `concept_bridge:Server:DispatchAlert`, `concept_bridge:server:dispatch:sendAlert`, `concept_bridge:Server:piotreq_gpt` | Loaded source; bounded provider-specific data; `BridgeServerConfig.CanSendDispatch(src, provider, data)` must explicitly return true | No default approval hook; client relays are disabled until a gameplay integration validates reports against server-owned state. Missing/false/error hooks deny. One request per source per 5 seconds; yielding authorization rechecks character/provider lifetime. Trusted server methods and existing server-local relay calls bypass the client hook |
| `concept_bridge:cb:GetAppearance` (QB/ESX/FiveM/Illenium server adapters) | Only the callback source's appearance can be read; extra target arguments rejected | Up to four reads/source/second; provider errors and character/source/provider changes discard the reply. Replies are bounded data-only copies |
| `concept_bridge:Callback:GetFrameworkJobs`, ESX `GetFrameworkItems` | Connected source; no payload. Definitions are public and remain available before character selection | Separate four-read/source/second budgets for jobs and items; original table shapes retained; failures return an empty table |
| OX `concept_bridge:Callback:GetAccountBalance` | Loaded callback source; optional bounded account/item name; no injected target or extra payload | Eight reads/source/second allow normal cash/money/bank bursts. Invalid/unavailable/stale reads return nil. Trusted server getter remains unchanged |
| Dynamic `ox_core:useItem:<item>` without ox_inventory | Server-local inventory integration only: `(src, item, itemData?)`; never authorizes a client assertion of item ownership | Not network-registered; positive network source rejected even if another resource registers the name. Native ox_inventory registration/callback behavior is unchanged; that provider owns item-use authorization |
| `concept_bridge:Server:completeCheckout` | Existing registered-shop ownership/access, source/character, quantities, stock and provider checks | Existing 500 ms checkout gap, serialization and compensation journal retained |
| Housing `_OnPlayerInside` and active provider observations | Existing source binding, bounded property data and character/provider validation | Informational server-local notifications only; not proof of housing ownership or authorization. Trusted publishing and argument order retained |
| Shell Enter/Exit | Existing source, linked interaction, proximity, membership, permission hooks and post-yield checks | Private transition/visit/routing state retained; no new public teleport permission |
| Framework loaded/unloaded/job/group events | Existing source-binding and forwarding contracts retained | This change does not authenticate lifecycle transitions or supplied job/group contents. Cancellation hints do not reset request quotas |

Requests capture player identity before provider work and check it again before subsequent effects/returning results. Disconnect/source reuse, unload notifications and owner-qualified provider refreshes retire old contexts; source globals are not reread after yielding. Provider calls already executing internally are not a cross-provider transaction or persistence guarantee.

## Client and provider boundaries

Client-bound entity/marker/shell/notify/helptext/weapon/inventory/boss-menu events and the client appearance callback affect the receiving client's presentation; their payloads are not server authorization. The server validates appearance callback replies as untrusted data. Existing server-origin checks on appearance mutation events remain.

Some dispatch/phone/inventory adapters call provider-owned network endpoints or exports directly. Those providers own their validation and permissions; bridge-owned relay checks cannot secure a separate provider event. The emergencydispatch bridge helper uses the authorized bridge relay while preserving its `Dispatch.SendAlert(data)` API. Installed-provider/native acceptance remains separate from these fixtures.

Client appearance/payload copies reject cycles, callable references, functions, metatables, non-finite numbers, excessive depth/entries and oversized strings. Server-authoritative permission code must never treat a client's appearance or dispatch report as proof of a game-world event.

Server authorization/logging configuration is loaded by `server_scripts` and is excluded from the client packfile. Client/shared settings remain downloadable; the editable server config still ships in the source ZIP. [Cfx.re manifest semantics](https://docs.fivem.net/docs/scripting-reference/resource-manifest/#file) distinguish client downloads from the server script list.

## Dispatch integration

Prefer validating the incident in the gameplay script's server action and sending the alert through trusted server `Dispatch.SendAlert`. Client dispatch relays are disabled by default (`CanSendDispatch = nil`). If an integration needs client-originated reports, set `CanSendDispatch(src, provider, data)` in `settings/serverConfig.lua` to check them against server-owned gameplay state and return `true` only for an allowed report. The hook receives the actual source, selected provider and validated payload; player roles alone do not establish that an incident occurred. Existing client integrations must move alert publication to validated server actions or supply this check. Provider client exports do not become authenticated merely because this bridge hook exists.

Trusted server `Dispatch.SendAlert(data)` is available for default/LB/Redutzu/emergencydispatch. Piotreq retains `Dispatch.SendAlert(src, data)`. Existing provider export names and payload shapes are retained; provider-specific optional functionality outside the bridge-generated relay payload remains available through trusted server APIs.

The payload formats follow the existing adapters and [LB's AddDispatch documentation](https://docs.lbscripts.com/tablet/script-integration/server-exports/#adddispatch) and [Piotreq's server SendAlert documentation](https://piotreq-scripts.gitbook.io/piotreq-scripts/assets-and-guides/police-mdt/dispatch-system). Trust boundaries follow [Cfx.re event-security guidance](https://docs.fivem.net/docs/developers/server-security/).

## Verification

Run `lua test/handler_security.lua`. It loads actual handlers/helpers with provider/native doubles and covers valid requests, trusted server APIs, malformed/oversized input, target injection, quotas, yielding permission/provider work, source reuse and character/provider retirement. Existing shop/housing/shell and source-binding suites retain their contracts. These fixtures do not run FiveM or certify proprietary providers.
