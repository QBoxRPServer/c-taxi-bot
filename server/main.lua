-----------------------
----   Variables   ----
-----------------------



-----------------------
----   Functions   ----
-----------------------


-----------------------
----   Events   ----
-----------------------
lib.callback.register('c-taxi:server:payForTaxi', function(source, price)
    local src = source
    if Config.Framework.QBBox() then
        local player = exports['qbx_core']:GetPlayer(src)
        if (player and player.PlayerData) then
            if player.Functions.RemoveMoney('cash', price, GetCurrentResourceName()) or player.Functions.RemoveMoney('bank', price, GetCurrentResourceName())
            then
                return(true)
            else
                TriggerClientEvent('ox_lib:notify', src, {type = 'warning', description = 'Чем ты планируешь платить? Иди сначала продай почку',
                                                          position = "center-right", duration = 7500})
                return(false)
            end
        else
            print("CRITICAL", "Ошибка получения PlayerData")
        end
    end
end)

AddEventHandler("onResourceStop", function(resName)
    if (resName == GetCurrentResourceName()) then

    end
end)

-----------------------
----   Commands    ----
-----------------------

-----------------------
----   Threads   ----
-----------------------






