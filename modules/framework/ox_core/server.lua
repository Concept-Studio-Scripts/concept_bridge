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

local function oxInventoryStarted()
    return GetResourceState('ox_inventory') == 'started'
end

--- ox_inventory item definitions (empty when the inventory is unavailable).
---@return table
local function oxItems()
    if not oxInventoryStarted() then return {} end
    local ok, items = pcall(function()
        return exports.ox_inventory:Items()
    end)
    if ok and type(items) == 'table' then return items end
    return {}
end

--- Job definitions keyed by group name (parity with qbx_core).
---@return table
local function getFrameworkJobs()
    local map = {}
    local names = Ox.GetGroupsByType and Ox.GetGroupsByType('job') or {}
    for i = 1, #names do
        local name = names[i]
        local def = Ox.GetGroup and Ox.GetGroup(name) or nil
        map[name] = def or { name = name, label = name }
    end
    return map
end

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

--- Returns the character's default account (bank). Falls back to the charId
--- lookup used by older ox_core builds.
---@param player table|nil
---@return table|nil
local function getCharacterAccount(player)
    if not player then return nil end
    if type(player.getAccount) == 'function' then
        local ok, account = pcall(function() return player.getAccount() end)
        if ok and type(account) == 'table' then return account end
    end
    if player.charId and type(Ox.GetCharacterAccount) == 'function' then
        local ok, account = pcall(Ox.GetCharacterAccount, player.charId)
        if ok and type(account) == 'table' then return account end
    end
    return nil
end

-- Online character default accounts (bank), used to route ox_core account
-- events to the owning client. Personal accounts only; group/society accounts
-- are not tracked. A missed mapping only costs latency (consumers still poll).
local AccountSource = {}
local SourceAccount = {}

---@param src number
---@param accountId any
local function NoteAccountId(src, accountId)
    if not src or accountId == nil then return end
    local key = tostring(accountId)
    local previous = SourceAccount[src]
    if previous and previous ~= key and AccountSource[previous] == src then
        AccountSource[previous] = nil
    end
    AccountSource[key] = src
    SourceAccount[src] = key
end

---@param src number
---@param account table|nil
local function NoteAccount(src, account)
    if type(account) ~= 'table' then return end
    NoteAccountId(src, account.accountId)
end

---@param src number
local function TrackPlayerAccount(src)
    NoteAccount(src, getCharacterAccount(Framework.GetPlayer(src)))
end

---@param src number
local function UntrackPlayerAccount(src)
    local accountId = SourceAccount[src]
    if accountId == nil then return end
    SourceAccount[src] = nil
    if AccountSource[accountId] == src then AccountSource[accountId] = nil end
end

---@param accountId any
---@param action string
---@param amount number|nil
local function NotifyAccount(accountId, action, amount)
    local src = accountId ~= nil and AccountSource[tostring(accountId)] or nil
    if not src then return end
    TriggerClientEvent('concept_bridge:Client:OnAccountUpdate', src, {
        account = 'bank',
        action = action,
        amount = amount,
    })
end

---@param account table|nil
---@return number|nil
local function accountBalance(account)
    if type(account) ~= 'table' then return nil end
    if type(account.get) == 'function' then
        local ok, balance = pcall(function() return account.get('balance') end)
        if ok then
            local n = tonumber(balance)
            if n then return math.floor(n + 0.5) end
        end
    end
    local n = tonumber(account.balance)
    if n then return math.floor(n + 0.5) end
    return nil
end

--- ox_core stores cash as the ox_inventory `money` item; the character account
--- is the bank. Any other type is treated as an inventory item name.
---@param _type string|nil
---@return string kind, string|nil item
local function resolveMoneyKind(_type)
    if _type == 'bank' then return 'bank', nil end
    if _type == nil or _type == '' or _type == 'money' or _type == 'cash' then return 'cash', 'money' end
    return 'item', tostring(_type)
end

