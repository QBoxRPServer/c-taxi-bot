function getStoppingLocation(coords)
    local _, nCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    return nCoords
end


function GetWaypoint()

    local waypoint
    while not DoesBlipExist(waypoint) do
        waypoint = GetFirstBlipInfoId(8)
        Citizen.Wait(500)
    end
    print("GetWaypoint +++")
    return table.unpack(Citizen.InvokeNative(0xFA7C7F0AADF25D09, waypoint, Citizen.ResultAsVector()))

end


function getVehNodeType(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end