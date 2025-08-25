RegisterCommand('ctaxi', function(source, args)
    local src = source
    TriggerClientEvent('c-taxi-bot:client:callVehicle', src)
end, false)