local configFunc = loadfile("config.lua")
local config = configFunc and configFunc() or {
    vehicles = {},
    rentPoint = { x = 0, y = 0, z = 3 },
    spawnPoint = { x = 5, y = 5, z = 3 },
    npcModel = 217,
    npcRotation = 180
}

local activeRents = {}
local rentalTimers = {}

-- вспомогательная функция для проверки существования
local function isPlayerValid(player)
    return player and isElement(player) and getElementType(player) == "player"
end

-- завершение аренды
local function terminateRental(player, reason, refundPercent)
    if not isPlayerValid(player) then return false end
    
    local rental = activeRents[player]
    if not rental then return false end
    
    -- останавливает таймер
    if rental.timer and isTimer(rental.timer) then
        killTimer(rental.timer)
    end
    
    -- возврат денег (если нужно)
    if reason == "return" and refundPercent and refundPercent > 0 then
        local elapsed = (getTickCount() - rental.startTime) / 1000
        local remaining = math.max(0, 60 - elapsed) / 60
        local refund = math.floor(rental.price * remaining * (refundPercent / 100))
        
        if refund > 0 then
            givePlayerMoney(player, refund)
            outputChatBox(string.format("#00FF00[Аренда]#FFFFFF Возвращено $%d", refund), player, 255, 255, 255, true)
        end
    end
    
    -- выкидывает из машины и удаляем её
    if rental.vehicle and isElement(rental.vehicle) then
        if getPedOccupiedVehicle(player) == rental.vehicle then
            removePedFromVehicle(player)
        end
        destroyElement(rental.vehicle)
    end
    
    activeRents[player] = nil
    
    -- сообщение о причине
    local messages = {
        nofunds = "#FF0000[Аренда]#FFFFFF Недостаточно средств, аренда завершена",
        return = "#00FF00[Аренда]#FFFFFF Транспорт возвращен",
        destroy = "#FF0000[Аренда]#FFFFFF Ваш транспорт уничтожен",
        quit = "#FF0000[Аренда]#FFFFFF Аренда завершена из-за выхода из игры"
    }
    
    if messages[reason] then
        outputChatBox(messages[reason], player, 255, 255, 255, true)
    end
    
    return true
end

-- проверка и списание оплаты
local function chargeRent(player)
    if not isPlayerValid(player) then
        return
    end
    
    local rental = activeRents[player]
    if not rental then 
        return 
    end
    
    -- проверяем, существует ли машина
    if not rental.vehicle or not isElement(rental.vehicle) then
        terminateRental(player, "destroy", 0)
        return
    end
    
    local playerMoney = getPlayerMoney(player)
    if playerMoney >= rental.price then
        takePlayerMoney(player, rental.price)
        outputChatBox(string.format("#00FF00[Аренда]#FFFFFF Списано $%d за минуту. Осталось: $%d", rental.price, playerMoney - rental.price), player, 255, 255, 255, true)
        rental.startTime = getTickCount()
    else
        outputChatBox("#FF0000[Аренда]#FFFFFF Недостаточно средств для продления аренды!", player, 255, 255, 255, true)
        terminateRental(player, "nofunds", 0)
    end
end

