fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_osijek'
author 'Bandera'
description 'OSRP - custom Osijek city (Blender -> Sollumz), placed in the sea east of Los Santos'
version '1.0.8'

this_is_a_map 'yes'

data_file 'DLC_ITYP_REQUEST' 'stream/osijek.ytyp'

shared_scripts { 'config.lua', 'layout.lua' }
client_script 'client.lua'
server_script 'server.lua'
