-- Write ONE player's inventory to the database now. A consumer that moves an item between two players wants both
-- sides durable at once (a crash between two periodic saves would otherwise roll one of them back).
-- Only some providers can do this; the others answer false, 'unsupported' - never a silent no-op.
local Save = {}

--- providers that export SaveInventory(src)
Save.Providers = { ['qb-inventory'] = true, ['ps-inventory'] = true, ['jpr-inventory'] = true }

---@return boolean saved
---@return string? reason 'unsupported' | 'invalid_player' | 'provider_error'
function Save.Player(provider, src)
    if type(src) ~= 'number' or src < 1 then return false, 'invalid_player' end
    if not Save.Providers[provider] then return false, 'unsupported' end
    local ok = pcall(function() return exports[provider]:SaveInventory(src) end)
    if not ok then return false, 'provider_error' end
    return true
end

return Save
