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
    'modules/version/server/*.lua',
    'modules/framework/**/server.lua',
    'modules/inventory/**/server.lua',
    'modules/doorlock/**/server.lua',
    'modules/phone/**/server.lua',
    'modules/banking/**/server.lua',
    'modules/dispatch/**/server.lua',
    'modules/clothing/**/server.lua',
    'modules/shops/**/server.lua',
    'modules/helptext/**/server.lua',
    'modules/notify/**/server.lua',
    'modules/housing/**/server.lua',
    'modules/skills/**/server.lua',
    'modules/bossmenu/**/server.lua',
    "lib/**/server.lua",
    'init.lua',
}

client_scripts {
    'settings/clientConfig.lua',
    'modules/framework/**/client.lua',
    'modules/inventory/**/client.lua',
    'modules/weapons/client.lua',
    'modules/seatbelt/**/client.lua',
    'modules/voice/**/client.lua',
    'modules/doorlock/**/client.lua',
    'modules/phone/**/client.lua',
    'modules/weather/**/client.lua',
    'modules/vehiclekey/**/client.lua',
    'modules/fuel/**/client.lua',
    'modules/target/**/client.lua',
    'modules/dispatch/**/client.lua',
    'modules/progressbar/**/client.lua',
    'modules/clothing/**/client.lua',
    'modules/input/**/client.lua',
    'modules/menu/**/client.lua',
    'modules/helptext/**/client.lua',
    'modules/notify/**/client.lua',
    'modules/dialogue/**/client/*.lua',
    'modules/shops/**/client.lua',
    'modules/housing/**/client.lua',
    'modules/skills/**/client.lua',
    'modules/bossmenu/**/client.lua',
    'init.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*.css',
    'web/dist/assets/*.js',
    'locales/*.json',
    'lib/**/**/*.lua',
    'lib/**/**/**/*.lua',
    'modules/**',
    'settings/*.lua',
    'lib/init.lua',
}

dependencies {
    '/server:6116',
    '/onesync',
    'ox_lib',
}
