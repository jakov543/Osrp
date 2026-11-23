fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_osijek'
author 'Bandera'
description 'OSRP - custom Osijek city (Blender -> Sollumz), placed in the sea east of Los Santos'
version '1.0.42'

this_is_a_map 'yes'

data_file 'DLC_ITYP_REQUEST' 'stream/osijek.ytyp'

shared_scripts { 'config.lua', 'layout.lua' }
client_scripts { 'client.lua', 'life.lua', 'streets.lua', 'ambulance.lua', 'events.lua', 'minimap.lua', 'arrival.lua', 'dialogs.lua', 'dialog.lua', 'bulet.lua' }

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
    'html/livery/policija_hr.png',
    'html/map.json',
    'html/map.png',
    'html/map_big.png',
}
server_script 'server.lua'
