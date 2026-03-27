-- загрузка конфига с проверкой
local config
local configFunc = loadfile("config.lua")
if configFunc then
    config = configFunc()
else
    -- значения по умолчанию
    config = {
        rentPoint = { x = 0, y = 0, z = 3 }, -- ЗАМЕНИТЬ НА СВОИ КООРДИНАТЫ, ГДЕ У ВАС БУДЕТ МЕТКА И NPC
        spawnPoint = { x = 5, y = 5, z = 3 },
        npcModel = 217,
        npcRotation = 180,
        vehicles = {},
        sounds = { start = nil }
    }
    outputDebugString("[Rental] Config file not found, using defaults")
end

-- гуи переменные
local gui = {
    visible = false,
    selected = 1,
    w = 420,
    h = 340,
    x = 0,
    y = 0,
    buttons = {},
    antiSpam = { rent = 0, return = 0 }
}

-- расчёт позиции гуи
local screenW, screenH = guiGetScreenSize()
gui.x = (screenW - gui.w) / 2
gui.y = (screenH - gui.h) / 2

-- кэширование текстур для иконок
local carIconTexture = dxCreateTexture(":rental_system/images/car_icon.png") -- если есть текстура
local function drawCarIcon(x, y, size)
    if carIconTexture then
        dxDrawImage(x, y, size, size, carIconTexture)
    else
        -- Fallback: рисуем простую иконку если нет текстуры
        dxDrawRectangle(x, y + 15, size, 20, tocolor(200, 150, 100, 255))
        dxDrawRectangle(x + 10, y + 5, size - 20, 12, tocolor(180, 180, 200, 255))
        dxDrawCircle(x + 8, y + 32, 6, 0, 360, tocolor(50, 50, 50, 255))
        dxDrawCircle(x + size - 8, y + 32, 6, 0, 360, tocolor(50, 50, 50, 255))
        dxDrawCircle(x + 8, y + 32, 4, 0, 360, tocolor(120, 120, 120, 255))
        dxDrawCircle(x + size - 8, y + 32, 4, 0, 360, tocolor(120, 120, 120, 255))
    end
end

