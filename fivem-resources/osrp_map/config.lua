Config = {}

-- Short names -> real GTA V props. A list = random pick (trees look natural that way).
-- Any GTA V prop name also works directly, e.g. /prop prop_streetlight_03
Config.Presets = {
    lampa  = { 'prop_streetlight_01' },                 -- classic city street light (lights up at night)
    lampa2 = { 'prop_streetlight_03' },                 -- modern street light
    drvo   = { 'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_maple_02', 'prop_tree_maple_03', 'prop_tree_oak_01' },
    bor    = { 'prop_tree_cedar_02', 'prop_tree_pine_01' },
    grm    = { 'prop_bush_lrg_04b', 'prop_bush_med_03' },
    klupa  = { 'prop_bench_01a', 'prop_bench_05' },
    kanta  = { 'prop_bin_01a', 'prop_bin_07a' },
    hidrant = { 'prop_fire_hydrant_1' },
    stup   = { 'prop_bollard_02a' },                    -- small posts that keep cars off the sidewalk
    posta  = { 'prop_postbox_01a' },
    fontana = { 'prop_fountain2', 'prop_fountain1' },   -- falls back to a tree if missing
}

-- Template settings for /predlozak (meters)
Config.Templates = {
    ulica = { length = 120, width = 14 },   -- /predlozak ulica [dužina] [širina ceste]
    trg = { radius = 18 },                  -- /predlozak trg [radijus]
    park = { width = 40, length = 60 },     -- /predlozak park [širina] [dužina]
    promenada = { length = 150 },           -- /predlozak promenada [dužina]  (props on your LEFT side)
}

Config.StreamDistance = 250.0   -- props appear within this distance (meters) - keeps FPS high
Config.MaxProps = 3000          -- safety limit for the whole map
Config.SideOffset = 7.0         -- /proplinija both sides: distance from your line to each side (meters)
