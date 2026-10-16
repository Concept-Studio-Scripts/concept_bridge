local Requests = lib.require('@concept_bridge.lib.security.server.requests')
local PhoneRequests = {Current = Requests.Current}

function PhoneRequests.Send(src, provider, send, email, title, message, recipient)
    if not Requests.Text(email, 254, not recipient) or not Requests.Text(title, 256, true)
        or not Requests.Text(message, 8192, true, true)
        or (recipient and not email:match('^[^%s@]+@[^%s@]+$')) then return false, 'invalid_payload' end
    local ctx, reason = Requests.Begin('Phone', src, provider, 5000)
    if not ctx then return false, reason end
    local ok, result, detail = Requests.Execute(ctx, send, ctx.src, email, title, message, ctx)
    if not ok then return false, result end
    return result, detail
end

return PhoneRequests