---@description This will return the name of the framework in use.
---@return string
Framework.GetFrameworkName = function()
    print("[Concept Bridge] Warning: Framework.GetFrameworkName is deprecated, use Framework.GetResourceName instead.")
    return Framework.GetResourceName()
end

---@description This will get the name of the in use resource.
---@return string
Framework.GetResourceName = function()
    return 'ox_core'
end

---@description This will return if the player is an admin in the framework.
---@param src any
---@return boolean
Framework.GetIsFrameworkAdmin = function(src)
    if not src then return false end
    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'group.admin') then return true end
    local player = Framework.GetPlayer(src)
    if not player or type(player.getGroupByType) ~= 'function' then return false end
    local ok, groupName = pcall(function() return player.getGroupByType('admin') end)
    return ok and groupName ~= nil or false
end

---@description This will return the citizen ID of the player (charId).
---@param src number
---@return string | nil
Framework.GetPlayerIdentifier = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return end
    if player.charId == nil then return end
    return tostring(player.charId)
end

---@description Returns the player data of the specified source in the framework defualt format.
---@param src any
---@return table | nil
Framework.GetPlayer = function(src)
    local player = Ox.GetPlayer(src)
    if not player then return end
    return player
end

---@description Returns the player data of the specified identifier in the framework default format.
---@param citizenid string
---@return table | nil
Framework.GetPlayerByIdentifier = function(citizenid)
    local id = tonumber(citizenid) or citizenid
    ---GetPlayerIdentifier returns charId — prefer char lookup.
    if Ox.GetPlayerFromCharId then
        local player = Ox.GetPlayerFromCharId(tonumber(id) or id)
        if player then return Framework.GetPlayer(player.source) end
    end
    local player = Ox.GetPlayerByUserId(tonumber(id))
    if not player then return end
    return Framework.GetPlayer(player.source)
end

---@description This will return the player source of the specified citizen ID.
---@param citizenid string
---@return number | nil
Framework.GetPlayerSource = function(citizenid)
    local id = tonumber(citizenid) or citizenid
    if Ox.GetPlayerFromCharId then
        local player = Ox.GetPlayerFromCharId(tonumber(id) or id)
        if player then return player.source end
    end
    local player = Ox.GetPlayerByUserId(tonumber(id))
    if not player then return end
    return player.source
end

---@description Returns a table of the jobs in the framework, keyed by group name.
---@return table
Framework.GetFrameworkJobs = getFrameworkJobs

