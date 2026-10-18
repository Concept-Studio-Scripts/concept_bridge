---@diagnostic disable: duplicate-set-field
local resourceName = "sleepless_interact"
if GetResourceState(resourceName) ~= 'started' then return end

local targetDebug = BridgeSharedConfig and BridgeSharedConfig.DebugLevel == 2 or false
local sleepless_interact = exports.sleepless_interact
local targetZones = {}

Target = Target or {}

function Target.GetResourceName()
    return "sleepless_interact"
end

---This is an internal function that is used to fix the options passed to fit alternative target systems, for example qb-ox or ox-qb etc.
---@param options table
---@return table
function Target.FixOptions(options)
    Target.TakeNewCanInteract()
    for k, v in pairs(options) do
        local action = v.onSelect or v.action
        local select = function(entityOrData)
            if type(entityOrData) == 'table' then
                return action(entityOrData.entity)
            end
            return action(entityOrData)
        end
        options[k].onSelect = select
        options[k].groups = v.job or v.groups
        local optionsCanInteract = v.canInteract
        if optionsCanInteract then
            local id = Target.CreateCanInteract(optionsCanInteract)
            v.canInteract = function(...)
                return Target.CanInteract(id, ...)
            end
        end
    end
    return options
end

---This will toggle the targeting system on or off. This is useful for when you want to disable the targeting system for a specific player entirely.
---@param bool boolean
function Target.DisableTargeting(bool) -- someone disabled this mistakenly
    sleepless_interact:disableInteract(bool)
end

---This will add target options to players.
---@param options table
function Target.AddGlobalPlayer(options)
    options = Target.FixOptions(options)
    sleepless_interact:addGlobalPlayer(options)
end

---This will remove target options from all players.
---@param names string|table|nil Native option name(s); nil is a bridge no-op.
function Target.RemoveGlobalPlayer(names)
    if names == nil then return end
    sleepless_interact:removeGlobalPlayer(names)
end

---This will add target options to all specified models. This is useful for when you want to add target options to all models of a specific type.
---@param options table
function Target.AddGlobalPed(options)
    options = Target.FixOptions(options)
    sleepless_interact:addGlobalPed(options)
end

---This will remove target options from all peds. This is useful for when you want to remove target options from all peds.
---@param options any
function Target.RemoveGlobalPed(options)
    sleepless_interact:removeGlobalPed(options)
end

---This will add taget options to all vehicles.
---@param options table
function Target.AddGlobalVehicle(options)
    options = Target.FixOptions(options)
    sleepless_interact:addGlobalVehicle(options)
end

---This will remove target options from all vehicles.
---@param options table
function Target.RemoveGlobalVehicle(options)
    local assembledLables = {}
    for k, v in pairs(options) do
        table.insert(assembledLables, v.name)
    end
    sleepless_interact:removeGlobalVehicle(assembledLables)
end

---This will add a networked entity to the target system.
---@param netids table | number
---@param options table
function Target.AddNetworkedEntity(netids, options)
    options = Target.FixOptions(options)
    sleepless_interact:addEntity(netids, options)
end

---This will remove a networked entity from the target system.
---@param netids table | number
---@param optionNames string
function Target.RemoveNetworkedEntity(netids, optionNames)
    sleepless_interact:removeEntity(netids, optionNames)
end

---This will generate targets on non networked entites with the passed options.
---@param entities number | table
---@param options table
function Target.AddLocalEntity(entities, options)
    options = Target.FixOptions(options)
    Target.OwnCanInteractEntities(entities, Target.TakeNewCanInteract())
    sleepless_interact:addLocalEntity(entities, options)
end

---This will remove the target options from a local entity. This is useful for when you want to remove target options from a specific entity.
---@param entity number | table
---@param labels string | table | nil
function Target.RemoveLocalEntity(entity, labels)
    sleepless_interact:removeLocalEntity(entity, labels)
    if labels == nil then Target.FreeCanInteractEntities(entity) end
end

---This will add target options to all specified models. This is useful for when you want to add target options to all models of a specific type.
---@param models number | table
---@param options table
function Target.AddModel(models, options)
    options = Target.FixOptions(options)
    sleepless_interact:addModel(models, options)
end

---This will remove target options from all specified models.
---@param model number
function Target.RemoveModel(model)
    sleepless_interact:removeModel(model)
end

-- sleepless_interact has no zones: a zone is a coords point (addCoords). Points share ids by position, so
-- every option gets a name and a zone removes only its own options by name.
local function addZone(name, coords, options)
    options = Target.FixOptions(options or {})
    Target.OwnCanInteract('zone:' .. name, Target.TakeNewCanInteract())
    local names = {}
    for index, option in pairs(options) do
        option.name = option.name or ('%s:%s'):format(name, index)
        names[#names + 1] = option.name
    end
    local target = sleepless_interact:addCoords(vector3(coords.x, coords.y, coords.z), options)
    table.insert(targetZones, { name = name, id = target, names = names, creator = GetInvokingResource() or GetCurrentResourceName() })
    return target
end

local function removeZone(zone)
    Target.FreeCanInteract('zone:' .. zone.name)
    sleepless_interact:removeCoords(zone.id, zone.names)
end

---This will add a box zone to the target system. This is useful for when you want to add target options to a specific area.
---@param name string
---@param coords table
---@param size table
---@param heading number
---@param options table
function Target.AddBoxZone(name, coords, size, heading, options)
    return addZone(name, coords, options)
end

---This will add a circle zone to the target system. This is useful for when you want to add target options to a specific area.
---@param name string
---@param coords table
---@param radius number
---@param options table
function Target.AddSphereZone(name, coords, radius, options, debug)
    return addZone(name, coords, options)
end

---This will remove target options from a specific zone.
---@param name string
function Target.RemoveZone(name)
    for index, data in pairs(targetZones) do
        if data.name == name then
            removeZone(data)
            table.remove(targetZones, index)
            break
        end
    end
end

-- Forget only the zones of a stopping resource; others stay removable. If the provider stops,
-- its zones and ids are gone, so forget all of them without removing anything.
local function cleanupZones(resource)
    if resource == resourceName then
        targetZones = {}
        return
    end
    local all = resource == GetCurrentResourceName()
    for index = #targetZones, 1, -1 do
        local zone = targetZones[index]
        if all or zone.creator == resource then
            pcall(removeZone, zone)
            table.remove(targetZones, index)
        end
    end
end

AddEventHandler('onResourceStop', cleanupZones)

return Target
