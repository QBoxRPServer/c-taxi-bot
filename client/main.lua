-----------------------
----   Variables   ----
-----------------------
local Manager = require 'client.classes.manager'  -- Импортируем класс
local manager








-----------------------
----   Functions   ----
-----------------------


-----------------------
----   Events   ----
-----------------------
RegisterNetEvent('c-taxi-bot:client:callVehicle', function()
       manager = Manager:new()
      --exports['c-logger']:Log("WARNING", "Ошибка при обращении к getMissionData",GetCurrentResourceName())
end)

AddEventHandler("onResourceStop", function(resName)
       if (resName == GetCurrentResourceName()) then
              if not manager then return end
              manager.taxi_bot:Cleanup();
       end
end)

-----------------------
----   Commands    ----
-----------------------

-----------------------
----   Threads   ----
-----------------------






