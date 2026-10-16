local Requests = lib.require('@concept_bridge.lib.security.server.requests')
local FrameworkRequests = {}

function FrameworkRequests.Registry(src, expected, kind, read, ...)
    if select('#', ...) ~= 0 then return {} end
    local ctx = Requests.Begin('Framework', src, expected, 1000, false, 'Framework:' .. kind, 4)
    if not ctx then return {} end
    local ok, result = Requests.Execute(ctx, read)
    if ok and type(result) == 'table' then return result end
    return {}
end

function FrameworkRequests.Balance(src, expected, read, account, ...)
    if select('#', ...) ~= 0 or (account ~= nil and not Requests.Text(account, 64, true)) then return nil end
    -- Cash/bank/custom-item reads often arrive together; allow a bounded burst.
    local ctx = Requests.Begin('Framework', src, expected, 1000, true, 'Framework:balance', 8)
    if not ctx then return nil end
    local ok, result = Requests.Execute(ctx, read, ctx.src, account)
    if ok and type(result) == 'number' and result == result and math.abs(result) < math.huge then return result end
    return nil
end

return FrameworkRequests
