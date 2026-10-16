BridgeServerConfig = {}
BridgeServerConfig.MaxInventorySlots = 50
BridgeServerConfig.LogSystem = "none"   -- can be "none", "built-in", "qb", "fivemerr", "fivemanage", or "ox_lib"
BridgeServerConfig.WebhookURL = ""          -- Add webhook URL here if using built-in logging system
BridgeServerConfig.FivemerrApiKey = ""      -- Add Fivemerr API key here if using fiveMerr
BridgeServerConfig.EmbedLogo = "https://cdn.discordapp.com/avatars/299410129982455808/31ce635662206e8bd0132c34ce9ce683?size=1024"
-- Client dispatch relays require server authorization. Trusted server exports bypass this hook.
-- Replace with a server-owned mission/job check when only specific operations may publish alerts.
BridgeServerConfig.CanSendDispatch = function(src, provider, data)
    return IsPlayerAceAllowed(src, 'concept_bridge.dispatch')
end
return BridgeServerConfig