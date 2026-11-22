fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_framework'
author 'Bandera'
description 'OSRP V1 - own roleplay framework (no ESX/QBCore): characters, spawn, money, jobs, death, /me /do, admin'
version '1.0.24'

shared_script 'config.lua'
server_scripts {
    'server/main.lua',
    'server/commands.lua',
    'server/ems.lua'
}
client_scripts {
    'client/main.lua',
    'client/death.lua',
    'client/roleplay.lua',
    'client/hud.lua',
    'client/ems.lua'
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/emblem.png'
}
