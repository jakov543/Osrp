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
    -- v1.0.23: smaller street trees that fit the 4-floor houses (the big oaks/cedars only stay in the park)
    av   = { 'prop_tree_maple_03', 'prop_tree_birch_03b', 'prop_tree_birch_04' },  -- Europska avenija
    prom = { 'prop_tree_birch_03', 'prop_tree_birch_04', 'prop_tree_maple_03' },   -- promenada uz Dravu
    park = { 'prop_tree_maple_02', 'prop_tree_birch_01', 'prop_tree_oak_01', 'prop_tree_birch_03' },
    trg  = { 'prop_tree_maple_03', 'prop_tree_birch_03b' },                        -- Tvrđa
}

-- Doors of the houses you can enter: first model that exists in your GTA is used
Config.DoorModels = { 'v_ilev_fh_frontdoor', 'v_ilev_trevtraildr', 'prop_com_ls_door_01' }
Config.DoorsLocked = false            -- true = everyone needs a key (lock them from your own scripts)

-- Furniture inside the houses (first existing model per type)
Config.FurnitureModels = {      -- v1.0.22: first our own Blender furniture (osrpprop_h_*), GTA props as fallback
    -- v1.0.29 GTA props in the hospital, police station and airport
    atm         = { 'prop_atm_01' },
    vend_snack  = { 'prop_vend_snak_01' },
    vend_soda   = { 'prop_vend_soda_01' },
    vend_coffee = { 'prop_vend_coffe_01' },
    bin_in      = { 'prop_bin_08a' },
    wheelchair  = { 'prop_wheelchair_01' },
    -- living room
    sofa    = { 'osrpprop_h_sofa', 'hei_heist_stn_sofa2seat_02', 'v_res_tre_sofa_s', 'prop_couch_01' },
    fotelja = { 'osrpprop_h_fotelja', 'v_res_m_armchair', 'v_res_d_armchair', 'prop_armchair_01' },
    stolic  = { 'osrpprop_h_stolic', 'apa_mp_h_tab_coffee_07', 'apa_mp_h_tab_coffee_08', 'prop_table_04' },
    tepih   = { 'osrpprop_h_tepih', 'apa_mp_h_acc_rugwoolm_01', 'apa_mp_h_acc_rugwooll_03' },
    tvstol  = { 'osrpprop_h_tvstol', 'apa_mp_h_str_avunitm_01', 'prop_tv_cabinet_03' },
    tv      = { 'osrpprop_h_tv', 'prop_tv_flat_01', 'prop_tv_flat_02', 'prop_tv_03' },
    polica  = { 'osrpprop_h_polica', 'apa_mp_h_str_shelffloorm_02', 'v_res_cabinet' },
    slika   = { 'osrpprop_h_slika', 'apa_mp_h_acc_artwalll_01', 'apa_mp_h_acc_artwallm_02' },
    lampa   = { 'osrpprop_h_lampa', 'apa_mp_h_lit_floorlamp_01', 'apa_mp_h_floorlamp_a' },
    stol    = { 'osrpprop_h_stol', 'apa_mp_h_din_table_04', 'v_res_tre_table2', 'prop_table_03' },
    stolica = { 'osrpprop_h_stolica', 'hei_heist_din_chair_01', 'apa_mp_h_din_chair_04', 'prop_chair_01a' },
    biljka  = { 'osrpprop_h_biljka', 'apa_mp_h_acc_plant_tall_01', 'prop_plant_int_01a', 'prop_pot_plant_01a' },
    -- kitchen
    hladnjak = { 'osrpprop_h_hladnjak', 'prop_fridge_01', 'prop_fridge_03' },
    stednjak = { 'osrpprop_h_stednjak', 'v_res_ovenhobmod', 'prop_cooker_03' },
    sudoper  = { 'osrpprop_h_sudoper', 'v_res_m_sinkunit', 'prop_sink_06' },
    ormaric  = { 'osrpprop_h_ormaric', 'prop_cs_kitchen_cab_l', 'prop_cs_kitchen_cab_r' },
    kuh_stol = { 'osrpprop_h_kuh_stol', 'prop_table_03', 'prop_table_04' },
    stolac   = { 'osrpprop_h_stolac', 'v_ilev_fh_kitchenstool', 'prop_chair_04a' },
    -- bathroom
    wc        = { 'osrpprop_h_wc', 'prop_toilet_01', 'prop_toilet_02' },
    umivaonik = { 'osrpprop_h_umivaonik', 'v_res_mbsink', 'prop_sink_02' },
    kada      = { 'osrpprop_h_kada', 'v_res_mbath', 'apa_mp_h_bathtub_01' },
    rucnik    = { 'osrpprop_h_rucnik', 'prop_towel_shelf_01' },
    -- bedroom
    krevet_d     = { 'osrpprop_h_krevet_d', 'apa_mp_h_bed_double_08', 'hei_heist_bed_double_08' },
    nocni        = { 'osrpprop_h_nocni', 'hei_heist_bed_table_dble_04', 'apa_mp_h_bed_table_wide_12' },
    stolna_lampa = { 'osrpprop_h_stolna_lampa', 'apa_mp_h_lit_lamptable_02', 'v_res_desklamp' },
    ormar        = { 'osrpprop_h_ormar', 'v_res_tre_wardrobe' },
    komoda       = { 'osrpprop_h_komoda', 'v_res_mbdresser', 'apa_mp_h_bed_chestdrawer_02' },
    -- hospital / terminal
    automat = { 'prop_vend_snak_01', 'prop_vend_soda_01', 'prop_vend_soda_02' },
    kava    = { 'prop_vend_coffe_01', 'prop_vend_water_01' },
    krevet  = { 'v_med_bed1', 'v_med_emptybed', 'v_med_bed2' },
}
-- furniture models in GTA face backwards (-Y): every piece is turned by this many degrees.
-- If one kind stands the wrong way round in your game, set it here, e.g. Config.FurnitureTurn = { tv = 0.0 }
Config.FurnitureTurnDefault = 180.0
Config.FurnitureTurn = { tepih = 0.0 }


