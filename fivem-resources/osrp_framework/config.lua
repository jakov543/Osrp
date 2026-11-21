Config = {}

-- Where new players and respawns appear (change to your Osijek map later)
Config.Spawn = vector4(5675.0, -1511.0, 31.0, 90.0)          -- Osijek, Europska avenija (osrp_osijek)
Config.Hospital = vector4(5700.0, -1470.0, 31.0, 180.0)       -- Osijek, Tvrđa square (respawn after death)

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
