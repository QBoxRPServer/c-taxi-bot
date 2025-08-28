local TaxiBot = {}
TaxiBot.__index = TaxiBot

function TaxiBot:new(model, driverModel)
    local obj = setmetatable({}, self)
    obj.model = model or "taxi"
    obj.driverModel = driverModel or "IG_RussianDrunk"
    obj.state = "idle" -- idle, spawning, driving, arrived, finished
    obj.attempts = 0
    obj.maxAttempts = 3
    obj.plate = nil

    return obj
end

function TaxiBot:RequestTaxi(playerCoords)
    if self.state ~= "idle" then
        lib.notify({type = 'error', description = 'Такси уже вызвано'})
        return false
    end

    self.state = "spawning"
    self.playerCoords = playerCoords
    self.attempts = 0

    lib.notify({type = 'info', description = 'Ищем машинку поблизости...', duration = 2500})

    self:FindSpawnPositionAndSpawn()
    return true
end

function TaxiBot:FindNearestRoadNode(coords, maxDistance)
    maxDistance = maxDistance or 50.0 -- Максимальное расстояние поиска

    local found = false
    local roadCoords = coords
    local heading = 0.0

    -- Пытаемся найти ближайшую дорогу
    local nodeType = 1 -- 1 = vehicles, 2 = peds, etc.

    -- Первый метод: GetNthClosestVehicleNode
    local success, nodePosition, nodeHeading = GetNthClosestVehicleNode(
            coords.x, coords.y, coords.z,
            0, -- Самый близкий узел
            nodeType,
            0, 0
    )

    if success and nodePosition then
        local distance = #(coords - nodePosition)
        if distance <= maxDistance then
            found = true
            roadCoords = vector4(nodePosition.x, nodePosition.y, nodePosition.z, GetEntityHeading(PlayerPedId()))
            print("[FindNearestRoadNode] Найден дорожный узел, расстояние: " .. distance .. "м")
        end
    end

    -- Второй метод: GetClosestVehicleNodeWithHeading (если первый не сработал)
    if not found then
        success, nodePosition, nodeHeading = GetClosestVehicleNodeWithHeading(
                coords.x, coords.y, coords.z,
                nodeType,
                0, 0
        )

        if success and nodePosition then
            local distance = #(coords - nodePosition)
            if distance <= maxDistance then
                found = true
                roadCoords = vector4(nodePosition.x, nodePosition.y, nodePosition.z, nodeHeading)
                print("[FindNearestRoadNode] Найден дорожный узел (метод 2), расстояние: " .. distance .. "м")
            end
        end
    end

    -- Третий метод: GetRoadSidePointWithHeading (для обочин)
    if not found then
        success, nodePosition, nodeHeading = GetRoadSidePointWithHeading(
                coords.x, coords.y, coords.z,
                0 -- Флаг
        )

        if success and nodePosition then
            local distance = #(coords - nodePosition)
            if distance <= maxDistance then
                found = true
                roadCoords = vector4(nodePosition.x, nodePosition.y, nodePosition.z, nodeHeading)
                print("[FindNearestRoadNode] Найден узел на обочине, расстояние: " .. distance .. "м")
            end
        end
    end

    if not found then
        print("[FindNearestRoadNode] Не удалось найти подходящий дорожный узел в радиусе " .. maxDistance .. "м")
        -- Возвращаем оригинальные координаты, но ищем землю под ними
        local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        if groundFound then
            roadCoords = vector4(coords.x, coords.y, groundZ + 0.5, GetEntityHeading(PlayerPedId()) or 0.0)
        else
            roadCoords = vector4(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()) or 0.0)
        end
    end

    return roadCoords
end

function TaxiBot:FindSpawnPositionAndSpawn()
    -- Ищем позицию для спавна в 150-200 метрах от игрока
    local searchRadius = 150.0
    local found = false
    local spawnCoords = nil

    while not found and self.attempts < self.maxAttempts do
        self.attempts = self.attempts + 1

        -- Генерируем случайную точку вокруг игрока
        local randomAngle = math.random() * math.pi * 2
        local randomDistance = math.random(150, 200)
        local randomOffset = vector3(
                math.cos(randomAngle) * randomDistance,
                math.sin(randomAngle) * randomDistance,
                0
        )

        local potentialCoords = self.playerCoords + randomOffset
        -- Ищем ближайший дорожный узел
        spawnCoords = self:FindNearestRoadNode(potentialCoords, 50.0)

        -- Проверяем, что путь до игрока существует
        if self:IsPathValid(spawnCoords, self.playerCoords) then
            found = true
            print("[TaxiBot] Найдена подходящая позиция для спавна такси")
            break
        end

        Citizen.Wait(0)
    end

    if found and spawnCoords then
        self:SpawnTaxi(spawnCoords)
    else
        lib.notify({type = 'error', description = 'Не удалось найти подходящий маршрут для такси'})
        self.state = "idle"
    end
