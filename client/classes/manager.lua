local Manager = lib.class('Manager')
local Vehicle = require 'client.classes.vehicle'  -- Импортируем класс
local TaxiBot = require 'client.classes.taxi_bot'

--- Конструктор
function Manager:constructor()
    self.vehicle = nil
    self.driver =nil

    --[[self.vehicle =  lib.waitFor(function()
        return  Vehicle:new(Config.vehicle_model)
    end)]]
    local playerCoords = GetEntityCoords(PlayerPedId())
    local taxiBot = TaxiBot:new()
    taxiBot:RequestTaxi(playerCoords)
end

return Manager