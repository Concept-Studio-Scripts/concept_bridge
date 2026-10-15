local catalog = lib.require('@concept_bridge.lib.providers.shared.catalog')
local resolver = lib.require('@concept_bridge.lib.providers.shared.resolver')
local enabled = {Framework = true, Inventory = true, Fuel = true, Seatbelt = true, Voice = true}
local managed = {}
for _, definition in ipairs(catalog) do
    if enabled[definition.name] then managed[#managed + 1] = definition end
end
ProviderResolver = resolver.New(managed, 'server')