end

function TaxiBot:IsPathValid(startCoords, endCoords)
    -- Проверяем возможность построения маршрута
    local success = CalculateTravelDistanceBetweenPoints(
            startCoords.x, startCoords.y, startCoords.z,
            endCoords.x, endCoords.y, endCoords.z,
            0.0, 0
    )

    return success > 0 and success < 1000.0 -- Максимальная дистанция 1км
end

function TaxiBot:SpawnTaxi(spawnCoords)
    -- Загружаем модель такси
    local modelHash = joaat(self.model)

    if not lib.requestModel(modelHash, 5000) then
        lib.notify({type = 'error', description = 'Ошибка загрузки модели такси'})
        self.state = "idle"
        return
    end

    -- Создаем такси
    local vehicle = CreateVehicle(
            modelHash,
            spawnCoords.x,
            spawnCoords.y,
            spawnCoords.z + 0.5,
            spawnCoords.w or 0.0,
            true,
            false
    )

    if not DoesEntityExist(vehicle) then
        lib.notify({type = 'error', description = 'Ошибка создания такси'})
        self.state = "idle"
        return
    end

    self.vehicle = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleColours(vehicle, 88, 88) -- Желтый цвет для такси
    self.plate = "TAXI " .. math.random(100, 999)
    SetVehicleNumberPlateText(vehicle, self.plate)

    -- Создаем водителя
    self:CreateDriver()

    -- Настраиваем blip
    self:SetupBlip()
    lib.notify({
        type = 'success',
        description = 'Такси c номером '..self.plate..' выехало к вам! Ожидайте прибытия',
        duration = 5000
    })
    -- Начинаем движение к игроку
    self.state = "driving"
    self:DriveToPlayer()


end

function TaxiBot:CreateDriver()
    local driverHash = joaat(self.driverModel)

    if not lib.requestModel(driverHash, 3000) then
        print("[DEBUG] Ошибка загрузки модели водителя")
        return
    end

    local driver = CreatePedInsideVehicle(
            self.vehicle,
            4,
            driverHash,
            -1,
            true,
            false
    )

    if driver and DoesEntityExist(driver) then
        self.driver = driver
        SetEntityAsMissionEntity(driver, true, true)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedFleeAttributes(driver, 0, false)
        SetPedKeepTask(driver, true)
        SetDriverAbility(driver, 1.0) -- Максимальное умение вождения
        SetDriverAggressiveness(driver, 0.1) -- Минимальная агрессивность

        -- Одеваем как таксиста
        SetPedComponentVariation(driver, 3, 0, 0, 0) -- Руки
        SetPedComponentVariation(driver, 4, 21, 0, 0) -- Брюки
        SetPedComponentVariation(driver, 8, 59, 0, 0) -- Рубашка
        SetPedComponentVariation(driver, 11, 55, 0, 0) -- Куртка
    end
end

function TaxiBot:SetupBlip()
    if self.blip then RemoveBlip(self.blip) end

    self.blip = AddBlipForEntity(self.vehicle)
    SetBlipSprite(self.blip, 198) -- Иконка такси
    SetBlipColour(self.blip, 5) -- Желтый цвет
    SetBlipScale(self.blip, 0.8)
    SetBlipDisplay(self.blip, 4)
    SetBlipCategory(self.blip, 10)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Такси")
    EndTextCommandSetBlipName(self.blip)
end

function TaxiBot:DriveToPlayer()
    if not self.driver or not DoesEntityExist(self.driver) then
        self:Cleanup()
        return
    end
    local new_coords = getStoppingLocation(GetEntityCoords(PlayerPedId()))
    -- Настраиваем вождение
    TaskVehicleDriveToCoord(
            self.driver,
            self.vehicle,
            new_coords.x,
            new_coords.y,
            new_coords.z,
            10.0, -- Скорость
            0, -- Параметры вождения
            GetEntityModel(self.vehicle),
            Config.DrivingStyles.rush.style,--786603, -- Стиль вождения (аккуратный)
            5.0, -- Дистанция остановки
            true -- Остановиться точно в точке
    )

    -- Запускаем мониторинг прибытия
    self:MonitorArrival(new_coords)
end

