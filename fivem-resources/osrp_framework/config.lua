Config = {}

-- Where new players and respawns appear (change to your Osijek map later)
Config.Spawn = vector4(-1037.74, -2737.9, 20.17, 330.0)      -- airport (until Osijek map is in)
Config.Hospital = vector4(298.6, -584.5, 43.26, 70.0)        -- respawn after death

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
