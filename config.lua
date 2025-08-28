Config = {}
Config = {
    price_per_landing = 25, --price per landing
    price_per_second = 1, --price per landing
    vehicle_model = "taxi"
}
Config.SpeedLimitZones = { -- Speeds in MPH
    [2] = 40, -- City / main roads
    [10] = 30, -- Slow roads
    [64] = 25, -- Off road
    [66] = 60, -- Freeway
    [82] = 60, -- Freeway tunnels
}
Config.DrivingStyles = { -- See https://vespura.com/fivem/drivingstyle/
    normal = {
            style = 786607,--786603,--524731,
            speedMult = 1.0,
            aggressiveness = 0.5,
    },
    rush = {
            style = 787263,
            speedMult = 1.5,
            aggressiveness = 0.75,
    },
}

Config.Framework = {}

function Config.Framework.ESX()
    return GetResourceState("es_extended") ~= "missing"
end

function Config.Framework.QBCore()
    return GetResourceState("qb-core") ~= "missing"
end

function Config.Framework.QBBox()
    return GetResourceState("qbx_core") ~= "missing"
end