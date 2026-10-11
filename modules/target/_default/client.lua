---@diagnostic disable: duplicate-set-field
Target = Target or {}

local InteractIds = {}
local localEntities, localZones = {}, {}

local function warnUser()
    print("Currently Only Targeting Is Supported By Concept Bridge, You Are Using A Resource That Requires The Target Module To Be Used.")
end

function Target.GetResourceName()
    return "default"
end

function Target.GetCanInteract(id)
    return InteractIds[id]
end

function Target.CreateCanInteract(cb)
    if not cb then return end
    local id = lib.string.random('................')
    InteractIds[id] = {
        id = id,
        ableToInteract = -1,
        onInteract = cb
    }
    return id
end

function Target.CanInteract(id, ...)
    local interactData = InteractIds[id]
    if not interactData then return true end
    if interactData.ableToInteract == -1 then
        local cb = interactData.onInteract
        local canInteractStatus = cb(...)
        interactData.ableToInteract = canInteractStatus and 1 or 0
        SetTimeout(1000, function()
            interactData.ableToInteract = -1
        end)
    end
    return interactData.ableToInteract > 0
end

function Target.FixOptions(options)
    for k, v in pairs(options) do
        local action = v.onSelect or v.action
        local select = function(entityOrData)
            if type(entityOrData) == 'table' then
                return action(entityOrData.entity)
            end
            return action(entityOrData)
        end
        options[k].onSelect = select
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

function Target.AddGlobalPlayer(options)
    warnUser()
end

function Target.AddGlobalVehicle(options)
    warnUser()
end

function Target.RemoveGlobalVehicle(options)
    warnUser()
end

function Target.AddLocalEntity(entities, options)
    local fixedOptions = Target.FixOptions(options)
    if type(entities) == 'number' then entities = {entities} end
    for _, entity in pairs(entities) do
        Target.RemoveLocalEntity(entity)
        local menu = {id = lib.string.random('................'), title = locale('target.title'), options = {}}
        for _, option in pairs(fixedOptions) do
            menu.options[#menu.options + 1] = {
                title = option.label or option.name or locale('target.title'),
                description = locale('target.description'),
                onSelect = function()
                    if not option.canInteract or option.canInteract(entity) then option.onSelect(entity) end
                end,
            }
        end
        local point = lib.points.new({
            coords = GetEntityCoords(entity), distance = 5,
            nearby = function(self)
                if self.currentDistance < 2 and DoesEntityExist(entity) then
                    Utility.Draw3DHelpText(self.coords, locale('target.interact'), 0.35)
                    if IsControlJustPressed(0, 38) then Menu.Open(menu, false) end
                end
            end,
        })
        localEntities[entity] = point
        CreateThread(function()
            while localEntities[entity] == point and DoesEntityExist(entity) do
                local coords = GetEntityCoords(entity)
                if coords ~= point.coords then
                    lib.grid.removeEntry(point)
                    point.coords = coords
                    lib.grid.addEntry(point)
                end
                Wait(300)
            end
            if localEntities[entity] == point then Target.RemoveLocalEntity(entity) end
        end)
    end
end

function Target.AddModel(models, options)
    warnUser()
end

function Target.AddBoxZone(name, coords, size, heading, options)
    Target.RemoveZone(name)
    local fixedOptions = Target.FixOptions(options)
    local menu = {id = name, title = locale('target.title'), options = {}}
    for _, option in pairs(fixedOptions) do
        menu.options[#menu.options + 1] = {
            title = option.label or option.name or locale('target.title'),
            description = locale('target.description'),
            onSelect = function()
                if not option.canInteract or option.canInteract() then option.onSelect() end
            end,
        }
    end
    localZones[name] = lib.zones.box({
        coords = coords, size = size, rotation = heading or 0,
        inside = function()
            Utility.Draw3DHelpText(coords, locale('target.interact'), 0.35)
            if IsControlJustPressed(0, 38) then Menu.Open(menu, false) end
        end,
    })
    return name
end

function Target.RemoveGlobalPlayer()
    warnUser()
end

function Target.RemoveLocalEntity(entities)
    if type(entities) == 'number' then entities = {entities} end
    for _, entity in pairs(entities or {}) do
        if localEntities[entity] then localEntities[entity]:remove() end
        localEntities[entity] = nil
    end
end

function Target.RemoveModel(model)
    warnUser()
end

function Target.RemoveZone(name)
    if localZones[name] then localZones[name]:remove() end
    localZones[name] = nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity in pairs(localEntities) do Target.RemoveLocalEntity(entity) end
    for name in pairs(localZones) do Target.RemoveZone(name) end
end)

return Target