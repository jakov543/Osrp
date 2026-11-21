fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_osijek'
author 'Bandera'
description 'OSRP - custom Osijek city (Blender -> Sollumz), placed in the sea east of Los Santos'
version '1.0.7'

this_is_a_map 'yes'
-- Remove the -- below once the converted files (osijek.ytyp + osijek_*.ydr) are in stream/:
-- data_file 'DLC_ITYP_REQUEST' 'stream/osijek.ytyp'

shared_scripts { 'config.lua', 'layout.lua' }
client_script 'client.lua'
server_script 'server.lua'
