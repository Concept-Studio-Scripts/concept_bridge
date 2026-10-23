local function checker(metadata)
    local printed, requests = {}, {}
    local env = setmetatable({
        GetResourceMetadata = function() return metadata end,
        print = function(message) printed[#printed + 1] = message end,
        PerformHttpRequest = function(url) requests[#requests + 1] = url end,
        AddEventHandler = function() end,
    }, {__index = _G})
    local version = assert(loadfile('modules/version/server/VersionChecker.lua', 't', env))()
    return version, printed, requests
end
for _, metadata in ipairs({false, '', 'development'}) do
    local version, printed, requests = checker(metadata or nil)
    assert(pcall(version.AdvancedVersionChecker, 'owner/repo', 'my_resource'), 'bad/missing metadata must not throw')
    assert(#requests == 0 and #printed == 1 and printed[1]:find('my_resource', 1, true),
        'bad metadata reports the resource once and does not request remote notes')
end
for _, repo in ipairs({false, '', 'owner', 'owner/repo/extra'}) do
    local version, printed, requests = checker('1.0.0')
    assert(pcall(version.AdvancedVersionChecker, repo or nil, 'my_resource'), 'invalid repository must not throw')
    assert(#requests == 0 and #printed == 1, 'invalid repositories are rejected before HTTP')
end
local version, printed, requests = checker('v1.2.3')
version.AdvancedVersionChecker('owner/repo', 'my_resource')
assert(#printed == 0 and #requests == 1 and requests[1] ==
    'https://raw.githubusercontent.com/owner/repo/main/resources.json', 'valid prefixed versions still check updates')
print('version_checker: invalid metadata/repositories and valid update URL passed')
