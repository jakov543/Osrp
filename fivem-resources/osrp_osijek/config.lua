Config = {}

-- Where Osijek sits in the GTA world: open sea east of Los Santos, 30 m above the water
Config.Origin = vector3(5500.0, -1500.0, 8.0)   -- v1.0.15: 8 m above the sea (quays, no waves on the streets), the Drava is real GTA water

-- Spawn point in Osijek (Europska avenija, next to Tvrđa). Put this in
-- osrp_framework/config.lua -> Config.Spawn once the map works:
--   Config.Spawn = vector4(5675.0, -1511.0, 9.0, 90.0)
Config.SpawnOffset = vector4(175.0, -11.0, 1.0, 90.0)

Config.StreamDistance = 900.0   -- chunks appear within this distance

-- Real GTA V trees per area (the first model that exists in your GTA version is used, so nothing breaks)
Config.TreeModels = {
    av   = { 'prop_tree_birch_01', 'prop_tree_maple_02', 'prop_tree_birch_02' },   -- Europska avenija
    prom = { 'prop_tree_birch_02', 'prop_tree_birch_01', 'prop_tree_maple_02' },   -- promenada uz Dravu
    park = { 'prop_tree_oak_01', 'prop_tree_maple_02', 'prop_tree_cedar_02', 'prop_tree_birch_01' },
    trg  = { 'prop_tree_maple_02', 'prop_tree_birch_01' },                         -- Tvrđa
}

-- Doors of the houses you can enter: first model that exists in your GTA is used
Config.DoorModels = { 'v_ilev_fh_frontdoor', 'prop_ld_door_01', 'v_ilev_trevtraildr', 'prop_com_ls_door_01' }
Config.DoorsLocked = false            -- true = everyone needs a key (lock them from your own scripts)

-- Furniture inside the houses (first existing model per type)
Config.FurnitureModels = {
    sofa    = { 'v_res_tre_sofa_s', 'prop_couch_01', 'v_ilev_m_sofa', 'prop_couch_lg_02' },
    automat = { 'prop_vend_snak_01', 'prop_vend_soda_01', 'prop_vend_soda_02' },
    kava    = { 'prop_vend_coffe_01', 'prop_vend_water_01' },
    krevet  = { 'v_med_bed1', 'v_med_emptybed', 'v_med_bed2' },
    stol    = { 'prop_table_03', 'prop_table_04', 'v_res_tre_table2' },
    stolica = { 'prop_chair_01a', 'prop_chair_04a', 'v_res_tre_chair' },
    tv      = { 'prop_tv_flat_01', 'prop_tv_03', 'prop_tv_06' },
    biljka  = { 'prop_plant_int_01a', 'prop_pot_plant_01a', 'prop_plant_01a' },
}

Config.InteriorDistance = 120.0       -- doors/furniture appear within this distance
Config.InteriorLight = true           -- warm ceiling light in each house (always on)

-- ===================== city life (v1.0.11) =====================
Config.CityRadius = 1000.0          -- size of Osijek incl. hospital + airport (metres from the centre)
Config.DrawMap = true               -- landmark blips (hospital, airport ...) on the pause map
Config.MapMode = 'nui'              -- 'nui' = real drawn minimap + big map (F7) | 'blips' = old blip rectangles

Config.ParkedCars = true
Config.ParkedModels = { 'asea', 'premier', 'emperor', 'ingot', 'primo', 'stanier', 'blista', 'dilettante', 'panto', 'issi2', 'rhapsody', 'fugitive' }

Config.SignModels = {
    stop     = { 'prop_sign_road_01a', 'prop_sign_road_01b' },
    semafor  = { 'prop_traffic_01a', 'prop_traffic_01b', 'prop_traffic_03a' },
    pjesacki = { 'prop_sign_road_05a', 'prop_sign_road_03a', 'prop_sign_road_01a' },
    -- v1.0.15 airport props (first model that exists in your GTA is used)
    air_stair     = { 'prop_air_stair_01', 'prop_air_stair_02', 'prop_air_stair_03' },
    air_bagloader = { 'prop_air_bagloader2', 'prop_air_bagloader' },
    air_cart      = { 'prop_air_trailer_4a', 'prop_air_trailer_1a', 'prop_air_cargo_01a' },
    air_cargo     = { 'prop_air_cargo_01a', 'prop_air_cargo_02a', 'prop_air_cargo_04a' },
    air_radar     = { 'prop_air_bigradar' },
    air_cone      = { 'prop_air_conelight', 'prop_roadcone01a' },
    -- v1.0.16 street furniture
    klupa   = { 'prop_bench_01a', 'prop_bench_05', 'prop_bench_09' },
    kanta   = { 'prop_bin_05a', 'prop_bin_01a', 'prop_bin_07a' },
    hidrant = { 'prop_fire_hydrant_1', 'prop_fire_hydrant_2' },
    kiosk   = { 'prop_news_disp_02a', 'prop_news_disp_01a', 'prop_news_disp_03a' },
    bicikl  = { 'prop_bikerack_1a', 'prop_bikerack_2' },
    telefon = { 'prop_phonebox_04', 'prop_phonebox_01a' },
    posuda  = { 'prop_pot_plant_03a', 'prop_plant_int_03a', 'prop_pot_plant_05a' },
}