---@description This will return a table of all logged in player sources
---@return table
Framework.GetPlayers = function()
    local players = Ox.GetPlayers() or {}
    local sources = {}
    for i = 1, #players do
        local src = players[i].source
        if src then sources[#sources + 1] = src end
    end
    return sources
end

---@description Returns the first and last name of the player.
---@param src number
---@return string | nil
---@return string | nil
Framework.GetPlayerName = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return end
    -- ox_core stores RP name via player.get('firstName')/('lastName'); handle case variants and direct props
    local first = player.get('firstName') or player.get('firstname') or player.get('FirstName') or player.firstName or
    player.firstname
    local last  = player.get('lastName') or player.get('lastname') or player.get('LastName') or player.lastName or
    player.lastname
    if type(first) ~= 'string' or first == '' then first = nil end
    if type(last) ~= 'string' then last = nil end
    return first, last
end

---@description Returns the player date of birth.
---@param src number
---@return string | nil
Framework.GetPlayerDob = function(src)
    local player = Framework.GetPlayer(src)
    if not player or type(player.get) ~= 'function' then return end
    return player.get('dateOfBirth')
end

---@description Adds the specified metadata key and value to the player's data.
---Stress is special-cased to ox_core's status store (the canonical source).
---@param src number
---@param metadata string
---@param value any
---@return boolean | nil
Framework.SetPlayerMetadata = function(src, metadata, value)
    local player = Framework.GetPlayer(src)
    if not player then return end
    if metadata == 'stress' and type(player.setStatus) == 'function' then
        local ok = pcall(function()
            player.setStatus('stress', lib.math.clamp(tonumber(value) or 0, 0, 100))
        end)
        return ok
    end
    if type(player.set) == 'function' then
        return player.set(metadata, value, true)
    end
    return nil
end

---@description Gets the specified metadata key to the player's data.
---Stress is special-cased to ox_core's status store (the canonical source).
---@param src number
---@param metadata string
---@return any | nil
Framework.GetPlayerMetadata = function(src, metadata)
    local player = Framework.GetPlayer(src)
    if not player then return end
    if metadata == 'stress' and type(player.getStatus) == 'function' then
        local ok, raw = pcall(function() return player.getStatus('stress') end)
        if ok and type(raw) == 'number' then return raw end
    end
    return player.get(metadata) or false
end

---@description Returns the player's stress (0-100). ox_core stores stress as a status.
---@param src number
---@return number
Framework.GetStress = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return 0 end
    local raw = (type(player.getStatus) == 'function' and player.getStatus('stress')) or 0
    return math.floor((tonumber(raw) or 0) + 0.5)
end

---@description Adds the specified value to the player's stress level and updates the client HUD.
---@param src number
---@param value number
---@return number | nil
Framework.AddStress = function(src, value)
    local player = Framework.GetPlayer(src)
    if not player then return end
    local currentStress = (type(player.getStatus) == 'function' and player.getStatus('stress')) or 0
    local newStress = lib.math.clamp((tonumber(currentStress) or 0) + (tonumber(value) or 0), 0, 100)
    if type(player.setStatus) == 'function' then
        player.setStatus('stress', newStress)
    end
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    return newStress
end

---@description Removes the specified value from the player's stress level and updates the client HUD.
---@param src number
---@param value number
---@return number | nil
Framework.RemoveStress = function(src, value)
    local player = Framework.GetPlayer(src)
    if not player then return end
    local currentStress = (type(player.getStatus) == 'function' and player.getStatus('stress')) or 0
    local newStress = lib.math.clamp((tonumber(currentStress) or 0) - (tonumber(value) or 0), 0, 100)
    if type(player.setStatus) == 'function' then
        player.setStatus('stress', newStress)
    end
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    return newStress
end

---@description Adds to hunger “remaining” (ESX-style). ox status is deprivation — removeStatus.
---@param src number
---@param value number
---@return number | nil
Framework.AddHunger = function(src, value)
    local player = Framework.GetPlayer(src)
    if not player then return end
    value = tonumber(value) or 0
    if type(player.removeStatus) == 'function' and value > 0 then
        player.removeStatus('hunger', value)
    elseif type(player.addStatus) == 'function' and value < 0 then
        player.addStatus('hunger', -value)
    end
    local raw = (type(player.getStatus) == 'function' and player.getStatus('hunger')) or 0
    return math.floor((100 - raw) + 0.5)
end

---@description Adds to thirst “remaining” (ESX-style).
---@param src number
---@param value number
---@return number | nil
Framework.AddThirst = function(src, value)
    local player = Framework.GetPlayer(src)
    if not player then return end
    value = tonumber(value) or 0
    if type(player.removeStatus) == 'function' and value > 0 then
        player.removeStatus('thirst', value)
    elseif type(player.addStatus) == 'function' and value < 0 then
        player.addStatus('thirst', -value)
    end
    local raw = (type(player.getStatus) == 'function' and player.getStatus('thirst')) or 0
    return math.floor((100 - raw) + 0.5)
end

---@description Hunger remaining for HUD (100 = full). ox getStatus is deprivation.
---@param src number
---@return number | nil
Framework.GetHunger = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return 0 end
    local raw = (type(player.getStatus) == 'function' and player.getStatus('hunger')) or 0
    return math.floor((100 - raw) + 0.5)
end

---@description This will return a boolean if the player is dead or in last stand.
---@param src number
---@return boolean|nil
Framework.GetIsPlayerDead = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return false end
    return player.getStatus('dead') or player.get('dead') or false
end

---@description This will revive a player, if the player is dead or in last stand.
---@param src number
---@return boolean
Framework.RevivePlayer = function(src)
    local srcId = tonumber(src)
    if not srcId then return false end
    local player = Framework.GetPlayer(srcId)
    if player then
        player.setStatus('dead', false)
        player.set('dead', false)
    end
    TriggerClientEvent('hospital:client:Revive', srcId)
    return true
end

---@description Thirst remaining for HUD (100 = full).
---@param src number
---@return number| nil
Framework.GetThirst = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return 0 end
    local raw = (type(player.getStatus) == 'function' and player.getStatus('thirst')) or 0
    return math.floor((100 - raw) + 0.5)
end

---@description Returns the phone number of the player.
---@param src number
---@return string | nil
Framework.GetPlayerPhone = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return end
    return player.get('phoneNumber') or player.get('phone') or nil
end

---@description Returns the gang name of the player.
---@param src number
---@return string | nil
Framework.GetPlayerGang = function(src)
    local player = Framework.GetPlayer(src)
    if not player then return end
    local name = player.getGroupByType and player.getGroupByType('gang') or nil
    return name or 'none'
end

---@description This will get a table of player sources that have the specified job name.
---@param job string
---@return table
Framework.GetPlayersByJob = function(job)
    return Framework.GetPlayerSourcesByJob(job) or {}
end

---@deprecated Deprecated: Returns the job name, label, grade name, and grade level of the player.
---@param src number
---@return string | string | string | number | nil
---@return string | string | string | number | nil
---@return string | string | string | number | nil
---@return string | string | string | number | nil
Framework.GetPlayerJob = function(src)
    --print("[Concept Bridge] Warning: Framework.GetPlayerJob is deprecated, use Framework.GetPlayerJobData instead.")
    local jobData = Framework.GetPlayerJobData(src)
    if not jobData then
        ---@diagnostic disable-next-line: missing-return-value
        return
    end
    return jobData.jobName, jobData.jobLabel, jobData.gradeName, jobData.gradeRank
end

---@description This will return the players job name, job label, job grade label job grade level, boss status,
---and duty status in a table
---@param src number
---@return table | nil
Framework.GetPlayerJobData = function(src)
    local playerData = Framework.GetPlayer(src)
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

---@description Sets the player's job to the specified name and grade.
---@param src number
---@param name string
---@param grade string|number
---@return boolean | nil
Framework.SetPlayerJob = function(src, name, grade)
    local player = Framework.GetPlayer(src)
    if not player then return end
    grade = tonumber(grade) or 0
    if type(player.setGroup) == 'function' then
        return player.setGroup(name, grade)
    end
    return nil
end

---@description This will toggle the duty status of the player (active group).
---@param src number
---@param status boolean
Framework.SetPlayerDuty = function(src, status)
    local player = Framework.GetPlayer(src)
    if not player or type(player.setActiveGroup) ~= 'function' then return nil end
    if status == true then
        local groups = (type(player.getGroups) == 'function' and player.getGroups()) or {}
        local active = type(player.get) == 'function' and player.get('activeGroup') or nil
        if active and groups[active] then return true end
        for groupName in pairs(groups) do
            local ok = pcall(function() return player.setActiveGroup(groupName) end)
            return ok and true or false
        end
        return false
    end
    local ok = pcall(function() return player.setActiveGroup(nil) end)
    return ok and true or false
end

---@description Returns the players duty status (active group set).
---@param src number
---@return boolean | nil
Framework.GetPlayerDuty = function(src)
    local player = Framework.GetPlayer(src)
    if not player or type(player.get) ~= 'function' then return end
    return player.get('activeGroup') ~= nil
end

---@description This will add money based on the type of account (cash/bank) or item name.
---@param src number
---@param _type string
---@param amount number
---@return boolean
Framework.AddAccountBalance = function(src, _type, amount)
    local player = Framework.GetPlayer(src)
    if not player then return false end
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    local kind, item = resolveMoneyKind(_type)
    if kind == 'bank' then
        local account = getCharacterAccount(player)
        if not account or type(account.addBalance) ~= 'function' then return false end
        local ok, result = pcall(function()
            return account.addBalance({ amount = amount, message = 'concept_bridge' })
        end)
        if not ok then return false end
        return result == true or (type(result) == 'table' and result.success == true)
    end
    if not oxInventoryStarted() then return false end
    local ok, success = pcall(function()
        return exports.ox_inventory:AddItem(src, item, amount)
    end)
    return ok and success and true or false
end

---@description This will remove money based on the type of account (cash/bank) or item name.
---@param src number
---@param _type string
---@param amount number
---@return boolean
Framework.RemoveAccountBalance = function(src, _type, amount)
    local player = Framework.GetPlayer(src)
    if not player then return false end
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    local kind, item = resolveMoneyKind(_type)
    if kind == 'bank' then
        local account = getCharacterAccount(player)
        if not account or type(account.removeBalance) ~= 'function' then return false end
        local ok, result = pcall(function()
            return account.removeBalance({ amount = amount, message = 'concept_bridge' })
        end)
        if not ok then return false end
        return result == true or (type(result) == 'table' and result.success == true)
    end
    if not oxInventoryStarted() then return false end
    local ok, success = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end)
    return ok and success and true or false
