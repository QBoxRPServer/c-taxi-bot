local Vehicle = lib.class('Vehicle')
--- Конструктор
function Vehicle:constructor(model)
    self.handler = nil
    self.net_id = nil
    self.model = model --string

    self.plate = nil
    self:Spawn()

end

function Vehicle:FindNearestRoadNode(coords, maxDistance)
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

function Vehicle:IsValidRoadPosition(coords)
    -- Проверяем, что позиция на дороге и доступна
    local onRoad = IsPointOnRoad(coords.x, coords.y, coords.z, 0)
    local clear = true

    -- Проверяем, нет ли других объектов на этой позиции
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehCoords)
            if distance < 3.0 then -- Слишком близко к другому транспорту
                clear = false
                break
            end
        end
    end

    return onRoad and clear
end

function Vehicle:FindBestSpawnPosition(preferredCoords)
    local maxAttempts = 5
    local searchRadius = 30.0

    for attempt = 1, maxAttempts do
        -- Ищем дорожный узел
        local spawnCoords = self:FindNearestRoadNode(preferredCoords, searchRadius)

        -- Проверяем валидность позиции
        if self:IsValidRoadPosition(spawnCoords.xyz) then
            print("[FindBestSpawnPosition] Найдена хорошая позиция для спавна (попытка " .. attempt .. ")")
            return spawnCoords
        end

        -- Увеличиваем радиус поиска для следующих попыток
        searchRadius = searchRadius + 10.0
        print("[FindBestSpawnPosition] Попытка " .. attempt .. " неудачна, увеличиваем радиус до " .. searchRadius .. "м")

        Citizen.Wait(0) -- Даем время на обработку
    end

    -- Если все попытки неудачны, возвращаем лучший из найденных вариантов
    print("[FindBestSpawnPosition] Не удалось найти идеальную позицию, используем последний вариант")
    return self:FindNearestRoadNode(preferredCoords, 50.0)
end


