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
Config.HospitalDoor = vector3(5170.0, -1878.5, 9.0)    -- KBC Osijek reception (E = treatment)
Config.EmsGarage = vector4(5220.0, -1869.0, 9.0, 270.0) -- EMS players take an ambulance here
Config.HealPrice = 100            -- treatment at the reception
Config.AmbulanceBill = 250        -- bill when the ambulance (AI or EMS) brings you back
Config.EmsReviveReward = 150      -- EMS player gets this (bank) for every revive
Config.EmsWaitSeconds = 90        -- if no EMS player revives you in this time, the AI ambulance comes
Config.AmbulanceModel = 'ambulance'