Config.InteriorDistance = 70.0        -- doors/furniture appear within this distance (each flat has ~40 pieces)
Config.InteriorLight = false          -- (old single light) - v1.0.21 has a light in every room

-- ===================== city life (v1.0.11) =====================
Config.CityRadius = 1000.0          -- size of Osijek incl. hospital + airport (metres from the centre)
Config.DrawMap = true               -- landmark blips (hospital, airport ...) on the pause map
Config.MapMode = 'nui'              -- 'nui' = real drawn minimap + big map (F7) | 'blips' = old blip rectangles

Config.ParkedCars = true
Config.ParkedModels = { 'asea', 'premier', 'emperor', 'ingot', 'primo', 'stanier', 'blista', 'dilettante', 'panto', 'issi2', 'rhapsody', 'fugitive' }

Config.SignModels = {
    stop     = { 'osrpprop_sign_stop', 'prop_sign_road_01a', 'prop_sign_road_01b' },        -- v1.0.27: Croatian signs (own models)
    semafor  = { 'prop_traffic_01a', 'prop_traffic_01b', 'prop_traffic_03a' },
    pjesacki = { 'osrpprop_sign_crossing', 'prop_sign_road_05a', 'prop_sign_road_03a' },
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
    -- v1.0.18 plants on the grass
    grm     = { 'prop_bush_med_03', 'prop_bush_lrg_04b', 'prop_bush_med_06', 'prop_bush_lrg_01e' },
    trava   = { 'prop_grass_dry_02', 'prop_grass_dry_03', 'prop_bush_dead_02' },
    -- v1.0.23 real GTA V street light poles (they turn on at night by themselves)
    ulicna_lampa = { 'prop_streetlight_01', 'prop_streetlight_01b' },
    park_lampa   = { 'prop_streetlight_03', 'prop_streetlight_01' },
    -- v1.0.27 road works + closed road
    cunj          = { 'prop_roadcone02a', 'prop_roadcone01a' },
    barijera_rad  = { 'prop_barrier_work05', 'prop_barrier_work06a' },
    barijera      = { 'prop_mp_barrier_02b', 'prop_barrier_work05' },
    mjesalica     = { 'prop_cementmixer_01a' },
    generator     = { 'prop_generator_03b' },
    radno_svjetlo = { 'prop_worklight_03b' },
}
-- extra turn per prop kind, if a GTA model looks the wrong way (e.g. set ulicna_lampa = 180.0 if the lamp arm points away from the road)
Config.SignTurn = { ulicna_lampa = 0.0, park_lampa = 0.0, stop = 180.0, pjesacki = 180.0 }   -- our own sign models face the other way than GTA props

