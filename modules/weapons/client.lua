-- client/weapons.lua — provider-aware current weapon + ammo reads.
-- ox_inventory is authoritative when started; otherwise QB weapon caches and
-- native fallbacks are used. Consumers get a normalized pack and can listen to
-- `concept_bridge:Client:OnWeaponUpdate`.
---@diagnostic disable: duplicate-set-field
Weapons = Weapons or {}

local UNARMED = `WEAPON_UNARMED`
local READ_TTL_MS = 50

local ReadCache = { at = 0, ped = 0, pack = nil }
local ImageUrlCache = {}
local HashIdentityCache = {}
local QbHashWeapons = nil
local CachedQbWeapon = nil

local GROUP_NAMES = {
    [`GROUP_MELEE`] = 'melee',
    [`GROUP_PISTOL`] = 'pistol',
    [`GROUP_STUNGUN`] = 'pistol',
    [`GROUP_SMG`] = 'smg',
    [`GROUP_RIFLE`] = 'rifle',
    [`GROUP_MG`] = 'mg',
    [`GROUP_SHOTGUN`] = 'shotgun',
    [`GROUP_SNIPER`] = 'sniper',
    [`GROUP_HEAVY`] = 'heavy',
    [`GROUP_THROWN`] = 'thrown',
    [`GROUP_PETROLCAN`] = 'item',
    [`GROUP_FIREEXTINGUISHER`] = 'item',
}

local function ResStarted(name)
    return GetResourceState(name) == 'started'
end

local function PrettyLabel(spawnName)
    local raw = tostring(spawnName or 'item')
    raw = raw:gsub('^WEAPON_', ''):gsub('^weapon_', ''):gsub('^prop_', '')
    raw = raw:gsub('_MK2$', ' Mk II'):gsub('_', ' ')
    return raw:gsub('(%a)([%w]*)', function(a, rest)
        return a:upper() .. rest:lower()
    end)
end

local function GroupName(hash)
    if not hash or hash == 0 then return 'item' end
    local ok, g = pcall(GetWeapontypeGroup, hash)
    if ok and g then
        return GROUP_NAMES[g] or 'item'
    end
    return 'item'
end

---@description Returns the name of the weapon data source in use.
---@return string
Weapons.GetResourceName = function()
    if ResStarted('ox_inventory') then return 'ox_inventory' end
    if ResStarted('qb-weapons') then return 'qb-weapons' end
    if ResStarted('qbx_core') then return 'qbx_core' end
    return 'default'
end

-- qb-core/qbx_core key Shared.Weapons by weapon NAME (entries carry .hash);
-- indexing by hash never matches, so every QB weapon degraded to the group-name
-- fallback label. Build a hash→entry map once.
local function BuildHashWeaponMap()
    local map = {}
    local shared = Framework and Framework.Shared
    if type(shared) == 'table' and type(shared.Weapons) == 'table' then
        for _, entry in pairs(shared.Weapons) do
            if type(entry) == 'table' and type(entry.hash) == 'number' and entry.hash ~= 0 then
                map[entry.hash] = entry
            end
        end
    end
    if not next(map) and ResStarted('qbx_core') then
        local ok, data = pcall(function()
            return exports.qbx_core:GetWeapons()
        end)
        if ok and type(data) == 'table' then
            for _, entry in pairs(data) do
                if type(entry) == 'table' and type(entry.hash) == 'number' and entry.hash ~= 0 then
                    map[entry.hash] = entry
                end
            end
        end
    end
    return map
end

local function QbHashWeaponMap()
    if QbHashWeapons then return QbHashWeapons end
    local map = BuildHashWeaponMap()
    -- Cache only when non-empty: an early call before qb-core initializes must
    -- not wedge the map empty forever.
    if next(map) then
        QbHashWeapons = map
        return map
    end
    return map
end

local function IdentityFromHash(hash)
    if not hash or hash == 0 then return nil, nil end
    local cached = HashIdentityCache[hash]
    if cached then
        return cached.name, cached.label
    end

    local w = QbHashWeaponMap()[hash]
    local name, label
    if type(w) == 'table' and (w.name or w.weapon) then
        name = tostring(w.name or w.weapon)
        label = w.label and tostring(w.label) or PrettyLabel(name)
    end

    if name then
        HashIdentityCache[hash] = { name = name, label = label or PrettyLabel(name) }
        return name, label
    end

    return nil, nil
