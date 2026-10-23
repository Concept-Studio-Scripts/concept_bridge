-- ox_lib owns generic utilities; this registry contains bridge extensions only.
lib.locale(BridgeSharedConfig.Lang ~= 'auto' and BridgeSharedConfig.Lang or nil)

cLib = {
    Math = lib.require('@concept_bridge.lib.utility.shared.math'),
    LA = lib.require('@concept_bridge.lib.utility.shared.la'),
}

if IsDuplicityVersion() then
    cLib.Logs = lib.require('@concept_bridge.lib.logs.server.logs')
    cLib.Marker = lib.require('@concept_bridge.lib.markers.server.server')
    cLib.Shell = lib.require('@concept_bridge.lib.shells.server.shells')
    cLib.Entity = lib.require('@concept_bridge.lib.entities.server.server_entity')
    cLib.ServerEntity = cLib.Entity
else
    cLib.Placeable = lib.require('@concept_bridge.lib.placers.client.object_Placer')
    cLib.Utility = lib.require('@concept_bridge.lib.utility.client.utility')
    cLib.PlaceableObject = lib.require('@concept_bridge.lib.placers.client.placeable_object')
    cLib.Particle = lib.require('@concept_bridge.lib.particles.client.particles')
    cLib.Marker = lib.require('@concept_bridge.lib.markers.client.markers')
    cLib.Anim = lib.require('@concept_bridge.lib.anim.client.client')
    cLib.Cutscene = lib.require('@concept_bridge.lib.cutscenes.client.cutscene')
    cLib.Entity = lib.require('@concept_bridge.lib.entities.client.client_entity')
    cLib.ClientEntity = cLib.Entity
end

exports('cLib', function() return cLib end)
return cLib
