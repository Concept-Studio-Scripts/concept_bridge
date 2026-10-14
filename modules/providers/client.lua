local catalog = lib.require('@concept_bridge.lib.providers.shared.catalog')
local resolver = lib.require('@concept_bridge.lib.providers.shared.resolver')
ProviderResolver = resolver.New(catalog, 'client')