end

---@description This will return the balance based on the type of account (cash/bank) or item name.
---@param src number
---@param _type string
---@return number
Framework.GetAccountBalance = function(src, _type)
    local player = Framework.GetPlayer(src)
    if not player then return 0 end
    local kind, item = resolveMoneyKind(_type)
    if kind == 'bank' then
        local account = getCharacterAccount(player)
        NoteAccount(src, account)
        return accountBalance(account) or 0
    end
    if not oxInventoryStarted() then return 0 end
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(src, item, nil, false)
    end)
    if ok and type(count) == 'number' then return count end
    return 0
end

---@description Adds the specified item to the player's inventory.
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Framework.AddItem = function(src, item, count, slot, metadata)
    if not oxInventoryStarted() then return false end
    local ok, success = pcall(function()
        return exports.ox_inventory:AddItem(src, item, count, metadata, slot)
    end)
    if not ok or not success then return false end
    TriggerClientEvent('concept_bridge:client:inventory:updateInventory', src,
        { action = 'add', item = item, count = count, slot = slot, metadata = metadata })
    return true
end

---@description Removes the specified item from the player's inventory.
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Framework.RemoveItem = function(src, item, count, slot, metadata)
    if not oxInventoryStarted() then return false end
    local ok, success = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, count, metadata, slot)
    end)
    if not ok or not success then return false end
    TriggerClientEvent('concept_bridge:client:inventory:updateInventory', src,
        { action = 'remove', item = item, count = count, slot = slot, metadata = metadata })
    return true
