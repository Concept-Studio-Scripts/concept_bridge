---@diagnostic disable: duplicate-set-field
if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

Framework = Framework or {}

local cachedItemList = nil

---@description This is an internal function, its here to attempt to emulate qbs shared items mainly. This should not be used outside of bridge.
Framework.ItemList = function()
    if cachedItemList then return cachedItemList end
    local items = lib.callback.await('concept_bridge:Callback:GetFrameworkItems', false)
    cachedItemList = { Items = items.Items or {} }
    return cachedItemList
end

---@description This will get the name of the framework being used (if a supported framework).
---@return string
Framework.GetFrameworkName = function()
    --print("This is depricated, please use Framework.GetResourceName() instead.")
    return Framework.GetResourceName()
end

---@description This will get the name of the in use resource.
---@return string
Framework.GetResourceName = function()
    return 'es_extended'
end

---@description This will return true if the player is loaded, false otherwise.
---This could be useful in scripts that rely on player loaded events and offer a debug mode to hit this function.
---@return boolean
Framework.GetIsPlayerLoaded = function()
    return ESX.IsPlayerLoaded()
end

---@description This is an internal function, do not use this outside of bridge as there is no standard format between the frameworks.
--- @return table
-- PlayerData read through the ESX export is copied on every call: a copy is reused for a second, and kept
-- current in between by esx:setPlayerData (every ESX.SetPlayerData but the loadout), job and account events.
local playerCache, cachedAt = nil, 0

Framework.GetPlayerData = function()
    if playerCache and GetGameTimer() - cachedAt < 1000 then return playerCache end
    playerCache, cachedAt = ESX.GetPlayerData(), GetGameTimer()
    return playerCache
end

AddEventHandler('esx:setPlayerData', function(key, value)
    if playerCache and key ~= nil then playerCache[key] = value end
end)

---@description This will return a table of all the jobs in the framework.
---@return table
Framework.GetFrameworkJobs = function()
    local jobs = lib.callback.await('concept_bridge:Callback:GetFrameworkJobs', false)
    return jobs
end

---@description This will get the players birth date
---@return string
Framework.GetPlayerDob = function()
    local playerData = Framework.GetPlayerData()
    local dob = playerData.dateofbirth
    return dob
end

---@description This will return the players metadata for the specified metadata key.
---@param metadata table | string
---@return table | string | number | boolean
Framework.GetPlayerMetaData = function(metadata)
    return Framework.GetPlayerData().metadata[metadata]
end

---@description This will send a notification to the player.
---@param message string
---@param type string
---@param time number
---@return nil
Framework.Notify = function(message, type, time)
    return ESX.ShowNotification(message, type, time)
end

---@description Will Display the help text message on the screen
---@param message string
---@param _position unknown
---@return nil
Framework.ShowHelpText = function(message, _position)
    return exports.esx_textui:TextUI(message, "info")
end

---@description This will hide the help text message on the screen
---@return nil
Framework.HideHelpText = function()
    return exports.esx_textui:HideUI()
end

---@description This will get the players identifier (citizenid) etc.
---@return string
Framework.GetPlayerIdentifier = function()
    local playerData = Framework.GetPlayerData()
    return playerData.identifier
end

---@description This will get the players name (first and last).
---@return string
---@return string
Framework.GetPlayerName = function()
    local playerData = Framework.GetPlayerData()
    return playerData.firstName, playerData.lastName
end

---@description Depricated : This will return the players job name, job label, job grade label and job grade level
---@return string
---@return string
---@return string
---@return string
Framework.GetPlayerJob = function()
    --print("This is depricated, please use Framework.GetPlayerJobData() instead.")
    local jobData = Framework.GetPlayerJobData()
    return jobData.jobName, jobData.jobLabel, jobData.gradeName, jobData.gradeRank
end

--- @description This will return the players job name, job label, job grade label job grade level,
--- boss status, and duty status in a table
--- @return table
Framework.GetPlayerJobData = function()
    local playerData = Framework.GetPlayerData()
    local jobData = playerData.job
    local isBoss = (jobData.grade_name == "boss")
    return {
        jobName = jobData.name,
        jobLabel = jobData.label,
        gradeName = jobData.grade_name,
        gradeLabel = jobData.grade_label,
        gradeRank = jobData.grade,
        boss = isBoss,
        onDuty = jobData.onduty,
    }
end