-- отрисовка интерфейса
local function drawGUI()
    if not gui.visible then return end
    
    local x, y, w, h = gui.x, gui.y, gui.w, gui.h
    
    -- фон с тенью
    dxDrawRectangle(x + 2, y + 2, w, h, tocolor(0, 0, 0, 100))
    dxDrawRectangle(x, y, w, h, tocolor(25, 25, 35, 240))
    
    -- заголовок
    dxDrawRectangle(x, y, w, 40, tocolor(45, 45, 60, 255))
    dxDrawText("АРЕНДА ТРАНСПОРТА", x, y, x + w, y + 40, tocolor(255, 200, 0, 255), 1.2, "bankgothic", "center", "center")
    dxDrawLine(x + 10, y + 45, x + w - 10, y + 45, tocolor(80, 80, 100, 255))
    
    -- скроллинг если машин много
    local startY = y + 55
    local itemH = 52
    local maxItems = math.floor((h - 105) / itemH)
    local scrollOffset = 0
    
    if #config.vehicles > maxItems then
        -- TODO: добавить скроллинг если нужно
        scrollOffset = 0
    end
    
    -- список машин
    for i, v in ipairs(config.vehicles) do
        local itemY = startY + (i - 1 - scrollOffset) * itemH
        if itemY + itemH > y + h - 50 then break end
        if itemY >= startY then
            local isSelected = (i == gui.selected)
            
            -- фон элемента
            local bgColor = isSelected and tocolor(65, 105, 165, 220) or tocolor(35, 35, 45, 200)
            dxDrawRectangle(x + 10, itemY, w - 20, itemH - 2, bgColor)
            
            -- обводка выбранного
            if isSelected then
                dxDrawRectangle(x + 8, itemY, 3, itemH - 2, tocolor(255, 200, 0, 255))
            end
            
            -- иконка машины
            drawCarIcon(x + 20, itemY + 6, 40)
            
            -- название
            dxDrawText(v.name, x + 70, itemY, x + 220, itemY + itemH, tocolor(255, 255, 255, 255), 1.0, "default-bold", "left", "center")
            
            -- цена
            dxDrawText(string.format("$%d / мин", v.pricePerMin), x + w - 100, itemY, x + w - 15, itemY + itemH, tocolor(100, 255, 100, 255), 0.9, "default", "right", "center")
        end
    end
    
    -- кнопки
    local btnY = y + h - 50
    local btnW = 110
    local btnSpacing = 20
    local rentX = x + (w - btnW * 2 - btnSpacing) / 2
    local returnX = rentX + btnW + btnSpacing
    
    -- кнопка арендовать
    local rentHover = isMouseInPosition(rentX, btnY, btnW, 35)
    local rentColor = rentHover and tocolor(60, 160, 60, 255) or tocolor(40, 120, 40, 230)
    dxDrawRectangle(rentX, btnY, btnW, 35, rentColor)
    dxDrawText("АРЕНДОВАТЬ", rentX, btnY, rentX + btnW, btnY + 35, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
    
    -- кнопка вернуть
    local returnHover = isMouseInPosition(returnX, btnY, btnW, 35)
    local returnColor = returnHover and tocolor(180, 70, 70, 255) or tocolor(140, 50, 50, 230)
    dxDrawRectangle(returnX, btnY, btnW, 35, returnColor)
    dxDrawText("ВЕРНУТЬ", returnX, btnY, returnX + btnW, btnY + 35, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
    
    -- кнопка закрыть (крестик)
    local closeHover = isMouseInPosition(x + w - 30, y + 8, 22, 22)
    local closeColor = closeHover and tocolor(120, 120, 140, 255) or tocolor(80, 80, 100, 200)
    dxDrawRectangle(x + w - 30, y + 8, 22, 22, closeColor)
    dxDrawText("✕", x + w - 30, y + 8, x + w - 8, y + 30, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
    
    -- сохранение координаты кнопок
    gui.buttons = {
        rent = { x = rentX, y = btnY, w = btnW, h = 35 },
        return = { x = returnX, y = btnY, w = btnW, h = 35 },
        close = { x = x + w - 30, y = y + 8, w = 22, h = 22 }
    }
end

-- проверка позиции мыши
function isMouseInPosition(x, y, w, h)
    local mx, my = getCursorPosition()
    if mx and my then
        local screenW, screenH = guiGetScreenSize()
        local absX, absY = mx * screenW, my * screenH
        return (absX >= x and absX <= x + w) and (absY >= y and absY <= y + h)
    end
    return false
end

-- обработка кликов
local function handleClick(button, state, _, _, clickX, clickY)
    if button ~= "left" or state ~= "up" or not gui.visible then return end
    
    local x, y, w, h = gui.x, gui.y, gui.w, gui.h
    
    -- выбор машины из списка
    local startY = y + 55
    local itemH = 52
    
    for i = 1, #config.vehicles do
        local itemY = startY + (i - 1) * itemH
        if itemY + itemH > y + h - 50 then break end
        if clickX >= x + 10 and clickX <= x + w - 10 and
           clickY >= itemY and clickY <= itemY + itemH - 2 then
            gui.selected = i
            playSoundFrontEnd(40)
            return
        end
    end
    
    -- анти-спам (кд 1 секунда)
    local currentTime = getTickCount()
    
    -- арендовать
    if clickX >= gui.buttons.rent.x and clickX <= gui.buttons.rent.x + gui.buttons.rent.w and
       clickY >= gui.buttons.rent.y and clickY <= gui.buttons.rent.y + gui.buttons.rent.h then
        if currentTime - gui.antiSpam.rent > 1000 then
            gui.antiSpam.rent = currentTime
            triggerServerEvent("rental:start", localPlayer, gui.selected)
            closeGUI()
        else
            outputChatBox("#FF4444[Аренда]#FFFFFF Подождите немного перед повторной арендой", 255, 255, 255, true)
        end
        return
    end
    
    -- вернуть
    if clickX >= gui.buttons.return.x and clickX <= gui.buttons.return.x + gui.buttons.return.w and
       clickY >= gui.buttons.return.y and clickY <= gui.buttons.return.y + gui.buttons.return.h then
        if currentTime - gui.antiSpam.return > 1000 then
            gui.antiSpam.return = currentTime
            triggerServerEvent("rental:return", localPlayer)
            closeGUI()
        else
            outputChatBox("#FF4444[Аренда]#FFFFFF Подождите немного перед возвратом", 255, 255, 255, true)
        end
        return
    end
    
    -- закрыть
    if clickX >= gui.buttons.close.x and clickX <= gui.buttons.close.x + gui.buttons.close.w and
       clickY >= gui.buttons.close.y and clickY <= gui.buttons.close.y + gui.buttons.close.h then
        closeGUI()
        return
    end
end

-- обработка нажатий клавиш
local function handleKey(key, press)
    if not press then return end
    
    if key == "escape" and gui.visible then
        closeGUI()
    elseif key == "arrow_up" and gui.visible then
        if gui.selected > 1 then
            gui.selected = gui.selected - 1
            playSoundFrontEnd(40)
        end
    elseif key == "arrow_down" and gui.visible then
        if gui.selected < #config.vehicles then
            gui.selected = gui.selected + 1
            playSoundFrontEnd(40)
        end
    elseif key == "return" and gui.visible then
        -- enter для аренды
        local currentTime = getTickCount()
        if currentTime - gui.antiSpam.rent > 1000 then
            gui.antiSpam.rent = currentTime
            triggerServerEvent("rental:start", localPlayer, gui.selected)
            closeGUI()
        end
    end
end

-- управление гуи
function openGUI()
    if gui.visible then
        closeGUI()
        return
    end
    
    if #config.vehicles == 0 then
        outputChatBox("#FF4444[Аренда]#FFFFFF Нет доступных автомобилей", 255, 255, 255, true)
        return
    end
    
    gui.visible = true
    showCursor(true)
    addEventHandler("onClientRender", root, drawGUI)
    addEventHandler("onClientClick", root, handleClick)
    bindKey("arrow_up", "down", handleKey)
    bindKey("arrow_down", "down", handleKey)
    bindKey("return", "down", handleKey)
    playSoundFrontEnd(41)
end

function closeGUI()
    if not gui.visible then return end
    
    gui.visible = false
    showCursor(false)
    removeEventHandler("onClientRender", root, drawGUI)
    removeEventHandler("onClientClick", root, handleClick)
    unbindKey("arrow_up", "down", handleKey)
    unbindKey("arrow_down", "down", handleKey)
    unbindKey("return", "down", handleKey)
end

-- события от сервера
addEvent("rental:error", true)
addEventHandler("rental:error", root, function(msg)
    outputChatBox("#FF4444[Аренда]#FFFFFF " .. msg, 255, 255, 255, true)
    playSoundFrontEnd(37)
end)

addEvent("rental:playSound", true)
addEventHandler("rental:playSound", root, function()
    if config.sounds and config.sounds.start then
        local soundPath = "@" .. config.sounds.start
        if fileExists(soundPath) then
            playSound(soundPath)
        else
            playSoundFrontEnd(42)
        end
    else
        playSoundFrontEnd(42)
    end
end)

-- маркер
local marker = nil
local markerBlip = nil

function createRentalMarker()
    if not config.rentPoint then return end
    
    marker = createMarker(config.rentPoint.x, config.rentPoint.y, config.rentPoint.z, "cylinder", 2.5, 0, 200, 0, 180)
    
    if marker then
        addEventHandler("onClientMarkerHit", marker, function(hit)
            if hit == localPlayer then
                openGUI()
            end
        end)
        
        -- добавляем блип на карту
        markerBlip = createBlip(config.rentPoint.x, config.rentPoint.y, config.rentPoint.z, 55, 2, 0, 200, 0, 255, 0, 300)
        if markerBlip then
            setBlipName(markerBlip, "Аренда транспорта")
        end
    end
end

-- удаление маркера
function destroyRentalMarker()
    if marker then
        if isElement(marker) then destroyElement(marker) end
        marker = nil
    end
    if markerBlip then
        if isElement(markerBlip) then destroyElement(markerBlip) end
        markerBlip = nil
    end
end

-- очистка при остановке ресурса
addEventHandler("onClientResourceStop", resourceRoot, function()
    destroyRentalMarker()
    if gui.visible then
        closeGUI()
    end
end)

-- старт ресурса
addEventHandler("onClientResourceStart", resourceRoot, function()
    createRentalMarker()
    outputChatBox("#00FF00[Аренда]#FFFFFF Система аренды загружена. Найдите зеленый маркер на карте.", 255, 255, 255, true)
end)