end

---@description Sets the metadata for the specified item in the player's inventory.
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param slot number
---@param metadata table
---@return boolean
Framework.SetMetadata = function(src, item, slot, metadata)
    if not oxInventoryStarted() then return false end
    local ok = pcall(function()
        exports.ox_inventory:SetMetadata(src, slot, metadata)
    end)
    return ok
end

---@description Returns a table of items matching the specified name (and optional metadata).
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param metadata table
---@return table
Framework.GetItem = function(src, item, metadata)
    if not oxInventoryStarted() then return {} end
    local ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(src, false)
    end)
    if not ok or type(items) ~= 'table' then return {} end
    local repackedTable = {}
    for _, v in pairs(items) do
        if type(v) == 'table' and v.name == item and (not metadata or v.metadata == metadata) then
            repackedTable[#repackedTable + 1] = {
                name = v.name,
                count = v.count or v.amount,
                metadata = v.metadata or {},
                slot = v.slot,
            }
        end
    end
    return repackedTable
end

---@description Returns the count of items matching the specified name (and optional metadata).
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param metadata table
---@return number
Framework.GetItemCount = function(src, item, metadata)
    if not oxInventoryStarted() then return 0 end
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(src, item, metadata, false)
    end)
    if ok and type(count) == 'number' then return count end
    return 0
