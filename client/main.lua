-----------------------
----   Variables   ----
-----------------------
local TaxiBot = require 'client.classes.taxi_bot'  -- Импортируем класс
local taxi_bot = nil








-----------------------
----   Functions   ----
-----------------------


-----------------------
----   Events   ----
-----------------------
RegisterNetEvent('c-taxi-bot:client:callVehicle', function()
       if not taxi_bot then
              local playerCoords = GetEntityCoords(PlayerPedId())
              taxi_bot = TaxiBot:new()
              taxi_bot:RequestTaxi(playerCoords)
       else
              if taxi_bot.state == "idle" or  taxi_bot.state == "driving" then
                     taxi_bot:Cleanup()
              else
                     lib.notify({type = 'warning', description = 'Вы уже в машине', duration =5500})
              end
       end

      --exports['c-logger']:Log("WARNING", "Ошибка при обращении к getMissionData",GetCurrentResourceName())
end)

AddEventHandler("onResourceStop", function(resName)
       if (resName == GetCurrentResourceName()) then
              print("manager.taxi_bot", taxi_bot)
              if taxi_bot and taxi_bot then print("taxi_bot", taxi_bot) end
              if taxi_bot then return end
              taxi_bot:Cleanup();
       end
end)

-----------------------
----   Commands    ----
-----------------------

-----------------------
----   Threads   ----
-----------------------






