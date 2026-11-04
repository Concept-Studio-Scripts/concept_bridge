-- Run from bridge root: lua test/qb_menu.lua [root/]
-- QB menu options run like qb-menu runs them: server events, commands, QB commands and actions,
-- not only client events. Every converted menu provider shares this helper.
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local calls = {}
local env = setmetatable({}, {__index = _G})
env._G = env
env.TriggerEvent = function(...) calls[#calls + 1] = {'client', ...} end
env.TriggerServerEvent = function(...) calls[#calls + 1] = {'server', ...} end
env.ExecuteCommand = function(...) calls[#calls + 1] = {'command', ...} end
local QBMenu = assert(loadfile(root .. 'lib/menu/client/qb.lua', 't', env))()

local acted
local menu = QBMenu.ToContext('qb', {
    {header = 'Garage', isMenuHeader = true},
    {header = 'Client', params = {event = 'garage:open', args = {slot = 1}}},
    {header = 'Server', params = {event = 'garage:buy', isServer = true, args = 2}},
    {header = 'Command', params = {event = 'e sit', isCommand = true}},
    {header = 'QB command', params = {event = 'fix', isQBCommand = true, args = 3}},
    {header = 'Action', params = {event = function(args) acted = args end, isAction = true, args = 4}},
    {header = 'Header only'},
})
expect(menu.title == 'Garage' and #menu.options == 6, 'the first header is the title and the rest are options')
for i = 1, 5 do menu.options[i].onSelect(menu.options[i].args) end
menu.options[6].onSelect()

expect(calls[1][1] == 'client' and calls[1][2] == 'garage:open' and calls[1][3].slot == 1, 'a plain event fires on the client')
expect(calls[2][1] == 'server' and calls[2][2] == 'garage:buy' and calls[2][3] == 2, 'isServer fires a server event')
expect(calls[3][1] == 'command' and calls[3][2] == 'e sit', 'isCommand runs the command')
expect(calls[4][1] == 'server' and calls[4][2] == 'QBCore:CallCommand' and calls[4][3] == 'fix' and calls[4][4] == 3,
    'isQBCommand asks QBCore to run the command')
expect(acted == 4, 'isAction calls the function with its args')
expect(#calls == 4, 'an option without an event does nothing')

local own = function() end
expect(QBMenu.ToContext('qb', {{header = 'Own', action = own}}).options[1].onSelect == own, 'an option action is kept')

print(('qb_menu: %d assertions passed'):format(assertions))