function TaxiBot:DriveTo(x,y,z)
    if not self.driver or not DoesEntityExist(self.driver) then
        self:Cleanup()
        return
    end
    local speed = 20.0
    local new_coords = getStoppingLocation(vec3(x,y,z))
    --[[-- Настраиваем вождение
    TaskVehicleDriveToCoord(
            self.driver,
            self.vehicle,
            new_coords.x,
            new_coords.y,
            new_coords.z,
            speed,
            0, -- Параметры вождения
            GetEntityModel(self.vehicle),
            786603, -- Стиль вождения (аккуратный)
            11.0, -- Дистанция остановки
            false -- Остановиться точно в точке
    )]]

    -- Запускаем мониторинг прибытия
    self:MonitorArrival(new_coords)
end

function TaxiBot:MonitorArrival(coords)
    if self.state == "driving" then
        while self.state == "driving"  do
            Citizen.Wait(1000)

            if not self:IsValid() then
                self:Cleanup()
                return
            end

            local taxiCoords = GetEntityCoords(self.vehicle)

            local distance = #(taxiCoords - coords)--self.playerCoords)
            -- Обновляем blip при приближении
            if distance < 100 then
                SetBlipScale(self.blip, 1.0)
            end

            -- Проверяем прибытие
            if distance < 15.0 then
                if GetIsTaskActive(self.driver, 169) or GetIsTaskActive(self.driver, 167) then
                    -- Водитель все еще едет, ждем
                else
                    -- Прибыли!
                    if self.state == "driving" then
                        self.state = "arrived"
                    elseif self.state == "in_trip" then
                        self.state = "trip_complete"
                    end
                    self:OnArrival()
                    break
                end
            end

            -- Проверяем застревание
            local speed = GetEntitySpeed(self.vehicle) * 3.6 -- км/ч
            if speed < 5.0 then
                self.stuckTimer = (self.stuckTimer or 0) + 1
                if self.stuckTimer > 30 then -- Застрял на 30 секунд
                    self:HandleStuck()
                    self.stuckTimer = 0
                end
            else
                self.stuckTimer = 0
            end
        end
    else
        local taxiCoords = GetEntityCoords(self.vehicle)
        local flags = getVehNodeType(taxiCoords)
        local speed = 20.0
        while self.state == "in_trip"  do
            Citizen.Wait(1000)

            if not self:IsValid() then
                self:Cleanup()
                return
            end

            taxiCoords = GetEntityCoords(self.vehicle)
            local newFlags = getVehNodeType(taxiCoords)

            if newFlags ~= flags then
                local limit = Config.SpeedLimitZones[newFlags] and Config.SpeedLimitZones[newFlags] or 20.0
                speed = limit *Config.DrivingStyles.normal.speedMult
                flags = newFlags
            end
            local distance = #(taxiCoords - coords)
            if distance >= 100 then
                TaskVehicleDriveToCoord(
                        self.driver,
                        self.vehicle,
                        coords.x,
                        coords.y,
                        coords.z,
                        speed,
                        0, -- Параметры вождения
                        GetEntityModel(self.vehicle),
                        786603, -- Стиль вождения (аккуратный)
                        11.0, -- Дистанция остановки
                        false -- Остановиться точно в точке
                )
            elseif distance < 100 and distance > 16.0 then
                TaskVehicleDriveToCoordLongrange(self.driver, self.vehicle, coords.x, coords.y, coords.z,
                    10.0, Config.DrivingStyles.normal.style, 1.0)
                SetPedKeepTask(self.driver, true)


            -- Проверяем прибытие
            elseif distance <= 16.0 then
                if GetIsTaskActive(self.driver, 169) or GetIsTaskActive(self.driver, 167) then
                    print("[DEBUG] Водитель все еще едет, ждем")
                    -- Водитель все еще едет, ждем
                    ClearPedTasks(self.driver)
                else
                    print("[DEBUG] Поездка завершена")
                    if self.state == "in_trip" then
                        self.state = "trip_complete"
                    end
                    self:OnArrival()
                    break
                end
            end
        end
    end
end

