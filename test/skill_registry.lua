local env = setmetatable({}, {__index = _G})
local Skills = assert(loadfile('modules/skills/_default/client.lua', 't', env))()
local created = Skills.Create('crafting', 50, 25)
assert(created.name == 'crafting' and created.maxLevel == 50 and Skills.All.crafting == created,
    'client skills initialize their own registry without a server Lua environment')
assert(Skills.Create(nil) == nil and Skills.All.crafting == created, 'invalid creation preserves registered skills')
print('skill_registry: client registry initialization and invalid creation passed')
