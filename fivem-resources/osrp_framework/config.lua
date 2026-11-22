Config = {}

-- Where new players and respawns appear (change to your Osijek map later)
Config.Spawn = vector4(5675.0, -1511.0, 9.0, 90.0)          -- Osijek, Europska avenija (osrp_osijek)
Config.Hospital = vector4(5170.0, -1873.5, 9.0, 0.0)         -- Osijek, in front of KBC Osijek (respawn after death)

-- Saved positions further than this from Config.Spawn (e.g. still in Los Santos) are ignored:
-- the player spawns in Osijek instead.
Config.CityRadius = 1100.0

Config.StartCash = 500
Config.StartBank = 2000

-- Jobs: name = { label, salary per payday }
Config.Jobs = {
    unemployed = { label = 'Nezaposlen', salary = 50 },
    police     = { label = 'Policija',   salary = 300 },
    ems        = { label = 'Hitna',      salary = 280 },
    mechanic   = { label = 'Mehaničar',  salary = 220 },
    taxi       = { label = 'Taxi',       salary = 180 },
}

Config.PaydayMinutes = 10          -- salary goes to bank every X minutes
Config.RespawnSeconds = 15         -- how long before you can respawn after death
Config.MeDistance = 20.0           -- /me /do visible distance (meters)
Config.DisableWanted = true        -- no GTA police wanted stars (roleplay police only)

-- ---------- v1.0.14: hospital + ambulance ----------
Config.HospitalDoor = vector3(5170.0, -1891.6, 9.25)   -- KBC Osijek reception desk in the lobby (E = treatment)
Config.EmsGarage = vector4(5220.0, -1869.0, 9.0, 270.0) -- EMS players take an ambulance here
Config.HealPrice = 100            -- treatment at the reception
Config.AmbulanceBill = 250        -- bill when the ambulance (AI or EMS) brings you back
Config.EmsReviveReward = 150      -- EMS player gets this (bank) for every revive
Config.EmsWaitSeconds = 90        -- if no EMS player revives you in this time, the AI ambulance comes
Config.AmbulanceModel = 'ambulance'

-- ---------- v1.0.16: characters + spawn ----------
Config.MaxCharacters = 3          -- characters per player (multicharacter)
-- spawn choices after picking a character (world coords). 'arrival' = fly in with the plane (osrp_osijek cutscene)
Config.SpawnPoints = {
    { id = 'last',     label = 'Zadnja lokacija',             icon = '📍', desc = 'Tamo gdje si zadnji put bio.' },
    { id = 'arrival',  label = 'Zračna luka (dolazak avionom)', icon = '✈️', desc = 'Sletiš u Osijek s avionom.', coords = vector4(5710.0, -1953.0, 9.0, 0.0) },
    { id = 'avenija',  label = 'Europska avenija',            icon = '🏙️', desc = 'Centar grada.', coords = vector4(5675.0, -1511.0, 9.0, 90.0) },
    { id = 'tvrdja',   label = 'Tvrđa',                       icon = '⛪', desc = 'Stari grad i konkatedrala.', coords = vector4(5725.0, -1462.0, 9.0, 180.0) },
    { id = 'bolnica',  label = 'KBC Osijek',                  icon = '🏥', desc = 'Ispred bolnice.', coords = vector4(5170.0, -1873.5, 9.0, 0.0) },
}
Config.Nationalities = { 'Hrvatska', 'Bosna i Hercegovina', 'Srbija', 'Slovenija', 'Crna Gora', 'Mađarska', 'Austrija', 'Njemačka', 'Italija', 'Ostalo' }

-- outfits in the character creator: component = { drawable, texture } (11 top, 3 arms, 8 undershirt, 4 legs, 6 shoes)
Config.Outfits = {
    m = {
        { [11] = { 0, 0 }, [3] = { 0, 0 }, [8] = { 15, 0 }, [4] = { 1, 0 }, [6] = { 1, 0 } },     -- t-shirt + jeans
        { [11] = { 7, 0 }, [3] = { 0, 0 }, [8] = { 15, 0 }, [4] = { 0, 0 }, [6] = { 7, 0 } },     -- jacket
        { [11] = { 10, 0 }, [3] = { 4, 0 }, [8] = { 10, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 } },  -- suit
        { [11] = { 14, 0 }, [3] = { 1, 0 }, [8] = { 15, 0 }, [4] = { 5, 0 }, [6] = { 9, 0 } },    -- sport
    },
    f = {
        { [11] = { 0, 0 }, [3] = { 0, 0 }, [8] = { 15, 0 }, [4] = { 0, 0 }, [6] = { 0, 0 } },
        { [11] = { 3, 0 }, [3] = { 3, 0 }, [8] = { 15, 0 }, [4] = { 1, 0 }, [6] = { 1, 0 } },
        { [11] = { 6, 0 }, [3] = { 5, 0 }, [8] = { 15, 0 }, [4] = { 6, 0 }, [6] = { 6, 0 } },
        { [11] = { 9, 0 }, [3] = { 0, 0 }, [8] = { 15, 0 }, [4] = { 3, 0 }, [6] = { 3, 0 } },
    },
}