end

---@description Returns boolean if the player has the specified item in their inventory.
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@param item string
---@param requiredCount number|nil
---@return boolean
Framework.HasItem = function(src, item, requiredCount)
    return Framework.GetItemCount(src, item) >= (requiredCount or 1)
end

---@description Returns the entire inventory of the player as a table.
---This is an internal function and should not be used outside of bridge, use the Inventory module instead when dealing with items.
---@param src number
---@return table
Framework.GetPlayerInventory = function(src)
    if not oxInventoryStarted() then return {} end
    local ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(src, false)
    end)
    if ok and type(items) == 'table' then return items end
    return {}
end

---@description Returns the specified slot data as a table.
---@param src number
---@param slot number
---@return table
Framework.GetItemBySlot = function(src, slot)
    if not oxInventoryStarted() then return {} end
    local ok, item = pcall(function()
        return exports.ox_inventory:GetSlot(src, slot)
    end)
    if ok and type(item) == 'table' then return item end
    return {}
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

---@description This will return the entire items table from the inventory.
---@return table
Framework.Items = function()
    return oxItems()
end

---@description Alternate item list accessor used by the default Inventory module.
---@return table
Framework.ItemList = function()
    return { Items = oxItems() }
end

---@description Returns a table of owned vehicles for the player. format is {vehicle = vehicle, plate = plate}
---@param src number
---@return table
Framework.GetOwnedVehicles = function(src)
    local player = Framework.GetPlayer(src)
    if not player or not player.charId then return {} end
    local result = MySQL.Sync.fetchAll('SELECT plate, model FROM vehicles WHERE owner = ?', { player.charId })
    local vehicles = {}
    for i = 1, #result do
        vehicles[#vehicles + 1] = { vehicle = result[i].model, plate = result[i].plate }
    end
    return vehicles
end

---@description Returns a table of owned vehicles for the player. format is {id = id, vehicle = model, plate = plate}
---@param src number
---@param plate string
---@return table|false
Framework.IsVehicleOwnedByPlayer = function(src, plate)
    local player = Framework.GetPlayer(src)
    if not player or not player.charId then return false end
    local result = MySQL.Sync.fetchAll('SELECT id, model, plate FROM vehicles WHERE owner = ? AND plate = ?',
        { player.charId, plate })
    if not result[1] then return false end

    return { id = result[1].id, vehicle = result[1].model, plate = plate }
end

---@description Registers a usable item with a callback function.
---@param itemName string
---@param cb function
---@return function|nil
Framework.RegisterUsableItem = function(itemName, cb)
    local func = function(src, item, itemData)
        itemData = itemData or item
        itemData.metadata = itemData.metadata or itemData.info or {}
        itemData.slot = itemData.id or itemData.slot
        cb(src, itemData)
    end

    if oxInventoryStarted() then
        return exports.ox_inventory:registerUsableItem(itemName, func)
    end
    RegisterNetEvent('ox_core:useItem:' .. itemName, func)
    AddEventHandler('ox_core:useItem:' .. itemName, function(...)
        func(source, ...)
    end)
end

---@description Event handler for when a player is loaded in ox_core framework
RegisterNetEvent("ox:playerLoaded", function(playerId, userId, charId)
    -- (these framework events can be sent by a CLIENT, with any id as their argument: when the event comes
    -- from a player, that player is who it is about - the argument only counts for an event raised on the server)
    local sender = tonumber(source)
    if sender and sender > 0 then playerId = sender end
    playerId = playerId or source
    TriggerEvent("concept_bridge:Server:OnPlayerLoaded", playerId)
    TrackPlayerAccount(playerId)
    local jobData = Framework.GetPlayerJobData(playerId)
    if not jobData then return end
    Framework.AddJobCount(playerId, jobData.jobName)
end)

---@description Event handler for when a player logs out in ox_core framework
RegisterNetEvent("ox:playerLogout", function(playerId, userId, charId)
    local sender = tonumber(source)
    if sender and sender > 0 then playerId = sender end
    playerId = playerId or source
    UntrackPlayerAccount(playerId)
    TriggerEvent("concept_bridge:Server:OnPlayerUnload", playerId)
end)

---@description Event handler for when a player's group is updated in ox_core framework
RegisterNetEvent("ox:setGroup", function(playerId, groupName, grade)
    local sender = tonumber(source)
    if sender and sender > 0 then playerId = sender end
    playerId = playerId or source
    if not groupName then return end
    TriggerEvent("concept_bridge:Server:OnPlayerJobChange", playerId, groupName)
end)

---@description Event handler for when a player disconnects from the server
AddEventHandler("playerDropped", function()
    local src = source
    UntrackPlayerAccount(src)
    TriggerEvent("concept_bridge:Server:OnPlayerUnload", src)
end)

-- ox_core account events -> normalized client hint. The bridge carries no
-- balance here; consumers re-read the authoritative value (poll fallback for
-- builds without these events). Personal default accounts only: deposits or
-- withdrawals into a shared/business account must not hint the HUD.
AddEventHandler("ox:depositedMoney", function(data)
    if type(data) ~= 'table' or data.accountId == nil then return end
    local src = tonumber(data.playerId)
    if not src then return end
    if not SourceAccount[src] then TrackPlayerAccount(src) end
    if tostring(SourceAccount[src]) ~= tostring(data.accountId) then return end
    TriggerClientEvent('concept_bridge:Client:OnAccountUpdate', src, {
        account = 'bank',
        action = 'deposit',
        amount = tonumber(data.amount),
    })
end)

AddEventHandler("ox:withdrewMoney", function(data)
    if type(data) ~= 'table' or data.accountId == nil then return end
    local src = tonumber(data.playerId)
    if not src then return end
    if not SourceAccount[src] then TrackPlayerAccount(src) end
    if tostring(SourceAccount[src]) ~= tostring(data.accountId) then return end
    TriggerClientEvent('concept_bridge:Client:OnAccountUpdate', src, {
        account = 'bank',
        action = 'withdraw',
        amount = tonumber(data.amount),
    })
end)

AddEventHandler("ox:updatedBalance", function(data)
    if type(data) ~= 'table' then return end
    NotifyAccount(data.accountId, data.action == 'add' and 'add' or 'remove', tonumber(data.amount))
end)

AddEventHandler("ox:transferredMoney", function(data)
    if type(data) ~= 'table' then return end
    local amount = tonumber(data.amount)
    NotifyAccount(data.fromId, 'transfer_out', amount)
    NotifyAccount(data.toId, 'transfer_in', amount)
end)

Framework.Commands = {}
---@description Adds a command to the ox_core framework
---@param name string
---@param help string
---@param arguments table
---@param argsrequired boolean
---@param callback function
---@param permission string
---@param ... any
Framework.Commands.Add = function(name, help, arguments, argsrequired, callback, permission, ...)
    RegisterCommand(name, function(src, args, raw)
        if permission and permission ~= '' then
            if not IsPlayerAceAllowed(src, permission) then return end
        end
        callback(src, args, raw)
    end, false)
end

---@description Callback to get framework jobs list
---@param source number
lib.callback.register('concept_bridge:Callback:GetFrameworkJobs', function(source)
    return Framework.GetFrameworkJobs() or {}
end)

---@description Callback to get account balance
---@param source number
---@param _type string
lib.callback.register('concept_bridge:Callback:GetAccountBalance', function(source, _type)
    return Framework.GetAccountBalance(source, _type) or 0
end)

return Framework
