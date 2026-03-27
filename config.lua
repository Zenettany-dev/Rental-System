local config = {
    -- координаты где стоит NPC и маркер
    rentPoint = {
        x = 0.0,
        y = 0.0,
        z = 3.0
    },
    
    -- координаты появления машины
    spawnPoint = {
        x = 5.0,
        y = 5.0,
        z = 3.0
    },
    
    -- NPC менеджер
    npcModel = 217, -- скин механика
    npcRotation = 180.0,
    
    -- список доступных автомобилей к аренде
    vehicles = {
        { model = 411, name = "Infernus", pricePerMin = 50 },
        { model = 402, name = "Buffalo", pricePerMin = 50 },
        { model = 506, name = "Super GT", pricePerMin = 60 },
        { model = 560, name = "Sultan", pricePerMin = 30 },
        { model = 562, name = "Elegy", pricePerMin = 45 }
    },
    
    sounds = {
        start = "sounds/610609bad055b8b.mp3"
    }
}

return config