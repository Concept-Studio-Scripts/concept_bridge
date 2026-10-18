fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
author 'Concept Studio; derived from The Order of the Sacred Framework and contributors'
name 'concept_bridge'
description 'Concept Studio compatibility layer for FiveM frameworks and providers; derived from Community Bridge.'
version '2.0.0' -- x-release-please-version

shared_scripts {
    '@ox_lib/init.lua',
    'settings/sharedConfig.lua',
    'lib/init.lua',
    'modules/clothing/**/shared.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'settings/serverConfig.lua',
    'modules/providers/server.lua',
    'modules/version/server/*.lua',
    'modules/shops/**/server.lua',
    "lib/**/server.lua",
    'init.lua',
}

client_scripts {
    'settings/clientConfig.lua',
    'modules/providers/client.lua',
    'modules/weapons/client.lua',
    'modules/shops/**/client.lua',
    'init.lua',
}

-- Clients download only what runs on them: client and shared code, never server modules.
files {
    'locales/*.json',
    'lib/init.lua',
    'lib/**/client/*.lua',
    'lib/**/shared/*.lua',
    'modules/**/client.lua',
    'modules/**/client/*.lua',
    'modules/**/shared.lua',
    'settings/clientConfig.lua',
    'settings/sharedConfig.lua',
}

dependencies {
    '/server:6116',
    '/onesync',
    'ox_lib',
    'oxmysql',
}