end

local function ImageUrls(name)
    if not name or name == '' then return {} end
    local cached = ImageUrlCache[name]
    if cached then return cached end

    local lower = name:lower()
    local upper = name:upper()
    local keys = { lower, upper, name }
    if lower:sub(1, 7) == 'weapon_' then
        keys[#keys + 1] = lower:sub(8)
        keys[#keys + 1] = upper
    elseif upper:sub(1, 7) == 'WEAPON_' then
        keys[#keys + 1] = lower
    end

    local seenKey, uniq = {}, {}
    for i = 1, #keys do
        local key = keys[i]
        if key and key ~= '' and not seenKey[key] then
            seenKey[key] = true
            uniq[#uniq + 1] = key
        end
    end

    local specs = {}
    if ResStarted('qb-inventory') then
        specs[#specs + 1] = { 'qb-inventory', 'html/images/%s.png' }
    end
    if ResStarted('ox_inventory') then
        specs[#specs + 1] = { 'ox_inventory', 'web/images/%s.png' }
    end
    if ResStarted('ps-inventory') then
        specs[#specs + 1] = { 'ps-inventory', 'html/images/%s.png' }
    end
    if ResStarted('lj-inventory') then
        specs[#specs + 1] = { 'lj-inventory', 'html/images/%s.png' }
    end
    if ResStarted('qs-inventory') then
        specs[#specs + 1] = { 'qs-inventory', 'html/images/%s.png' }
    end

    local seenUrl, urls = {}, {}
    local function push(url)
        if #urls >= 8 then return end
        if url and url ~= '' and not seenUrl[url] then
            seenUrl[url] = true
            urls[#urls + 1] = url
        end
    end

    if Inventory and Inventory.GetImagePath then
        for i = 1, #uniq do
            local ok, path = pcall(Inventory.GetImagePath, uniq[i])
            if ok and type(path) == 'string' and path ~= '' and not path:find('avatars.githubusercontent', 1, true) then
                push(path)
                break
            end
        end
    end

    for s = 1, #specs do
        local res, fmt = specs[s][1], specs[s][2]
        for i = 1, #uniq do
            local rel = fmt:format(uniq[i])
            push(('https://cfx-nui-%s/%s'):format(res, rel))
            push(('nui://%s/%s'):format(res, rel))
            if #urls >= 8 then break end
        end
        if #urls >= 8 then break end
    end

    ImageUrlCache[name] = urls
    return urls
end

local function ReadOxAmmoCount(oxItem)
    if type(oxItem) ~= 'table' then return nil end
    local ammoName = oxItem.ammo
    if type(ammoName) ~= 'string' or ammoName == '' then return nil end
    if Inventory and Inventory.GetItemCount then
        local ok, count = pcall(Inventory.GetItemCount, ammoName)
        if ok and type(count) == 'number' then
            return math.max(0, math.floor(count + 0.5))
        end
    end
    return nil
end

local function ReadAmmo(ped, hash, oxItem)
    local group = GroupName(hash)
    if group == 'melee' or group == 'item' then
        return nil, nil
    end

    local clip, reserve

    if type(oxItem) == 'table' and type(oxItem.metadata) == 'table' then
        local meta = oxItem.metadata
        if type(meta.ammo) == 'number' then
            clip = math.floor(meta.ammo + 0.5)
        end
    end

    local oxReserve = ReadOxAmmoCount(oxItem)
    if oxReserve ~= nil then
        reserve = oxReserve
    end

    if hash and hash ~= 0 and ped and type(ped) == 'number' and DoesEntityExist(ped) then
        if clip == nil then
            local ok, inClip = pcall(GetAmmoInClip, ped, hash)
            if ok and type(inClip) == 'number' then
                clip = math.max(0, math.floor(inClip + 0.5))
            end
        end
        if reserve == nil then
            local okTotal, total = pcall(GetAmmoInPedWeapon, ped, hash)
            if okTotal and type(total) == 'number' then
                local t = math.max(0, math.floor(total + 0.5))
                local c = clip or 0
                reserve = math.max(0, t - c)
            end
        end
    end

    if clip == nil and reserve == nil then
        return nil, nil
    end
    return clip or 0, reserve or 0
end

local function PackHeld(name, label, hash, group, ped, oxItem)
    local urls = ImageUrls(name)
    local clip, reserve = ReadAmmo(ped or (cache and cache.ped) or PlayerPedId(), hash, oxItem)
    return {
        name = name,
        label = label or PrettyLabel(name),
        hash = hash,
        group = group or GroupName(hash),
        image = urls[1],
        images = urls,
        clip = clip,
        reserve = reserve,
    }
end

local function ReadOxCurrent(ped)
    if not ResStarted('ox_inventory') then
        return nil, false
    end
    local ok, current = pcall(function()
        return exports.ox_inventory:getCurrentWeapon()
    end)
    if ok and type(current) == 'table' and current.name then
        return PackHeld(current.name, current.label, current.hash, nil, ped, current), true
    end
    return nil, true
end

local function PackFromQbCache(ped, hash)
    local data = CachedQbWeapon
    if type(data) ~= 'table' or not data.name then return nil end
    local name = tostring(data.name)
    local label = data.label and tostring(data.label) or PrettyLabel(name)
    return PackHeld(name, label, hash, nil, ped)
end

local function ReadNativeWeaponInHand(ped)
    if type(ped) ~= 'number' or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end
    local okHash, hash = pcall(GetSelectedPedWeapon, ped)
    if not okHash or not hash or hash == 0 or hash == UNARMED then
        return nil
    end
    local okEnt, ent = pcall(GetCurrentPedWeaponEntityIndex, ped)
    if not okEnt or not ent or ent == 0 then
        return nil
    end
    local okArmed, armed = pcall(IsPedArmed, ped, 7)
    if not okArmed or not armed then
        return nil
    end

    local fromQb = PackFromQbCache(ped, hash)
    if fromQb then return fromQb end

    local name, label = IdentityFromHash(hash)
    if not name then
        name = ('weapon_%s'):format(GroupName(hash))
        label = PrettyLabel(GroupName(hash))
    end
    return PackHeld(name, label, hash, GroupName(hash), ped)
end

---@description Returns the currently held weapon as a normalized pack:
---{ name, label, hash, group, image, images, clip, reserve } or nil.
---@param ped number|nil
---@return table|nil
function Weapons.GetCurrentWeapon(ped)
    ped = ped or (cache and cache.ped) or PlayerPedId()
    if not ped or ped == 0 then return nil end

    local now = GetGameTimer()
    if ReadCache.ped == ped and (now - ReadCache.at) < READ_TTL_MS then
        return ReadCache.pack
    end

    local pack
    local oxHeld, oxRunning = ReadOxCurrent(ped)
    if oxHeld then
        pack = oxHeld
    elseif not oxRunning then
        pack = ReadNativeWeaponInHand(ped)
    end

    ReadCache.ped = ped
    ReadCache.at = now
    ReadCache.pack = pack
    return pack
end

---@description Clears the weapon read cache; optionally broadcasts the new value.
---@param notify boolean|nil
function Weapons.Invalidate(notify)
    ReadCache.at = 0
    if notify then
        TriggerEvent('concept_bridge:Client:OnWeaponUpdate', Weapons.GetCurrentWeapon())
    end
end

AddEventHandler('ox_inventory:currentWeapon', function()
    Weapons.Invalidate(true)
end)

AddEventHandler('ox_inventory:usedItem', function()
    Weapons.Invalidate(true)
end)

RegisterNetEvent('qb-weapons:client:SetCurrentWeapon', function(data, bool)
    if bool == false or type(data) ~= 'table' or not data.name then
        CachedQbWeapon = nil
    else
        CachedQbWeapon = data
    end
    Weapons.Invalidate(true)
end)

AddEventHandler('Bridge:Refresh', function(domain, _, _, owner)
    if owner ~= 'concept_bridge' or (domain ~= 'Framework' and domain ~= 'Inventory') then return end
    ReadCache = {at = 0, ped = 0, pack = nil}
    ImageUrlCache, HashIdentityCache, QbHashWeapons, CachedQbWeapon = {}, {}, nil, nil
    TriggerEvent('concept_bridge:Client:OnWeaponUpdate')
end)

return Weapons
