Config = {}

-- Where Osijek sits in the GTA world: open sea east of Los Santos, 30 m above the water
Config.Origin = vector3(5500.0, -1500.0, 30.0)

-- Spawn point in Osijek (Europska avenija, next to Tvrđa). Put this in
-- osrp_framework/config.lua -> Config.Spawn once the map works:
--   Config.Spawn = vector4(5675.0, -1511.0, 31.0, 90.0)
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
    stol    = { 'prop_table_03', 'prop_table_04', 'v_res_tre_table2' },
    stolica = { 'prop_chair_01a', 'prop_chair_04a', 'v_res_tre_chair' },
    tv      = { 'prop_tv_flat_01', 'prop_tv_03', 'prop_tv_06' },
    biljka  = { 'prop_plant_int_01a', 'prop_pot_plant_01a', 'prop_plant_01a' },
}

Config.InteriorDistance = 120.0       -- doors/furniture appear within this distance
Config.InteriorLight = true           -- warm ceiling light in each house (always on)
