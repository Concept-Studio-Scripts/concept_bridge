local Requests = lib.require('@concept_bridge.lib.security.server.requests')
local Appearance = {}

function Appearance.Read(src, provider, read, trusted)
    local ctx, reason
    if trusted then ctx, reason = Requests.Capture('Clothing', src, provider)
    else ctx, reason = Requests.Begin('Clothing', src, provider, 1000, true, nil, 4) end
    if not ctx then return nil, reason end
    local ok, result = Requests.Execute(ctx, read, ctx.src)
    if not ok then return nil, result end
    if type(result) ~= 'table' then return nil, 'appearance_unavailable' end
    return Requests.Copy(result)
end

return Appearance
