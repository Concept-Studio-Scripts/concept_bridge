---@diagnostic disable: duplicate-set-field
if GetResourceState('ox_core') ~= 'started' then return end

Framework = Framework or {}

local Ox = require '@ox_core.lib.init'

local UNEMPLOYED = {
    name = 'unemployed',
    label = 'Unemployed',
    grade = { name = '0', level = 0 },
    isboss = false,
    onduty = false,
}

local function getPlayerObject()
    return Ox.GetPlayer(cache.playerId)
end

-- ox_core always returns a player object; it carries a charId only while a character is loaded.
local function characterLoaded()
    local ok, player = pcall(getPlayerObject)
    return ok and type(player) == 'table' and player.charId ~= nil
end

-- qb-style scripts read isLoggedIn: it follows the character, not just the bridge starting.
LocalPlayer.state.isLoggedIn = characterLoaded()

--- Job definitions keyed by group name (parity with qbx_core). Definitions are
--- read from replicated GlobalState, so this never yields.
---@return table
local function getFrameworkJobs()
    local map = {}
    local names = GlobalState.groups
    if type(names) ~= 'table' then return map end
    for i = 1, #names do
        local name = names[i]
        local def = Ox.GetGroup and Ox.GetGroup(name) or nil
        if type(def) ~= 'table' or def.type == nil or def.type == 'job' then
            map[name] = def or { name = name, label = name }
        end
    end
    return map
end

--- Grade label from the group definition's `grades` map.
---@param jobDef table|nil
---@param grade number|string
---@return string
local function gradeLabel(jobDef, grade)
    local grades = type(jobDef) == 'table' and jobDef.grades or nil
    if type(grades) == 'table' then
        local label = grades[grade] or grades[tostring(grade)]
        if label ~= nil then return tostring(label) end
    end
    return tostring(grade)
end

--- ox group grades map to account roles (owner/manager/...). Management roles
--- count as "boss" so HUD boss checks match qb-core/qbx_core.
---@param jobDef table|nil
---@param grade number|string
---@return boolean
local function gradeIsBoss(jobDef, grade)
    local roles = type(jobDef) == 'table' and jobDef.accountRoles or nil
    if type(roles) ~= 'table' then return false end
    local role = roles[grade] or roles[tostring(grade)]
    return role == 'owner' or role == 'manager'
end