-- esx_status is client-authoritative and updates asynchronously; cache its
-- ticks so GetHunger/GetThirst/GetStress return live values (playerData
-- variables go stale once esx_status:add fires).
local EsxStatusLive = {}
local EsxStatusGeneration = 0
local EsxStatusLoggedOut = false
local EsxStatusRunning = GetResourceState('esx_status') == 'started'

local function ResetEsxStatus()
    EsxStatusGeneration = EsxStatusGeneration + 1
    EsxStatusLive = {}
end

local function StatusPlayerReady()
    return not EsxStatusLoggedOut and ESX.IsPlayerLoaded()
end

local function StatusProviderReady()
    return EsxStatusRunning and GetResourceState('esx_status') == 'started'
end

local function ApplyEsxStatusList(statuses)
    if not StatusPlayerReady() or not StatusProviderReady() then return end
    if type(statuses) ~= 'table' then return end
    local changed = false
    for i = 1, #statuses do
        local entry = statuses[i]
        if type(entry) == 'table' and type(entry.name) == 'string' and type(entry.percent) == 'number' then
            local v = math.max(0, math.min(100, entry.percent + 0.0))
            if EsxStatusLive[entry.name] ~= v then
                EsxStatusLive[entry.name] = v
                changed = true
            end
        end
    end
    if changed then
        TriggerEvent('concept_bridge:Client:OnNeedsUpdate', {
            hunger = EsxStatusLive.hunger,
            thirst = EsxStatusLive.thirst,
            stress = EsxStatusLive.stress,
        })
    end
end

AddEventHandler('esx_status:onTick', ApplyEsxStatusList)
AddEventHandler('esx_status:loaded', ResetEsxStatus)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= 'esx_status' then return end
    EsxStatusRunning = false
    ResetEsxStatus()
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'esx_status' then return end
    EsxStatusRunning = true
    ResetEsxStatus()
end)

---@param name string
---@return number|nil
local function RefreshEsxStatus(name)
    if not StatusPlayerReady() or not StatusProviderReady() then return nil end
    local generation = EsxStatusGeneration
    pcall(function()
        TriggerEvent('esx_status:getStatus', name, function(status)
            if generation ~= EsxStatusGeneration or not StatusPlayerReady() or not StatusProviderReady() then return end
            if type(status) ~= 'table' then return end
            local ok, percent = pcall(function()
                if type(status.getPercent) == 'function' then return status.getPercent() end
                if type(status.val) == 'number' then return (status.val / 1000000.0) * 100.0 end
            end)
            -- A provider callback (including getPercent) may finish after a
            -- character switch or status-resource restart.
            if generation ~= EsxStatusGeneration or not StatusPlayerReady() or not StatusProviderReady() then return end
            if ok and type(percent) == 'number' then
                EsxStatusLive[name] = math.max(0, math.min(100, percent + 0.0))
            end
        end)
    end)
    return EsxStatusLive[name]
end

---@description This is an internal function to get status data
--- @param search string
Framework.GetStatusData = function(search)
    if type(search) ~= 'string' or not StatusPlayerReady() then return 0 end
    local generation = EsxStatusGeneration
    if StatusProviderReady() and EsxStatusLive[search] == nil then
        RefreshEsxStatus(search)
    end
    if generation ~= EsxStatusGeneration or not StatusPlayerReady() then return 0 end
    if StatusProviderReady() and EsxStatusLive[search] ~= nil then
        return EsxStatusLive[search]
    end
    local playerData = Framework.GetPlayerData()
    if not playerData or type(playerData.variables) ~= 'table' then return 0 end
    local status = playerData.variables.status
    if type(status) ~= 'table' then return 0 end
    for _, entry in ipairs(status) do
        if type(entry) == 'table' and entry.name == search then
            return entry.percent or 0
        end
    end
    return 0
end

---@description This will get the hunger of a player
---@return number
Framework.GetHunger = function()
    local status = Framework.GetStatusData("hunger")
    return math.floor((status) + 0.5) or 0
end

---@description This will get the thirst of a player
---@return number
Framework.GetThirst = function()
    local status = Framework.GetStatusData("thirst")
    return math.floor((status) + 0.5) or 0
end

---@description This will get the stress of a player (0-100)
---@return number
Framework.GetStress = function()
    local status = Framework.GetStatusData("stress")
    return math.floor((status) + 0.5) or 0
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Framework.HasItem = function(item, requiredCount)
    local hasItem = ESX.SearchInventory(item, true)
    return (tonumber(hasItem) or 0) >= (requiredCount or 1)
end