function Vehicle:Spawn()
    if not self.model then
        exports["c-logger"]:Log("CRITICAL", "Модель is nil", GetCurrentResourceName())
        return
    end
    print("[Vehicle:Spawn] Начинаем спавн транспорта:", self.model)

    -- Получаем хэш модели
    local modelHash = joaat(self.model)
    print("[Vehicle:Spawn] Хэш модели:", modelHash)

    -- Проверяем существование модели
    if not IsModelInCdimage(modelHash) then
        print("[Vehicle:Spawn] Ошибка: Модель не найдена в CD image:", self.model)
        return false
    end

    if not IsModelAVehicle(modelHash) then
        print("[Vehicle:Spawn] Ошибка: Это не модель транспорта:", self.model)
        return false
    end

    -- Ищем лучшую позицию для спавна
    local originalCoords = GetEntityCoords(PlayerPedId())
    local spawnCoords = self:FindBestSpawnPosition(originalCoords.xyz)

    print("[Vehicle:Spawn] Выбранная позиция для спавна:")
    print("  X:", spawnCoords.x, "Y:", spawnCoords.y, "Z:", spawnCoords.z, "Heading:", spawnCoords.w)
    print("  Расстояние от исходной точки:", #(originalCoords.xyz - spawnCoords.xyz) .. "м")

    -- Загружаем модель
    RequestModel(modelHash)
    print("[Vehicle:Spawn] Модель запрошена")

    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() - startTime > 5000 then
            print("[Vehicle:Spawn] Таймаут загрузки модели:", self.model)
            SetModelAsNoLongerNeeded(modelHash)
            return false
        end
        Citizen.Wait(10)
    end

    print("[Vehicle:Spawn] Модель загружена")

    -- Проверяем финальную позицию перед спавном
    if not self:IsValidRoadPosition(spawnCoords.xyz) then
        print("[Vehicle:Spawn] Внимание: Выбранная позиция может быть проблемной")
    end

    -- Создаем транспорт
    local vehicle = CreateVehicle(
            modelHash,
            spawnCoords.x,
            spawnCoords.y,
            spawnCoords.z + 0.1, -- Немного приподнимаем для избежания залипания
            spawnCoords.w,
            true,  -- network
            false  -- not mission vehicle
    )

    print("[Vehicle:Spawn] CreateVehicle вызван, хэндл:", vehicle)

    -- Ждем создания entity
    local startTime = GetGameTimer()
    while not DoesEntityExist(vehicle) do
        if GetGameTimer() - startTime > 3000 then
            print("[Vehicle:Spawn] Таймаут создания транспорта")
            SetModelAsNoLongerNeeded(modelHash)
            return false
        end
        Citizen.Wait(10)
    end

    -- Принудительно ставим на землю
    SetVehicleOnGroundProperly(vehicle)

    -- Получаем финальные координаты после установки на землю
    local finalCoords = GetEntityCoords(vehicle)
    local finalHeading = GetEntityHeading(vehicle)

    print("[Vehicle:Spawn] Транспорт создан:")
    print("  Финальная позиция: X:", finalCoords.x, "Y:", finalCoords.y, "Z:", finalCoords.z)
    print("  Финальный heading:", finalHeading)

    -- Настраиваем транспорт
    SetModelAsNoLongerNeeded(modelHash)
    SetEntityAsMissionEntity(vehicle, true, true)

    -- Сетевые настройки
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)

    -- Дополнительные настройки
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, false)

    -- Сохраняем данные
    self.handler = vehicle
    self.net_id = netId
    self.modelHash = modelHash
    self.plate = GetVehicleNumberPlateText(vehicle) or "DEFAULT"
    self.spawn_coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, finalHeading)

    -- Создаем водителя если нужно
    if self.createDriver then
        self:CreateDriver()
    end

    -- Уведомление для игрока
    Citizen.SetTimeout(1000, function()
        local dist = #(GetEntityCoords(PlayerPedId()) - finalCoords)
        lib.notify({
            title = 'Миссия',
            description = 'Транспорт ожидает вас в ' .. math.floor(dist) .. ' метрах. Садитесь за руль и следуйте к точке назначения',
            type = 'info',
            duration = 10000,
            position = "center-right"
        })

        -- Добавляем точку на карту
        if self.blip then
            RemoveBlip(self.blip)
        end
        self.blip = AddBlipForCoord(finalCoords.x, finalCoords.y, finalCoords.z)
        SetBlipSprite(self.blip, 227) -- Иконка автомобиля
        SetBlipColour(self.blip, 3) -- Зеленый цвет
        SetBlipAsShortRange(self.blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Миссионный транспорт")
        EndTextCommandSetBlipName(self.blip)
    end)

    return true
end

-- Метод для создания водителя
function Vehicle:CreateDriver()
    if not self.handler or not DoesEntityExist(self.handler) then
        print("[CreateDriver] Ошибка: Транспорт не существует")
        return false
    end

    local driverModel = "a_m_m_afriamer_01" -- Модель водителя
    local driverHash = joaat(driverModel)

    -- Загружаем модель пешехода
    lib.requestModel(driverHash, 3000)

    local coords = GetEntityCoords(self.handler)
    local driver = CreatePedInsideVehicle(
            self.handler,
            4, -- Тип пешехода (4 = внутри транспорта)
            driverHash,
            -1, -- Место водителя
            true, -- Сетевой
            false -- Не миссионный
    )

    if driver and DoesEntityExist(driver) then
        self.driver = driver
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedFleeAttributes(driver, 0, false)
        SetPedKeepTask(driver, true)

        print("[CreateDriver] Водитель создан")
        return true
    end

    print("[CreateDriver] Ошибка создания водителя")
    return false
end

-- Метод для проверки расстояния до игрока
function Vehicle:GetDistanceToPlayer()
    if not self:IsValid() then return 9999 end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleCoords = GetEntityCoords(self.handler)
    return #(playerCoords - vehicleCoords)
end

-- Метод для перемещения транспорта на новую позицию
function Vehicle:RelocateToBetterPosition()
    if not self:IsValid() then return false end

    local currentCoords = GetEntityCoords(self.handler)
    local betterCoords = self:FindBestSpawnPosition(currentCoords)

    -- Сохраняем состояние
    local engineRunning = GetIsVehicleEngineRunning(self.handler)
    local doorLockStatus = GetVehicleDoorLockStatus(self.handler)

    -- Перемещаем
    SetEntityCoords(self.handler, betterCoords.x, betterCoords.y, betterCoords.z, false, false, false, false)
    SetEntityHeading(self.handler, betterCoords.w)
    SetVehicleOnGroundProperly(self.handler)

    -- Восстанавливаем состояние
    SetVehicleDoorsLocked(self.handler, doorLockStatus)
    SetVehicleEngineOn(self.handler, engineRunning, true, false)

    return true
end


-- Метод для очистки
function Vehicle:Cleanup()
    if self.handler and DoesEntityExist(self.handler) then
        DeleteEntity(self.handler)
    end

    if self.driver and DoesEntityExist(self.driver) then
        DeleteEntity(self.driver)
    end

    self.handler = nil
    self.driver = nil
    self.net_id = nil
end

function Vehicle:IsValid()
    return self.handler and DoesEntityExist(self.handler)
end

function Vehicle:GetCoords()
    if self:IsValid() then
        return GetEntityCoords(self.handler)
    end
    return vector3(0, 0, 0)
end

function Vehicle:SetDestination(coords)
    if self.driver and DoesEntityExist(self.driver) then
        TaskVehicleDriveToCoordLongrange(
                self.driver,
                self.handler,
                coords.x,
                coords.y,
                coords.z,
                30.0, -- скорость
                786603, -- стиль вождения
                10.0 -- дистанция
        )
    end
end

return Vehicle