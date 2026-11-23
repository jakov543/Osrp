fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_osijek'
author 'Bandera'
description 'OSRP - Osijek city SCRIPTS (traffic, NPCs, BULET, bikes, cutscene, minimap, F7 map). Map files are in osrp_osijek_map.'
version '1.0.48'

dependency 'osrp_osijek_map'

shared_scripts { 'config.lua', 'layout.lua' }
client_scripts { 'client.lua', 'life.lua', 'streets.lua', 'ambulance.lua', 'events.lua', 'minimap.lua', 'arrival.lua', 'dialogs.lua', 'dialog.lua', 'bulet.lua', 'bikes.lua' }

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/map.js',
    'html/dialog.js',
    'html/dialog.css',
    'html/bulet.js',
    'html/bulet.css',
    'html/cine.js',
    'html/cine.css',
    'html/bikes.js',
    'html/bikes.css',
    'html/livery/policija_hr.png',
    'html/map.json',
    'html/map.png',
    'html/map_big.png',
}
server_script 'server.lua'
