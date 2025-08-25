Config = {}
Config = {
    vehicle_model = "taxi"
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