Config.Pedestrians = true
Config.PedCount = 64                -- NPCs walking, jogging, sitting, standing around you (phone, coffee, smoking ...)
Config.PedModels = { 'a_m_y_business_01', 'a_f_y_business_01', 'a_m_m_business_01', 'a_f_y_hipster_01', 'a_m_y_hipster_01',
                     'a_f_m_bevhills_01', 'a_m_y_vinewood_01', 'a_f_y_tourist_01', 'a_m_m_skater_01', 'a_f_y_eastsa_01',
                     'a_m_y_bevhills_01', 'a_f_y_bevhills_02', 'a_m_m_eastsa_02', 'a_f_m_tourist_01', 'a_m_y_runner_01',
                     'a_f_y_runner_01', 'a_m_o_genstreet_01', 'a_f_o_genstreet_01', 'a_m_y_genstreet_01', 'a_f_y_genhot_01',
                     'a_m_m_tourist_01', 'a_m_y_hipster_01', 'a_f_y_hipster_01', 'a_m_m_farmer_01', 'a_f_m_fatwhite_01' }

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

Config.NpcTalk = true               -- NPCs greet you when you walk up, press E to talk (dialog window with answers)
Config.NpcLanguage = 'hr'           -- v1.0.25: language of everything the NPCs say: 'hr' (hrvatski) or 'en' (English)
Config.NpcVoice = true              -- GTA voice sound when they greet you (the GTA voices are always English audio)
Config.NpcGreetings = {
    hr = { 'Bok!', 'Dobar dan!', 'Pozdrav, dobro došli u Osijek!', 'Dobro jutro!', 'O, bok! Kako si?', 'Hej, novo lice u gradu?', 'Lijep dan danas, ha?', 'Mogu li pomoći?' },
    en = { 'Hey there!', 'Hi! Nice day, isn\'t it?', 'Hello, welcome to Osijek!', 'Good morning!', 'Oh, hi! How are you?',
           'Hey, nice to see a new face.', 'Hello! Lovely weather today.', 'Hi, can I help you?' },
}
Config.NpcChat = {
    hr = { 'Jesi vidio konkatedralu? Toranj je visok skoro 100 metara!', 'Šetnica uz Dravu je najljepša za šetnju.', 'Pazi se, ima džepara okolo.' },
    en = { 'Have you seen the cathedral? The tower is almost 100 metres tall!', 'The promenade by the Drava is the best place for a walk.',
           'Be careful, there are pickpockets around here.' },
}

-- ===================================================================== v1.0.18
Config.BenchModels = { 'prop_bench_01a', 'prop_bench_05', 'prop_bench_09' }   -- E = sit (NPCs sit too)
Config.FountainParticle = 'ent_amb_fountain_pour'                              -- water jets of the Tvrđa fountain

-- ===================================================================== v1.0.20
Config.Cyclists = 8                 -- NPCs riding bikes on the Drava bike paths
Config.CyclistSpeed = 6.0           -- m/s (about 22 km/h)
Config.JoggerShare = 0.35           -- part of the people on the promenades who jog

-- v1.0.27 Croatian police livery (white car, blue RAL 5013 band, POLICIJA). TEST: it replaces GTA's police3 livery
-- texture at runtime. GTA maps that texture in its own way, so if it looks wrong set Enabled = false and send us the
-- original pol3_sign_1 texture from OpenIV (police3.ytd) - then the livery is painted exactly on its layout.
Config.PoliceLivery = {
    Enabled = true,
    Replace = { { txd = 'police3', tex = 'pol3_sign_1' }, { txd = 'police3+hi', tex = 'pol3_sign_1' } },
    Image = 'html/livery/policija_hr.png',
    Models = { 'police3', 'police', 'policet' },
    Colour = 111,                -- white body (GTA paint index) on the station's police cars
}

-- v1.0.33 BULET e-scooters (rent at the green stations, E). Prices are charged by osrp_framework.
Config.Bulet = {
    PerStation = 4,           -- scooters at each station
    RefillSeconds = 120,      -- a rented scooter comes back to its station after this
    Unlock = 2, PerMinute = 1,   -- $ to unlock + $ per started minute (keep the same in osrp_framework/server/shop.lua)
    MaxSpeed = 25.0,          -- km/h (like a real e-scooter)
    Accel = 2.2, Brake = 6.0, TurnRate = 75.0,
    BatteryDrain = 0.12,      -- % per second while driving
    BaseVehicle = 'rcbandito',  -- hidden small car that does the physics under the scooter
    PropZ = -0.32, PedZ = 0.88,  -- height of the scooter model / of you on it (tune if it floats or sinks)
    AnimDict = 'anim@heists@box_carry@', AnimName = 'idle',   -- standing with hands forward on the handlebar
    HandIK = true,                       -- v1.0.37: hands locked on the grips, head looks into turns
    LeanDeg = 12.0, PitchDeg = 5.0,  -- v1.0.37 own riding animation: lean into turns / forward + back
}