-- Начало аренды
function startRental(player, vehicleIndex)
    if not isPlayerValid(player) then 
        return false 
    end
    
    -- проверка на уже арендованную машину
    if activeRents[player] then
        triggerClientEvent(player, "rental:error", player, "У вас уже есть арендованная машина")
        return false
    end
    
    -- проверка, не находится ли игрок в транспорте
    if isPedInVehicle(player) then
        triggerClientEvent(player, "rental:error", player, "Пожалуйста, выйдите из транспорта перед арендой")
        return false
    end
    
    local vehicleData = config.vehicles[vehicleIndex]
    if not vehicleData then
        triggerClientEvent(player, "rental:error", player, "Транспорт не найден")
        return false
    end
    
    -- проверка денег
    local playerMoney = getPlayerMoney(player)
    if playerMoney < vehicleData.pricePerMin then
        triggerClientEvent(player, "rental:error", player, string.format("Нужно $%d для аренды, у вас $%d", vehicleData.pricePerMin, playerMoney))
        return false
    end
    
    -- проверка, свободно ли место для спавна
    local spawnX, spawnY, spawnZ = config.spawnPoint.x, config.spawnPoint.y, config.spawnPoint.z
    local nearbyVehicles = getElementsWithinRange(spawnX, spawnY, spawnZ, 5, "vehicle")
    if #nearbyVehicles > 0 then
        triggerClientEvent(player, "rental:error", player, "Место для спавна занято, попробуйте позже")
        return false
    end
    
    -- списываем первую оплату
    takePlayerMoney(player, vehicleData.pricePerMin)
    
    -- создаем машину
    local vehicle = createVehicle(
        vehicleData.model,
        spawnX, spawnY, spawnZ,
        0, 0, config.npcRotation or 0
    )
    
    if not vehicle or not isElement(vehicle) then
        givePlayerMoney(player, vehicleData.pricePerMin)
        triggerClientEvent(player, "rental:error", player, "Ошибка создания транспорта")
        return false
    end
    
    -- устанавливаем свойства машины
    setVehicleColor(vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
    setVehicleDamageProof(vehicle, false)
    setVehicleFuelTankExplodable(vehicle, true)
    
    -- сажаем игрока
    warpPedIntoVehicle(player, vehicle, 0)
    
    -- сохраняем аренду
    local timer = setTimer(chargeRent, 60000, 0, player)
    activeRents[player] = {
        vehicle = vehicle,
        timer = timer,
        startTime = getTickCount(),
        price = vehicleData.pricePerMin,
        name = vehicleData.name,
        model = vehicleData.model
    }
    
    -- уведомления
    outputChatBox(string.format("#00FF00[Аренда]#FFFFFF Вы арендовали %s за $%d/мин", vehicleData.name, vehicleData.pricePerMin), player, 255, 255, 255, true)
    triggerClientEvent(player, "rental:playSound", player)
    
    -- логи в консоль сервера
    outputDebugString(string.format("[Rental] %s арендовал %s (ID: %d)", getPlayerName(player), vehicleData.name, vehicleData.model))
    
    return true
end

function returnRental(player)
    if not isPlayerValid(player) then 
        return false 
    end
    
    if not activeRents[player] then
        triggerClientEvent(player, "rental:error", player, "У вас нет арендованной машины")
        return false
    end
    
    terminateRental(player, "return", 50) -- возвращаем 50% от остатка , можно убрать/заменить на другой %
    return true
end

-- регистрация событий
addEvent("rental:start", true)
addEventHandler("rental:start", root, startRental)

addEvent("rental:return", true)
addEventHandler("rental:return", root, returnRental)

-- обработка выхода игрока
addEventHandler("onPlayerQuit", root, function()
    if activeRents[source] then
        terminateRental(source, "quit", 0)
    end
end)

-- обработка смерти игрока (опционально)
addEventHandler("onPlayerWasted", root, function()
    if activeRents[source] then
        outputChatBox("#FFAA00[Аренда]#FFFFFF Вы погибли, аренда продолжается. Не забудьте вернуть транспорт!", source, 255, 255, 255, true)
    end
end)

-- очистка при уничтожении машины
addEventHandler("onVehicleDestroy", root, function()
    for player, rental in pairs(activeRents) do
        if rental.vehicle == source then
            if isPlayerValid(player) then
                outputChatBox("#FF0000[Аренда]#FFFFFF Ваша машина уничтожена! Аренда завершена.", player, 255, 255, 255, true)
                triggerClientEvent(player, "rental:error", player, "Ваш транспорт уничтожен")
            end
            terminateRental(player, "destroy", 0)
            break
        end
    end
end)

-- Инициализация
local npc = nil

addEventHandler("onResourceStart", resourceRoot, function()
    if config.rentPoint then
        npc = createPed(config.npcModel, config.rentPoint.x, config.rentPoint.y, config.rentPoint.z, config.npcRotation or 0)
        if npc then
            setElementFrozen(npc, true)
            setElementData(npc, "nametag", false)
            -- добавляет текст над NPC
            setElementData(npc, "text", "Аренда транспорта\nНажми на маркер", false)
        end
    end
    outputDebugString("[Rental] Система аренды запущена")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    -- завершаем все активные аренды
    for player, rental in pairs(activeRents) do
        if isElement(rental.vehicle) then 
            destroyElement(rental.vehicle) 
        end
        if rental.timer and isTimer(rental.timer) then 
            killTimer(rental.timer) 
        end
        if isPlayerValid(player) then
            outputChatBox("#FF0000[Аренда]#FFFFFF Система аренды перезагружается, аренда завершена", player, 255, 255, 255, true)
        end
    end
    activeRents = {}
    
    if npc and isElement(npc) then 
        destroyElement(npc) 
    end
    outputDebugString("[Rental] Система аренды остановлена")
end)

-- функция для отладки (можно вызвать из консоли)
function getActiveRents()
    local count = 0
    for player, rental in pairs(activeRents) do
        if isPlayerValid(player) then
            count = count + 1
            outputDebugString(string.format("Активная аренда: %s - %s", getPlayerName(player), rental.name))
        end
    end
    outputDebugString(string.format("Всего активных аренд: %d", count))
end