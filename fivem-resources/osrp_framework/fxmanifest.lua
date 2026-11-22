fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_framework'
author 'Bandera'
description 'OSRP V1 - own roleplay framework (no ESX/QBCore): characters, spawn, money, jobs, death, /me /do, admin'
version '1.0.40'

shared_script 'config.lua'
server_scripts {
    'server/main.lua',
    'server/commands.lua',
    'server/ems.lua',
    'server/shop.lua',
    'server/stores.lua'
}
client_scripts {
    'client/main.lua',
    'client/death.lua',
    'client/roleplay.lua',
    'client/hud.lua',
    'client/ems.lua',
    'client/police.lua',
    'client/stores.lua'
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/emblem.png'
}