function TaxiBot:OnArrival()
    -- Останавливаемся
    TaskVehicleTempAction(self.driver, self.vehicle, 6, 5000) -- Остановка на 5 секунд
    SetVehicleEngineOn(self.vehicle, true, true, false)
    if self.state == "arrived" then
        lib.notify({
            type = 'success',
            description = 'Такси прибыло! Подойдите к машине',
            duration = 7000
        })

        -- Мигаем фарами
        self:FlashLights()

        -- Запускаем таймер ожидания
        self:StartWaitingTimer()
    elseif self.state == "trip_complete" then
        PlayPedAmbientSpeechNative(self.driver, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
        Wait(1500)
        lib.notify({
            type = 'success',
            description = 'Поездка завершена',
            duration = 7000
        })
        TaskLeaveVehicle(PlayerPedId(), self.vehicle, 1)
        Wait(1500)
        StartVehicleHorn(self.vehicle, 1500, 0, true)
        ClearPedTasks(self.driver)
        SetEntityAsNoLongerNeeded(self.driver)
        SetEntityAsNoLongerNeeded(self.vehicle)
        Wait(15000)
        self:Cleanup()
    end

end

function TaxiBot:FlashLights()
    for i = 1, 2 do
        SetVehicleLights(self.vehicle, 2) -- Вкл
        Citizen.Wait(300)
        SetVehicleLights(self.vehicle, 0) -- Выкл
        Citizen.Wait(300)
    end
    SetVehicleLights(self.vehicle, 1) -- Нормальный режим
end

function TaxiBot:SeatToVehicle()
    --[[if (AreAnyVehicleSeatsFree(self.vehicle)) then
        for i = -1, GetVehicleModelNumberOfSeats(self.vehicle) do
            if (IsVehicleSeatFree(self.vehicle, i)) then
                SetVehicleDoorsLocked(self.vehicle, 1)
                TaskEnterVehicle(PlayerPedId(), self.vehicle, -1, i, 1,1,0)
                return true
            end
        end
    else
        return false
    end]]
    if (AreAnyVehicleSeatsFree(self.vehicle)) then
        for i = 2, 1, -1 do
            if IsVehicleSeatFree(self.vehicle, i) then
                SetVehicleDoorsLocked(self.vehicle, 1)
                TaskEnterVehicle(PlayerPedId(), self.vehicle, 5000, i, 1.0, 1, 0)
                return true
            end
        end
    else
        return false
    end
end

function TaxiBot:StartWaitingTimer()
    local waitTime = 120 -- 2 минуты ожидания
    local startTime = GetGameTimer()

    while self.state == "arrived" do
        Citizen.Wait(1000)

        --todo проверяем садится ли игрок в такси
        if (GetVehiclePedIsTryingToEnter(PlayerPedId()) == self.vehicle) then
            if not self:SeatToVehicle() then
                return
            end
        end
        -- Проверяем, сел ли игрок в такси
        if IsPedInVehicle(PlayerPedId(), self.vehicle, false) then
            self:StartTrip()
            return
        end

        -- Проверяем таймаут ожидания
        if GetGameTimer() - startTime > waitTime * 1000 then
            lib.notify({type = 'info', description = 'Такси уехало из-за долгого ожидания'})
            self:Cleanup()
            return
        end

        -- Обновляем уведомление каждые 30 секунд

        local remaining = waitTime - math.floor((GetGameTimer() - startTime) / 1000)
        if remaining % 30 == 0 then
            lib.notify({
                type = 'info',
                description = 'Такси ждет вас! Осталось: ' .. remaining .. ' сек',
                duration = 5000
            })
        end
    end
end





function TaxiBot:StartTrip()
    self.state = "in_trip"
    PlayPedAmbientSpeechNative(self.driver,
            "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
    lib.notify({
        type = 'inform',
        description = 'Что бы начать поездку, скажите водителю куда ехать',
        duration = 5000
    })
    local tx, ty, tz = GetWaypoint()
    if tx and ty and tz then
        self.state = "in_trip"
        lib.notify({
            type = 'success',
            description = 'Поездка началась! Для принудительной отмены нажмите Backspace',
            duration = 5000
        })
        self:DriveTo(tx, ty, tz)
    end
end

function TaxiBot:HandleStuck()
    print("[TaxiBot] Такси застряло, пытаемся решить проблему...")

    -- Пытаемся выехать
    TaskVehicleTempAction(self.driver, self.vehicle, 32, 2000) -- Рывок вперед
    Citizen.Wait(2500)

    -- Если все еще застряли, пересчитываем маршрут
    local currentCoords = GetEntityCoords(self.vehicle)
    if GetEntitySpeed(self.vehicle) * 3.6 < 2.0 then
        self:DriveToPlayer() -- Перезапускаем движение
    end
end

function TaxiBot:IsValid()
    return self.vehicle and DoesEntityExist(self.vehicle) and
            self.driver and DoesEntityExist(self.driver)
end

function TaxiBot:Cleanup()
    if self.vehicle and DoesEntityExist(self.vehicle) then
        DeleteEntity(self.vehicle)
    end
    if self.driver and DoesEntityExist(self.driver) then
        DeleteEntity(self.driver)
    end
    if self.blip then
        RemoveBlip(self.blip)
    end

    self.state = "idle"
    self.vehicle = nil
    self.driver = nil
    self.blip = nil
end

function TaxiBot:Cancel()
    if self.state ~= "idle" then
        lib.notify({type = 'info', description = 'Вызов такси отменен'})
        self:Cleanup()
    end
end

return TaxiBot