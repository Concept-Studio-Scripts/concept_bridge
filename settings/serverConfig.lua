BridgeServerConfig = {}
BridgeServerConfig.MaxInventorySlots = 50
BridgeServerConfig.LogSystem = "none"   -- can be "none", "built-in", "qb", "fivemerr", "fivemanage", or "ox_lib"
BridgeServerConfig.WebhookURL = ""          -- Add webhook URL here if using built-in logging system
BridgeServerConfig.FivemerrApiKey = ""      -- Add Fivemerr API key here if using fiveMerr
BridgeServerConfig.EmbedLogo = "https://cdn.discordapp.com/avatars/299410129982455808/31ce635662206e8bd0132c34ce9ce683?size=1024"
-- Prefer sending dispatch from a gameplay server action after it validates the incident.
-- Client relays are disabled until this hook validates reports against server-owned state.
-- CanSendDispatch(src, provider, data) must return true only for an allowed report.
BridgeServerConfig.CanSendDispatch = nil
return BridgeServerConfig