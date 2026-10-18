# Regression checks

Run these commands from the repository root with Lua 5.4:

```sh
lua test/inventory_regressions.lua
lua test/provider_docs.lua
lua test/audit_regressions.lua
lua test/runtime_identity.lua
lua test/ox_lib_contracts.lua
lua test/shop_transactions.lua
lua test/housing_transitions.lua
lua test/consumer_contracts.lua
lua test/shell_access.lua
lua test/provider_selection.lua
lua test/esx_status_cache.lua
lua test/handler_security.lua
lua test/target_zones.lua
```

The fixtures exercise bridge code with dependency/native doubles. They do not start FiveM or certify installed provider versions. Some runtime files use FiveM-specific Lua syntax and cannot be compiled by stock Lua.

CI also checks standard-Lua syntax, release metadata and resource packaging. See [CONTRIBUTING.md](../CONTRIBUTING.md) for those commands.

User-facing contracts and integration guidance live in the [documentation](https://conceptstudio.store/docs/concept-bridge).
