---@diagnostic disable: duplicate-set-field
if GetResourceState('qbx_core') ~= 'started' then return end

QBox = exports.qbx_core

Framework = Framework or {}

---@description This will get the name of the framework being used (if a supported framework).
---@return string
Framework.GetFrameworkName = function()
    print("This is depricated, please use Framework.GetResourceName() instead.")
    return Framework.GetResourceName()
end

---@description This will get the name of the in use resource.
---@return string
Framework.GetResourceName = function()
    return 'qbx_core'
end

---@description This will return true if the player is loaded, false otherwise.
---@return boolean
Framework.GetIsPlayerLoaded = function()
    return LocalPlayer.state.isLoggedIn or false
end

---@description This is an internal function, do not use this outside of bridge as there is no standard format between the frameworks.
---@return table
-- PlayerData read through the core's export is copied on every call: a loaded character's data is kept
-- here and follows QBCore:Player:SetPlayerData (the core sends the whole data on every change).
local playerCache = nil

Framework.GetPlayerData = function()
    if playerCache then return playerCache end
    local data = QBox.GetPlayerData()
    if type(data) == 'table' and data.citizenid then playerCache = data end
    return data
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' and data.citizenid then playerCache = data end
end)

-- Character data only once a character is loaded: on the character select screen PlayerData is empty
-- and getters return nil (or an empty value) instead of erroring.
local function loadedData()
    local data = Framework.GetPlayerData()
    if type(data) == 'table' and data.citizenid then return data end
end

---@description This will return a table of all the jobs in the framework.
---@return table
Framework.GetFrameworkJobs = function()
    return QBox.GetJobs()
end

---@description This will get the players birth date
---@return string
Framework.GetPlayerDob = function()
    local playerData = loadedData()
    return playerData and playerData.charinfo and playerData.charinfo.birthdate
end

---@description Will Display the help text message on the screen
---@param message string
---@param position string
---@return nil
Framework.ShowHelpText = function(message, position)
    return exports.ox_lib:showTextUI(message, { position = position or 'top-center' })
end

---@description This will hide the help text message on the screen
---@return nil
Framework.HideHelpText = function()
    return exports.ox_lib:hideTextUI()
end

---@description This will return the players metadata for the specified metadata key.
---@param metadata table | string
---@return table | string | number | boolean
Framework.GetPlayerMetaData = function(metadata)
    local data = loadedData()
    return data and data.metadata and data.metadata[metadata]
end

---@description This will send a notification to the player.
---@param message string
---@param type string
---@param time number
---@return nil
Framework.Notify = function(message, type, time)
    return QBox:Notify("Notification", type, time, message)
end

---@description This will get the hunger of a player
---@return number
Framework.GetHunger = function()
    local hunger = Framework.GetPlayerMetaData("hunger") or 0
    return math.floor((hunger) + 0.5) or 0
end

---@description This will get the thirst of a player
---@return number
Framework.GetThirst = function()
    local thirst = Framework.GetPlayerMetaData("thirst") or 0
    return math.floor((thirst) + 0.5) or 0
end

---@description This will get the players identifier (citizenid) etc.
---@return string
Framework.GetPlayerIdentifier = function()
    local data = loadedData()
    return data and data.citizenid
end

---@description This will get the players name (first and last).
---@return string
---@return string
Framework.GetPlayerName = function()
    local playerData = loadedData()
    if not playerData or not playerData.charinfo then return nil, nil end
    return playerData.charinfo.firstname, playerData.charinfo.lastname
end

---@description Depricated : This will return the players job name, job label, job grade label and job grade level
---@return string
---@return string
---@return string
---@return string
Framework.GetPlayerJob = function()
    --print("This is depricated, please use Framework.GetPlayerJobData() instead.")
    local jobData = Framework.GetPlayerJobData()
    if not jobData then return nil end
    return jobData.jobName, jobData.jobLabel, jobData.gradeName, jobData.gradeRank
end

---@description This will return the players job name, job label, job grade label job grade level, boss status, and duty status in a table
---@return table
Framework.GetPlayerJobData = function()
    local playerData = loadedData()
    local jobData = playerData and playerData.job
    if not jobData then return nil end
    local grade = jobData.grade or {}
    return {
        jobName = jobData.name,
        jobLabel = jobData.label,
        gradeName = grade.name,
        gradeLabel = grade.name,
        gradeRank = grade.level,
        boss = jobData.isboss,
        onDuty = jobData.onduty,
    }
end

---@description This is an internal function used as a fallback, please use the Inventory.GetPlayerInventory instead.
---@return table {name, label, count, slot, metadata, stack, close, weight}
Framework.GetPlayerInventory = function()
    local data = loadedData()
    -- (a copy: a caller that sorts or trims the list must not change the cached player data)
    local items = {}
    for slot, item in pairs(data and data.items or {}) do items[slot] = item end
    return items
end

---@description This will return the players money by type, I recommend not useing this as its the client and not secure or to be trusted.
---Use case is for a ui or a menu I guess.
---@param _type string
---@return number
Framework.GetAccountBalance = function(_type)
    local player = loadedData()
    local account = player and player.money
    if not account then return 0 end
    if _type == 'money' then _type = 'cash' end
    local balance = account[_type] or 0
    if balance <= 0 then return 0 end
    return balance
end

---@description This is an internal function used as a fallback, please use the Inventory.GetItemCount instead.
--- @param item string
--- @return number
Framework.GetItemCount = function(item)
    return 0, print("Qbox has not implemented GetItemCount for this framework. Please ensure the inventory you are using is supported and start order is correct.")
end

---@description This will return the item data for the specified item.
--- @param item string
--- @return table {name, label, stack, weight, description, image}
Framework.GetItemInfo = function(item)
    return {}, print("Qbox has not implemented GetItemInfo for this framework. Please ensure the inventory you are using is supported and start order is correct.")
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Framework.HasItem = function(item, requiredCount)
	return false, print("Qbox has not implemented HasItem for this framework, Please ensure the inventory you are using is supported and start order is correct.")
end

---@description This will get a players dead status.
---@return boolean
Framework.GetIsPlayerDead = function()
    local playerData = loadedData()
    local metadata = playerData and playerData.metadata
    if not metadata then return false end
    return metadata["isdead"] or metadata["inlaststand"] or false
end

---@description Is the local player down: dead OR in last stand.
---@return boolean
Framework.GetIsPlayerDown = function()
    local playerData = Framework.GetPlayerData()
    return lib.require('@concept_bridge.lib.framework.shared.player_down').FromQbMetadata(playerData and playerData.metadata)
end

---@description Event handler for when player is loaded in QBX Core framework
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerCache = nil
    Wait(1500)
    TriggerEvent('concept_bridge:Client:OnPlayerLoaded')
end)

---@description Event handler for when player is unloaded in QBX Core framework
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerCache = nil
    TriggerEvent('concept_bridge:Client:OnPlayerUnload')
end)

---@description Event handler for when player job is updated in QBX Core framework
---@param data table Job data containing name, label, and grade information
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(data)
    if playerCache and type(data) == 'table' then playerCache.job = data end
    TriggerEvent('concept_bridge:Client:OnPlayerJobUpdate', data.name, data.label, data.grade.name, data.grade.level)
end)

return Framework