---@description This is an internal function used as a fallback, please use the Inventory.GetItemCount instead.
--- @param item string
--- @return number
Framework.GetItemCount = function(item)
    if not item then return 0 end
    -- ESX.SearchInventory is authoritative; do NOT index inventory[item] (array-backed)
    local ok, count = pcall(ESX.SearchInventory, item, true)
    if ok and type(count) == 'number' then return count end
    local inventory = Framework.GetPlayerInventory()
    if type(inventory) ~= 'table' then return 0 end
    local total = 0
    for _, entry in pairs(inventory) do
        if type(entry) == 'table' and entry.name == item then
            total = total + (tonumber(entry.count) or 0)
        end
    end
    return total
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Framework.GetItemInfo = function(item)
    if not item then return {} end
    local list = Framework.ItemList()
    local items = list and (list.Items or list) or {}
    local info = items[item]
    if type(info) ~= 'table' then return {} end
    return {
        name = item,
        label = info.label or item,
        stack = info.stack ~= false,
        weight = info.weight or 0,
        description = info.description or '',
        image = info.image,
    }
end

---@description This is an internal function used as a fallback, please use the Inventory.GetPlayerInventory instead.
--- @return table {name, label, count, slot, metadata, stack, close, weight}
Framework.GetPlayerInventory = function()
    local playerData = Framework.GetPlayerData()
    if not playerData or type(playerData.inventory) ~= 'table' then return {} end
    local repack = {}
    for _, v in pairs(playerData.inventory) do
        if type(v) == 'table' and v.name and (tonumber(v.count) or 0) > 0 then
            repack[#repack + 1] = {
                name = v.name,
                label = v.label or v.name,
                count = tonumber(v.count) or 0,
                slot = 0,
                metadata = {},
                stack = true,
                close = v.usable or false,
                weight = v.weight or 0,
            }
        end
    end
    return repack
end

---@description This will return the players money by type, I recommend not useing this as its the client and not secure or to be trusted.
---Use case is for a ui or a menu I guess.
---@param _type string
---@return number
Framework.GetAccountBalance = function(_type)
    local player = Framework.GetPlayerData()
    if not player then return 0 end
    local accounts = player.accounts
    if _type == 'cash' then _type = 'money' end
    for _, account in ipairs(accounts) do
        if account.name == _type then
            if not account.money or account.money <= 0 then return 0 end
            return account.money or 0
        end
    end
    return 0
end

--- @description This will get a players dead status
--- @return boolean
Framework.GetIsPlayerDead = function()
    local playerData = Framework.GetPlayerData()
    return playerData.dead
end

---@description Is the local player down: dead OR in last stand (this framework has no last stand: down is dead).
---@return boolean
Framework.GetIsPlayerDown = function()
    return lib.require('@concept_bridge.lib.framework.shared.player_down').FromFlag(Framework.GetIsPlayerDead())
end

---@description Event handler for when player is loaded in ESX framework
---@param xPlayer table
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerCache, cachedAt = type(xPlayer) == 'table' and xPlayer or nil, GetGameTimer()
    EsxStatusLoggedOut = false
    ResetEsxStatus()
    Wait(1500)
    TriggerEvent('concept_bridge:Client:OnPlayerLoaded')
end)

---@description Event handler for when player logs out in ESX framework
RegisterNetEvent('esx:onPlayerLogout', function()
    playerCache = nil
    EsxStatusLoggedOut = true
    ResetEsxStatus()
    TriggerEvent('concept_bridge:Client:OnPlayerUnload')
end)

---@description Event handler for when player job is updated in ESX framework
---@param data table Job data containing name, label, grade_label, and grade
RegisterNetEvent('esx:setJob', function(data)
    if playerCache and type(data) == 'table' then playerCache.job = data end
    TriggerEvent('concept_bridge:Client:OnPlayerJobUpdate', data.name, data.label, data.grade_label, data.grade)
end)

---@description Event handler for when an ESX account balance changes (ATM,
---shops, society pay, admin commands). Forwards as the shared account hint so
---consumers (concept_hud bank) refresh immediately instead of waiting for
---their poll cadence. The payload carries no balance; consumers re-read it.
---@param account table Account table containing name ('bank', 'money', ...) and money
RegisterNetEvent('esx:setAccountMoney', function(account)
    local name = type(account) == 'table' and account.name or nil
    if playerCache and name and type(playerCache.accounts) == 'table' then
        for _, entry in pairs(playerCache.accounts) do
            if entry.name == name then entry.money = account.money end
        end
    end
    TriggerEvent('concept_bridge:Client:OnAccountUpdate', { account = name })
end)

return Framework