Config.Pedestrians = true
Config.PedCount = 44                -- NPCs walking, sitting, standing around you (phone, coffee, smoking ...)
Config.PedModels = { 'a_m_y_business_01', 'a_f_y_business_01', 'a_m_m_business_01', 'a_f_y_hipster_01', 'a_m_y_hipster_01',
                     'a_f_m_bevhills_01', 'a_m_y_vinewood_01', 'a_f_y_tourist_01', 'a_m_m_skater_01', 'a_f_y_eastsa_01',
                     'a_m_y_bevhills_01', 'a_f_y_bevhills_02', 'a_m_m_eastsa_02', 'a_f_m_tourist_01', 'a_m_y_runner_01',
                     'a_f_y_runner_01', 'a_m_o_genstreet_01', 'a_f_o_genstreet_01', 'a_m_y_genstreet_01', 'a_f_y_genhot_01',
                     'a_m_m_tourist_01', 'a_m_y_student_01', 'a_f_y_student_01', 'a_m_m_farmer_01', 'a_f_m_fatwhite_01' }

Config.Traffic = true
Config.TrafficCount = 10            -- cars with drivers driving around the city
Config.TrafficModels = { 'asea', 'premier', 'blista', 'ingot', 'stanier', 'tailgater', 'fugitive', 'primo', 'dilettante', 'emperor' }
Config.TrafficSpeed = 11.0          -- m/s (about 40 km/h)
Config.DrivingStyle = 786603        -- normal, careful driving

-- ===================== v1.0.14: hospital, airport, random events =====================
Config.SpecialVehicles = true       -- ambulances at KBC Osijek, air ambulance on the roof, planes at the airport

-- Random events happen around each player (local, like GTA's random events).
-- Admins can test one: /dogadaj hit_and_run | accident | breakdown | thief | fire | chase
Config.Events = {
    Enabled = true,
    Interval = 120,                 -- every X seconds there is a chance ...
    Chance = 0.4,                   -- ... of 40 % that something happens near you
    MaxActive = 2,
    Cooldown = 600,                 -- the same event at most every 10 minutes
    HitDamage = 35,                 -- hit_and_run damage (player health is 100-200)
    Weights = {                     -- how often each event happens (0 = never)
        accident = 3,
        breakdown = 3,
        fire = 2,
        chase = 2,
        thief = 2,
        hit_and_run = 1,
    },
}

-- ===================== v1.0.16 =====================
Config.TakeVehicles = true          -- press F next to a parked ambulance / plane / heli to drive or fly it
Config.TakenRespawnMinutes = 15     -- a taken one comes back after this time
Config.ArrivalCutscene = true       -- new characters fly into Osijek airport (cutscene)
Config.ArrivalPlane = { 'luxor', 'shamal', 'nimbus', 'velum2' }

Config.NpcTalk = true               -- NPCs greet you when you walk up, press E to talk (English)
Config.NpcGreetings = {
    'Hey there!', 'Hi! Nice day, isn\'t it?', 'Hello, welcome to Osijek!', 'Good morning!', 'Oh, hi! How are you?',
    'Hey, nice to see a new face.', 'Hello! Lovely weather today.', 'Hi, can I help you?',
}
Config.NpcChat = {
    'Have you seen the cathedral? The tower is almost 100 metres tall!',
    'I am on my way to work, the traffic on Europska avenija is crazy.',
    'If you get hurt, KBC Osijek is on Vukovarska street.',
    'The promenade by the Drava is the best place for a walk.',
    'I just flew in, the airport is south of the city.',
    'Did you hear? There was an accident near the park this morning.',
    'Try the beach at Copacabana in the summer!',
    'Sorry, I am in a hurry. See you around!',
    'The old town, Tvrđa, has the best cafés in Osijek.',
    'Be careful, there are pickpockets around here.',
}
