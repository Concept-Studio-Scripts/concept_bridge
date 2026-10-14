local catalog = lib.require('@concept_bridge.lib.providers.shared.catalog')
local resolver = lib.require('@concept_bridge.lib.providers.shared.resolver')
local enabled = {Framework = true, Inventory = true, HelpText = true, Notify = true, Skills = true, BossMenu = true, Fuel = true, Input = true, ProgressBar = true, VehicleKey = true, Weather = true, Target = true, Menu = true, Seatbelt = true, Voice = true}
local managed = {}
for _, definition in ipairs(catalog) do
    if enabled[definition.name] then managed[#managed + 1] = definition end
end
ProviderResolver = resolver.New(managed, 'client')
