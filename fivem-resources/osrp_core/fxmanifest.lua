fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'osrp_core'
author 'Bandera'
description 'OSRP V1 - Osijek Roleplay: map name Osijek, GTA V HUD kept, custom map streaming'
version '1.0.22'

client_script 'client.lua'
server_script 'server.lua'

-- Put your custom Osijek map files (.ymap / .ytyp / .ydr / .ytd) in the stream/ folder.
this_is_a_map 'yes'

-- When your Blender/CodeWalker map is ready (see map/BLENDER-MAP.md), uncomment:
-- data_file 'DLC_ITYP_REQUEST' 'stream/osijek.ytyp'
