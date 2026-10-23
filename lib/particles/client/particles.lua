Particles = {}
Particle = {}
local particleAssets = {}

---@diagnostic disable: duplicate-set-field
--- Create a particle effect at the specified position and rotation.
--- @param dict string
--- @param ptfx string
--- @param pos vector3
--- @param rot vector3
--- @param scale number
--- @param color vector3
--- @param looped boolean
--- @param removeAfter number|nil
--- @return number|string|nil ptfxHandle -- Repeating effects return their tracked string id.
function Particle.Play(dict, ptfx, pos, rot, scale, color, looped, removeAfter)
    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    SetParticleFxNonLoopedColour(color.x, color.y, color.z)
    local particle = nil
    removeAfter = removeAfter or 5000
    if looped then
        particle = StartParticleFxLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false, false)
        local strParticle = tostring(particle)
        Particles[strParticle] = particle
        particleAssets[strParticle] = dict
        Wait(10)
        if particle == 0 or not DoesParticleFxLoopedExist(particle) then            
            Particles[strParticle], particleAssets[strParticle] = nil, nil
            particle = StartParticleFxNonLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false)
            if not particle or particle == 0 then
                RemoveNamedPtfxAsset(dict)
                print(string.format("[Particle] Failed to start particle fx: %s from dict: %s", ptfx, dict))
                return nil
            end
            local strParticle = tostring(particle)
            Particles[strParticle] = particle
            particleAssets[strParticle] = dict
            CreateThread(function()
                while Particles[strParticle] do
                    Wait(removeAfter)
                    if not Particles[strParticle] then break end
                    RemoveParticleFx(particle, false)                
                    lib.requestNamedPtfxAsset(dict)
                    UseParticleFxAssetNextCall(dict)
                    particle = StartParticleFxNonLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false)
                    if not particle or particle == 0 then
                        local asset = particleAssets[strParticle]
                        Particles[strParticle], particleAssets[strParticle] = nil, nil
                        if asset then RemoveNamedPtfxAsset(asset) end
                        break
                    end
                    Particles[strParticle] = particle
                end
            end)
            return strParticle
        else
            if not removeAfter or removeAfter <= 0 then return particle end
            CreateThread(function()
                while Particles[strParticle] do
                    Wait(removeAfter)
                    if not Particles[strParticle] then break end
                    StopParticleFxLooped(particle, false)
                    lib.requestNamedPtfxAsset(dict)
                    UseParticleFxAssetNextCall(dict)
                    particle = StartParticleFxLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false, false)
                    if not particle or particle == 0 then
                        local asset = particleAssets[strParticle]
                        Particles[strParticle], particleAssets[strParticle] = nil, nil
                        if asset then RemoveNamedPtfxAsset(asset) end
                        break
                    end
                    Particles[strParticle] = particle
                end
            end)     
            return strParticle
        end
    else 
        particle = StartParticleFxLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false, false)
        Wait(10)
        if not DoesParticleFxLoopedExist(particle) then            
            particle = StartParticleFxNonLoopedAtCoord(ptfx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, scale, false, false, false)
        end
        if not particle or particle == 0 then
            RemoveNamedPtfxAsset(dict)
            return nil
        end
        particleAssets[tostring(particle)] = dict
        Wait(removeAfter)
        Particle.Stop(particle)
    end

    return particle
end

function Particle.Stop(particle)
    if not particle then return end
    local id = tostring(particle)
    particle = Particles[id] or tonumber(particle)
    if not particle or particle == 0 then return end
    StopParticleFxLooped(particle, false)
    RemoveParticleFx(particle, false)
    if particleAssets[id] then RemoveNamedPtfxAsset(particleAssets[id]) end
    Particles[id], particleAssets[id] = nil, nil
end

function Particle.CreateOnEntity(dict, ptfx, entity, offset, rot, scale, color, looped, loopLength)
    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    SetParticleFxNonLoopedColour(color.x, color.y, color.z)
    local particle = nil
    if looped then
        particle = StartNetworkedParticleFxLoopedOnEntity(ptfx, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale, false, false, false)
        if loopLength then
            Wait(loopLength)
            RemoveParticleFxFromEntity(entity)
        end
    else
        particle = StartNetworkedParticleFxLoopedOnEntity(ptfx, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale, false, false, false)
    end
    RemoveNamedPtfxAsset(dict)
    return particle
end

function Particle.CreateOnEntityBone(dict, ptfx, entity, bone,  offset, rot, scale, color, looped, loopLength)
    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    SetParticleFxNonLoopedColour(color.x, color.y, color.z)
    local particle = nil
    if looped then
        particle = StartNetworkedParticleFxLoopedOnEntityBone(ptfx, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, bone, scale, false, false, false)
        if loopLength then
            Wait(loopLength)
            RemoveParticleFxFromEntity(entity)
        end
    else
        particle = StartNetworkedParticleFxNonLoopedOnEntityBone(ptfx, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, bone, scale, false, false, false)
    end
    RemoveNamedPtfxAsset(dict)
    return particle
end

return Particle