--- Prefer the active group (ox_core's primary job) over arbitrary pairs order.
---@param player table|nil
---@return table
local function buildGroupData(player)
    if not player then return UNEMPLOYED end

    local groups = (type(player.getGroups) == 'function' and player.getGroups()) or {}
    local activeGroup = type(player.get) == 'function' and player.get('activeGroup') or nil

    local primaryName, primaryGrade
    if activeGroup and groups[activeGroup] then
        primaryName, primaryGrade = activeGroup, groups[activeGroup]
    else
        for groupName, grade in pairs(groups) do
            primaryName, primaryGrade = groupName, grade
            break
        end
    end
    if not primaryName then return UNEMPLOYED end

    local jobDef = Ox.GetGroup and Ox.GetGroup(primaryName) or nil
    return {
        name = primaryName,
        label = (type(jobDef) == 'table' and jobDef.label) or primaryName,
        grade = { name = gradeLabel(jobDef, primaryGrade), level = primaryGrade },
        isboss = gradeIsBoss(jobDef, primaryGrade),
        onduty = activeGroup == primaryName,
    }
end

local function oxInventoryStarted()
    return GetResourceState('ox_inventory') == 'started'
end

--- ox_inventory item definitions (empty when the inventory is unavailable).
--- Framework item APIs are ox_inventory-backed; other inventories stay behind
--- Bridge.Inventory.
---@return table
local function oxItems()
    if not oxInventoryStarted() then return {} end
    local ok, items = pcall(function()
        return exports.ox_inventory:Items()
    end)
    if ok and type(items) == 'table' then return items end
    return {}
end

---@description This will get the name of the framework being used (if a supported framework).
---@return string
Framework.GetFrameworkName = function()
    print("This is deprecated, please use Framework.GetResourceName() instead.")
    return Framework.GetResourceName()
end

---@description This will get the name of the in use resource.
---@return string
Framework.GetResourceName = function()
    return 'ox_core'
end

---@description This will return true if the player is loaded, false otherwise.
---ox exposes the player object only once a character exists, so this is the
---authoritative readiness signal (the isLoggedIn state is set at load).
---@return boolean
Framework.GetIsPlayerLoaded = function()
    return characterLoaded()
end

---@description Returns the raw OxPlayer object. Internal use, avoid outside of bridge.
---@return table
Framework.GetPlayerObject = function()
    return getPlayerObject()
end

---@description Returns the raw OxPlayer object (framework format, not standardised).
---This is mainly for internal bridge use and should be avoided.
---@return table
Framework.GetPlayerData = function()
    return getPlayerObject()
end

---@description Returns job definitions keyed by group name.
---@return table
Framework.GetFrameworkJobs = getFrameworkJobs

---@description This will get the players birth date
---@return string|nil
Framework.GetPlayerDob = function()
    local player = getPlayerObject()
    if not player or type(player.get) ~= 'function' then return nil end
    return player.get('dateOfBirth')
end

---@description This will return the players metadata for the specified metadata key.
---@param metadata table | string
---@return table | string | number | boolean | nil
Framework.GetPlayerMetaData = function(metadata)
    local player = getPlayerObject()
    if not player or type(player.get) ~= 'function' then return nil end
    return player.get(metadata)
end

---@description This will return the account balance for the requested type.
---'bank' reads the character account; cash and other types read ox_inventory items.
---Returns nil until a character is loaded so consumers don't flash $0.
---@param _type string
---@return number|nil
Framework.GetAccountBalance = function(_type)
    if not getPlayerObject() then return nil end
    local balance = lib.callback.await('concept_bridge:Callback:GetAccountBalance', false, _type)
    if type(balance) == 'number' then return balance end
    return nil
end

---@description This will get the hunger of a player (HUD “remaining”: 100 = full).
--- ox_core stores deprivation (0 = full, 100 = starving) via getStatus — not metadata.
---@return number
Framework.GetHunger = function()
    local player = getPlayerObject()
    if not player or type(player.getStatus) ~= 'function' then return 0 end
    local raw = player.getStatus('hunger') or 0
    return math.floor((100 - raw) + 0.5)
end

---@description This will get the thirst of a player (HUD “remaining”: 100 = full).
---@return number
Framework.GetThirst = function()
    local player = getPlayerObject()
    if not player or type(player.getStatus) ~= 'function' then return 0 end
    local raw = player.getStatus('thirst') or 0
    return math.floor((100 - raw) + 0.5)
end

---@description This will get the stress of a player (0-100). ox stores stress as a status.
---@return number
Framework.GetStress = function()
    local player = getPlayerObject()
    if not player then return 0 end
    if type(player.getStatus) == 'function' then
        local ok, raw = pcall(function() return player.getStatus('stress') end)
        if ok and type(raw) == 'number' then return math.floor(raw + 0.5) end
    end
    if type(player.getStatuses) == 'function' then
        local ok, statuses = pcall(function() return player.getStatuses() end)
        if ok and type(statuses) == 'table' and type(statuses.stress) == 'number' then
            return math.floor(statuses.stress + 0.5)
        end
    end
    return 0
end

---@description This will get the players identifier (charId, falling back to userId).
---@return string|nil
Framework.GetPlayerIdentifier = function()
    local player = getPlayerObject()
    if not player then return nil end
    local identifier = player.charId or player.userId
    if identifier == nil then return nil end
    return tostring(identifier)
end

---@description This will get the players name (first and last).
---@return string|nil
---@return string|nil
Framework.GetPlayerName = function()
    local player = getPlayerObject()
    if not player or type(player.get) ~= 'function' then return nil, nil end
    local first = player.get('firstName') or player.get('firstname')
    local last = player.get('lastName') or player.get('lastname')
    return first, last
end

---@description This will send a notification to the player.
---@param message string
---@param nType string|nil
---@param time number|nil
Framework.Notify = function(message, nType, time)
    if not lib or not lib.notify then return end
    return lib.notify({
        title = 'Notification',
        description = message,
        type = nType,
        duration = time,
    })
end

---@description Will display the help text message on the screen.
---@param message string
---@param position string|nil
Framework.ShowHelpText = function(message, position)
    if not exports.ox_lib then return end
    return exports.ox_lib:showTextUI(message, { position = position or 'top-center' })
end

---@description This will hide the help text message on the screen.
Framework.HideHelpText = function()
    if not exports.ox_lib then return end
    return exports.ox_lib:hideTextUI()
end

---@deprecated Deprecated: This will return the players job name, job label, job grade label and job grade level
---@return string
---@return string
---@return string
---@return string
Framework.GetPlayerJob = function()
    local jobData = Framework.GetPlayerJobData()
    if not jobData then
        ---@diagnostic disable-next-line: missing-return-value
        return
    end
    return jobData.jobName, jobData.jobLabel, jobData.gradeName, jobData.gradeRank
end

---@description This will return the players job name, job label, job grade label job grade level, boss status, and duty status in a table
---@return table|nil
Framework.GetPlayerJobData = function()
    local playerData = Framework.GetPlayerData()
    if not playerData then return nil end
    local jobData = buildGroupData(playerData)
    return {
        jobName = jobData.name,
        jobLabel = jobData.label,
        gradeName = jobData.grade.name,
        gradeLabel = jobData.grade.name,
        gradeRank = jobData.grade.level,
        boss = jobData.isboss,
        onDuty = jobData.onduty,
    }
end

---@description This will get a players dead status
---@return boolean
Framework.GetIsPlayerDead = function()
    local playerData = Framework.GetPlayerData()
    if not playerData or type(playerData.get) ~= 'function' then return false end
    return playerData.get('isDead') or false
end

---@description Is the local player down: dead OR in last stand (this framework has no last stand: down is dead).
---@return boolean
Framework.GetIsPlayerDown = function()
    return lib.require('@concept_bridge.lib.framework.shared.player_down').FromFlag(Framework.GetIsPlayerDead())
end

---@description This will return their count of the item in the players inventory.
---@param item string
---@return number
Framework.GetItemCount = function(item)
    if not oxInventoryStarted() then return 0 end
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(item, nil, false)
    end)
    if ok and type(count) == 'number' then return count end
    return 0
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number|nil
---@return boolean
Framework.HasItem = function(item, requiredCount)
    return Framework.GetItemCount(item) >= (requiredCount or 1)
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Framework.GetItemInfo = function(item)
    local data = oxItems()[item]
    if type(data) ~= 'table' then return {} end
    return {
        name = data.name or item,
        label = data.label or item,
        stack = data.stack ~= false,
        weight = data.weight or 0,
        description = data.description,
        image = data.client and data.client.image or nil,
    }
