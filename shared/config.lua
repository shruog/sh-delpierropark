--[[
    Shared Configuration
    All coordinates, models, and tunable settings
]]

Config = {}

-- 
-- FERRIS WHEEL
-- 
Config.FerrisWheel = {
    Position       = vector3(-1663.97, -1126.7, 30.7),
    BoardingPoint  = vector3(-1661.95, -1127.011, 12.6973),
    BoardingRadius = 1.375,
    ProximityRadius = 20.0,

    Model          = `prop_ld_ferris_wheel`,
    CabinModel     = `prop_ferris_car_01`,
    AnimDict       = "anim@mp_ferris_wheel",
    CabinCount     = 16,
    Speed          = 5.0,      -- degrees-ish per tick factor (2.0 in vanilla scripts)

    Blip = {
        Sprite     = 266,      -- BlipSprite.Fairground
        ShortRange = true,
        Name       = "Ferris Wheel",
        Display    = 4,
    },

    AudioScenes = {
        Main = "FAIRGROUND_RIDES_FERRIS_WHALE",
        Alt  = "FAIRGROUND_RIDES_FERRIS_WHALE_ALTERNATIVE_VIEW",
    },
    SoundSet = "THE_FERRIS_WHALE_SOUNDSET",
    AudioBanks = {
        "SCRIPT\\FERRIS_WHALE_01",
        "SCRIPT\\FERRIS_WHALE_02",
        "THE_FERRIS_WHALE_SOUNDSET",
    },

    CamFar = {
        Pos = vector3(-1703.854, -1082.222, 42.006),
        Rot = vector3(-8.3096, 0.0, -111.8213),
        Fov = 50.0,
    },
}

-- 
-- ROLLER COASTER
-- 
Config.RollerCoaster = {
    AnimDict       = "anim@mp_rollarcoaster",
    CarModel       = `ind_prop_dlc_roller_car`,
    CarModel2      = `ind_prop_dlc_roller_car_02`,
    CarCount       = 4,
    WaitTime       = 30,       -- seconds to wait before departing

    Blip = {
        Position   = vector3(-1651.641, -1134.325, 21.90398),
        Sprite     = 266,
        ShortRange = true,
        Name       = "Roller Coaster",
        Display    = 4,
    },

    -- Positions where players can board (pairs: odd index = seat two offset)
    BoardingPositions = {
        vector3(-1644.316, -1123.53,  17.3447),
        vector3(-1644.92,  -1124.281, 17.3447),
        vector3(-1645.845, -1125.413, 17.3447),
        vector3(-1646.562, -1126.302, 17.3447),
        vector3(-1647.498, -1127.438, 17.3447),
        vector3(-1648.23,  -1128.184, 17.3447),
        vector3(-1649.233, -1129.399, 17.3447),
        vector3(-1649.937, -1130.203, 17.3447),
    },

    ExitPositions = {
        vector3(-1641.914, -1125.268, 17.3424),
        vector3(-1642.606, -1126.24,  17.3424),
        vector3(-1643.573, -1127.39,  17.3424),
        vector3(-1644.271, -1128.2,   17.3424),
        vector3(-1645.343, -1129.313, 17.3424),
        vector3(-1645.966, -1130.067, 17.3424),
        vector3(-1647.022, -1131.291, 17.3424),
        vector3(-1647.645, -1132.016, 17.3424),
    },

    -- Models to auto-delete (the vanilla yellow carts)
    DeleteModels = {
        "prop_roller_car_01",
        "prop_roller_car_02",
    },

    BoardingRadius = 1.3,
    ProximityRadius = 30.0,
    ProximityCenter = vector3(-1646.863, -1125.135, 17.338),
}

-- 
-- HELPERS
-- 
function Config.ConvertDegreesToRadians(angle)
    return (math.pi / 180.0) * angle
end

function Config.ConvertRadiansToDegrees(radians)
    return (180.0 / math.pi) * radians
end
