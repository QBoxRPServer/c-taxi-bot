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
    return table.unpack(Citizen.InvokeNative(0xFA7C7F0AADF25D09, waypoint, Citizen.ResultAsVector()))

end


function getVehNodeType(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end

function playTaxiSpeech(driver, speechName, speechParams)
    if not DoesEntityExist(driver) then return false end
    if IsPedFatallyInjured(driver) then return false end
    if not IsPedInAnyVehicle(driver) then return false end
    if IsPedRagdoll(driver) then return false end

    -- Даем педу "проснуться" если он в состоянии покоя
    if GetPedAlertness(driver) < 1.0 then
        SetPedAlertness(driver, 1.0)
    end
    PlayPedAmbientSpeechNative(driver, "GENERIC_INSULT_HIGH"--[[speechName]], "SPEECH_PARAMS_FORCE"--[[speechParam]])
    return true
end

function DrawText2D(text, position, scale, color, font)
    -- значения по умолчанию
    color = color and color or {255,255,255,255}
    font = font and font or 4
    -- Сброс предыдущих настроек
    ClearAllHelpMessages();

    -- Установка стиля
    SetTextFont(font);
    SetTextScale(scale, scale);
    SetTextProportional(true);
    SetTextColour(color[1], color[2], color[3], color[4]);
    SetTextOutline();
    SetTextDropShadow();
    SetTextCentre(true);

    -- Отрисовка
    BeginTextCommandDisplayText('STRING');
    AddTextComponentSubstringPlayerName(text);
    EndTextCommandDisplayText(position[1], position[2]);
end