end

---@description This will return the players inventory.
---@return table
Framework.GetPlayerInventory = function()
    if not oxInventoryStarted() then return {} end
    local ok, items = pcall(function()
        return exports.ox_inventory:GetPlayerItems()
    end)
    if ok and type(items) == 'table' then return items end
    ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems()
    end)
    if ok and type(items) == 'table' then return items end
    return {}
end

---@description Alternate item list accessor used by the default Inventory module.
---@return table
Framework.ItemList = function()
    return { Items = oxItems() }
end

---@description This will return the vehicle properties for the specified vehicle.
---@param vehicle number
---@return table
Framework.GetVehicleProperties = function(vehicle)
    local ok, props = pcall(lib.getVehicleProperties, vehicle)
    if ok and type(props) == 'table' then return props end
    return {}
end

---@description This will set the vehicle properties for the specified vehicle.
---@param vehicle number
---@param properties table
---@return boolean
Framework.SetVehicleProperties = function(vehicle, properties)
    if type(properties) ~= 'table' then return false end
    local ok, result = pcall(lib.setVehicleProperties, vehicle, properties)
    return ok and result ~= false
end

---@description Event handler for when player is loaded in ox_core framework
AddEventHandler('ox:playerLoaded', function(playerId, isNew)
    LocalPlayer.state.isLoggedIn = true
    Wait(1500)
    TriggerEvent('concept_bridge:Client:OnPlayerLoaded')
end)

---@description Event handler for when player logs out (returns to character select)
AddEventHandler('ox:playerLogout', function()
    LocalPlayer.state.isLoggedIn = false
    TriggerEvent('concept_bridge:Client:OnPlayerUnload')
end)

---@description Entering character select is also an unload for consumers:
---ox_core fires this when swapping characters, not just on full logout.
AddEventHandler('ox:startCharacterSelect', function()
    LocalPlayer.state.isLoggedIn = false
    TriggerEvent('concept_bridge:Client:OnPlayerUnload')
end)

---@description Event handler for when player group is updated in ox_core framework
RegisterNetEvent('ox:setGroup', function(groupName, grade)
    local playerData = Framework.GetPlayerData()
    local jobData = buildGroupData(playerData)
    TriggerEvent('concept_bridge:Client:OnPlayerJobUpdate', jobData.name, jobData.label, jobData.grade.name,
        jobData.grade.level)
end)

return Framework
