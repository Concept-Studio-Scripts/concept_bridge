-- Run from bridge root: lua test/manifest_files.lua [root/]
-- Clients download only the fxmanifest `files` entries: every module and library file the client loads
-- must match one of them, and no server file may.
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function read(path)
    local file = assert(io.open(root .. path, 'rb'))
    local text = file:read('a')
    file:close()
    return text
end

local manifest = read('fxmanifest.lua')
local block = assert(manifest:match('\nfiles%s*(%b{})'), 'fxmanifest has a files block')
local patterns = {}
for entry in block:gmatch("'([^']+)'") do
    -- FiveM globs: ** spans folders, * stays inside one
    local lua = '^' .. entry:gsub('[%.%-%+%?%(%)%[%]%^%$%%]', '%%%0'):gsub('%*%*/', '\1'):gsub('%*%*', '\2')
        :gsub('%*', '[^/]*'):gsub('\1', '.-/?'):gsub('\2', '.*') .. '$'
    patterns[#patterns + 1] = lua
end
local function shipped(path)
    for _, pattern in ipairs(patterns) do if path:match(pattern) then return true end end
    return false
end

-- what the client loads: every adapter and default the catalog lists for the client side ...
local wanted = {}
local catalog = read('lib/providers/shared/catalog.lua')
for path in catalog:gmatch('client%s*=%s*"([^"]+)"') do wanted[path] = 'catalog' end
-- ... and every library a client or shared file requires
local function scan(path)
    for name in read(path):gmatch("lib%.require%(%s*'@concept_bridge%.([^']+)'") do
        wanted[name:gsub('%.', '/') .. '.lua'] = path
    end
end
local listing = io.popen(('cd "%s" && git ls-files lib modules'):format(root))
local all = {}
for path in listing:lines() do all[#all + 1] = path end
listing:close()
expect(#all > 50, 'the repository files are listed')
for _, path in ipairs(all) do
    local server = path:match('/server%.lua$') or path:match('/server/')
    if path:match('%.lua$') and not server then scan(path) end
end
scan('lib/init.lua')

local count = 0
for path, from in pairs(wanted) do
    if not path:match('/server/') then
        count = count + 1
        expect(shipped(path), ('client file %s (needed by %s) is in the manifest files'):format(path, from))
    end
end
expect(count > 100, 'every client adapter and library was checked')

for _, path in ipairs(all) do
    if path:match('/server%.lua$') or path:match('/server/') then
        expect(not shipped(path), 'server file ' .. path .. ' is not sent to clients')
    end
end
expect(not shipped('settings/serverConfig.lua'), 'the server settings are not sent to clients')

print(('manifest_files: %d assertions passed'):format(assertions))
