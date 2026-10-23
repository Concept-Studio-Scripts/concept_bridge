Marker = {}
local created = {}

function Marker.Create(data)
    local position = data.position
    if not position then return end
    local id = data.id or lib.string.random('................')
    if created[id] then Marker.Remove(id) end
    local coords = position + (data.offset or vec3(0, 0, 0))
    local size = data.size or vec3(1, 1, 1)
    local color = data.color or vec3(0, 255, 0)
    local marker = lib.marker.new({
        type = data.marker or 1, coords = coords,
        width = size.x, height = size.z,
        rotation = data.rotation or vec3(0, 0, 0),
        color = {r = color.x, g = color.y, b = color.z, a = data.alpha or 255},
        bobUpAndDown = data.bobUpAndDown, faceCamera = data.faceCamera,
        rotate = data.rotate, textureDict = data.textureDict,
        textureName = data.textureName, invert = data.drawOnEnts,
    })
    -- ox_lib's marker width applies to both horizontal axes. Keep rectangular
    -- marker shapes when a replicated definition specifies different X/Y sizes.
    if size.x ~= size.y then
        marker.draw = function()
            DrawMarker(data.marker or 1, coords.x, coords.y, coords.z,
                0, 0, 0, marker.rotation.x, marker.rotation.y, marker.rotation.z,
                size.x, size.y, size.z, color.x, color.y, color.z, data.alpha or 255,
                data.bobUpAndDown, data.faceCamera, 2, data.rotate,
                data.textureDict, data.textureName, data.drawOnEnts)
        end
    end
    created[id] = lib.points.new({
        coords = coords, distance = data.drawDistance or 50,
        nearby = function() marker:draw() end,
    })
    return id
end

function Marker.Remove(id)
    local point = created[id]
    if not point then return false end
    point:remove()
    created[id] = nil
    return true
end

function Marker.RemoveAll()
    for id in pairs(created) do Marker.Remove(id) end
end

RegisterNetEvent('concept_bridge:Client:Marker', Marker.Create)
RegisterNetEvent('concept_bridge:Client:MarkerBulk', function(rows)
    for _, data in pairs(rows or {}) do Marker.Create(data) end
end)
RegisterNetEvent('concept_bridge:Client:MarkerRemove', Marker.Remove)
RegisterNetEvent('concept_bridge:Client:MarkerRemoveBulk', function(ids)
    for _, id in pairs(ids or {}) do Marker.Remove(id) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Marker.RemoveAll() end
end)
exports('Marker', function() return Marker end)
return Marker
