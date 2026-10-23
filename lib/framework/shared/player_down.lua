-- "Down": a player who cannot act - dead, or in last stand. One rule for every framework, so a consumer does
-- not have to know which of them has a last stand and what it calls it.
local Down = {}

--- QBCore / Qbox character metadata -> boolean
function Down.FromQbMetadata(metadata)
    if type(metadata) ~= 'table' then return false end
    return metadata.isdead == true or metadata.inlaststand == true
end

--- any truthy "dead" value a framework hands out -> boolean
function Down.FromFlag(value)
    return value == true or value == 1
end

--- the state bags the usual ambulance scripts set (some write no framework flag at all) -> boolean
function Down.FromState(src)
    local ok, st = pcall(function() return Player(src).state end)
    if not ok or not st then return false end
    return st.isDead == true or st.dead == true or st.isDowned == true or st.inlaststand == true or st.isInLastStand == true
end

return Down
