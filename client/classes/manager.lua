local Manager = lib.class('Manager')
local TaxiBot = require 'client.classes.taxi_bot'

--- Конструктор
function Manager:constructor()
    self.taxiBot = nil
    self.driver =nil

    --[[self.vehicle =  lib.waitFor(function()
        return  Vehicle:new(Config.vehicle_model)
    end)]]
    local playerCoords = GetEntityCoords(PlayerPedId())
    self.taxiBot = TaxiBot:new()
    self.taxiBot:RequestTaxi(playerCoords)
end

return Manager