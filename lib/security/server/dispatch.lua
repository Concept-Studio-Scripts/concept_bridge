local Requests = lib.require('@concept_bridge.lib.security.server.requests')
local DispatchRequests = {Current = Requests.Current}

local function number(value, low, high)
    return type(value) == 'number' and value == value and value >= low and value <= high
end

local function point(value, dimensions)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector2' and kind ~= 'vector3' and kind ~= 'vector4' then return false end
    return number(value.x, -100000, 100000) and number(value.y, -100000, 100000)
        and (dimensions == 2 or number(value.z, -100000, 100000))
end

local function jobs(value)
    if Requests.Text(value, 64) then return true end
    if type(value) ~= 'table' or #value == 0 or #value > 8 then return false end
    local count = 0
    for key, name in pairs(value) do
        count = count + 1
        if not Requests.Integer(key, 1, #value) or not Requests.Text(name, 64) then return false end
    end
    return count == #value
end

local function payload(provider, input)
    local data = Requests.Copy(input)
    if type(data) ~= 'table' then return nil end
    local text = Requests.Text
    if provider == 'lb-tablet' then
        if not (data.priority == 'low' or data.priority == 'medium' or data.priority == 'high')
            or not text(data.code, 32, true) or not text(data.title, 128, true) or not text(data.description, 2048, true, true)
            or type(data.location) ~= 'table' or not text(data.location.label, 256, true)
            or not point(data.location.coords, 2) or not number(data.time, 1, 86400)
            or (data.job ~= nil and not jobs(data.job)) then return nil end
        return {priority = data.priority, code = data.code, title = data.title, description = data.description,
            location = {label = data.location.label, coords = data.location.coords}, time = data.time, job = data.job}
    end
    if not text(data.message or 'Dispatch Alert', 2048, true, true)
        or not text(data.code or '10-80', 32, true)
        or (data.coords ~= nil and not point(data.coords, 3))
        or (data.street ~= nil and not text(data.street, 256, true))
        or (data.time ~= nil and not number(data.time, 1, 300000))
        or (data.jobs ~= nil and not jobs(data.jobs))
        or (data.job ~= nil and not text(data.job, 64))
        or (data.icon ~= nil and not text(data.icon, 128))
        or (data.priority ~= nil and not Requests.Integer(data.priority, 1, 5)) then return nil end
    if provider ~= 'piotreq_gpt' and not point(data.coords, 3) then return nil end
    local blip = data.blipData or {sprite = data.sprite or 161, color = data.color or 1, scale = data.scale or 0.8}
    if type(blip) ~= 'table' or not Requests.Integer(blip.sprite or 161, 0, 1000)
        or not Requests.Integer(blip.color or 1, 0, 255) or not number(blip.scale or 0.8, 0, 5) then return nil end
    return {message = data.message or 'Dispatch Alert', code = data.code or '10-80', coords = data.coords,
        street = data.street, time = data.time or 100000,
        jobs = type(data.jobs) == 'string' and {data.jobs} or data.jobs or {'police'}, job = data.job,
        icon = data.icon, priority = data.priority, blipData = blip,
        sprite = blip.sprite or 161, color = blip.color or 1, scale = blip.scale or 0.8}
end

function DispatchRequests.Send(src, provider, send, input)
    local data = payload(provider, input)
    if not data then return false, 'invalid_payload' end
    local ctx, reason = Requests.Begin('Dispatch', src, provider, 5000)
    if not ctx then return false, reason end
    local authorize = BridgeServerConfig and BridgeServerConfig.CanSendDispatch
    local ok, allowed = false, false
    if type(authorize) == 'function' then ok, allowed = pcall(authorize, ctx.src, provider, data) end
    if not ok or allowed ~= true or not Requests.Current(ctx) then
        Requests.Finish(ctx)
        return false, 'access_denied'
    end
    local success, result = Requests.Execute(ctx, send, data, ctx)
    if not success then return false, result end
    return result
end

return DispatchRequests
