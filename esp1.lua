-- == УДАЛЕНИЕ ГРАНИЦ КАРТЫ ==
pcall(function()
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder then
        local borders = mapFolder:FindFirstChild("Borders")
        if borders then
            borders:Destroy()
            print("✅ workspace.Map.Borders успешно удалены!")
        else
            warn("⚠️ workspace.Map.Borders не найдены")
        end
    else
        warn("⚠️ workspace.Map не найдена")
    end
end)

-- == РАСШИРЕНИЕ ПЛАТФОРМ ==
local targetColor = Color3.fromRGB(99, 95, 98)
local targetMaterial = Enum.Material.SmoothPlastic
local count = 0

for _, obj in pairs(workspace.Map:GetDescendants()) do
    if obj:IsA("BasePart") then
        -- Проверяем Material, Color и наличие MaterialVariant
        if obj.Material == targetMaterial and obj.Color == targetColor then
            obj.Size = Vector3.new(
                obj.Size.X,
                obj.Size.Y,
                obj.Size.Z * 4
            )
            count = count + 1
            print("Расширен:", obj.Name)
            if obj.MaterialVariant ~= "" then
                print("MaterialVariant:", obj.MaterialVariant)
            end
        end
    end
end

print("Всего расширено:", count)

-- == Безопасный HTTP Block с исключениями ==
local G = (getgenv and getgenv()) or _G

-- Кеш для отслеживания уже залогированных URL
local logged_urls = {}
local log_cooldown = 20  -- Показывать повторное сообщение только раз в 20 секунд

local function clog(msg, url)
    local current_time = tick()

    -- Проверяем, логировали ли мы этот URL недавно
    if url and logged_urls[url] then
        local time_diff = current_time - logged_urls[url]
        if time_diff < log_cooldown then
            return  -- Не логируем, если прошло меньше cooldown секунд
        end
    end

    -- Обновляем время последнего лога
    if url then
        logged_urls[url] = current_time
    end

    msg = '[SAFE-BLOCK] ' .. tostring(msg)
    if warn then warn(msg) else print(msg) end
    if G.rconsoleprint then G.rconsoleprint(msg .. '\n') end
end

-- Паттерны для обнаружения Discord webhook URL
local DISCORD_PATTERNS = {
    "discord%.com/api/webhooks/",
    "discordapp%.com/api/webhooks/",
    "webhook%.lewisakura%.moe/api/webhooks/",
    "hooks%.hyra%.io/api/webhooks/",
    "canary%.discord%.com/api/webhooks/",
    "ptb%.discord%.com/api/webhooks/"
}

-- Белый список - разрешенные паттерны (не блокируются)
local WHITELIST_PATTERNS = {
    "discord%.com/api/v%d+/channels/%d+/messages",  -- Каналы Discord
    "discordapp%.com/api/v%d+/channels/%d+/messages",
    "discord%.com/api/v%d+/guilds/",  -- API гильдий
    "discord%.com/api/v%d+/users/",    -- API пользователей
    
    -- LuaArmor исключения
    "luarmor%.net",                    -- Основной домен LuaArmor
    "api%.luarmor%.net",               -- API LuaArmor
    "cdn%.luarmor%.net",               -- CDN LuaArmor
    "ads%.luarmor%.net",               -- Рекламный домен LuaArmor
    "docs%.luarmor%.net"               -- Документация LuaArmor
}

local function isWhitelisted(url)
    if type(url) ~= "string" then return false end
    url = url:lower()

    for _, pattern in ipairs(WHITELIST_PATTERNS) do
        if url:match(pattern) then
            return true
        end
    end

    return false
end

local function isDiscordWebhook(url)
    if type(url) ~= "string" then return false end
    url = url:lower()

    for _, pattern in ipairs(DISCORD_PATTERNS) do
        if url:match(pattern) then
            return true
        end
    end

    if url:match("webhooks/%d+/[%w%-_]+") then
        return true
    end

    return false
end

local function block_request(opts)
    local url = 'unknown'
    if type(opts) == 'table' then
        url = opts.Url or opts.url or tostring(opts)
    else
        url = tostring(opts)
    end

    -- Проверяем белый список ПЕРВЫМ (приоритет)
    if isWhitelisted(url) then
        clog('ALLOWED (whitelist): ' .. url, url)
        -- Пропускаем запрос, вызываем оригинальную функцию
        if G._original_request then
            return G._original_request(opts)
        else
            return { StatusCode = 200, Headers = {}, Body = '{"allowed":true}', Success = true }
        end
    end

    -- Специальная блокировка Discord webhooks
    if isDiscordWebhook(url) then
        clog('BLOCKED DISCORD WEBHOOK: ' .. url, url)
        return {
            StatusCode = 403,
            Headers = {},
            Body = '{"message":"403: Forbidden","code":50013}',
            Success = false
        }
    end

    clog('BLOCKED: ' .. url, url)
    return { StatusCode = 200, Headers = {}, Body = '{"blocked":true}', Success = true }
end

local function safe_replace(tableObj, key, new_func)
    -- Сохраняем оригинальную функцию
    if not G._original_request and tableObj[key] then
        G._original_request = tableObj[key]
    end

    local succ = pcall(function() tableObj[key] = new_func end)
    if succ then clog('Replaced ' .. tostring(key)) end
    return succ
end

safe_replace(G, 'request', block_request)
safe_replace(G, 'http_request', block_request)
pcall(function() if G.syn then safe_replace(G.syn, 'request', block_request) end end)
pcall(function() if G.http then safe_replace(G.http, 'request', block_request) end end)

-- == Гарантированное получение LocalPlayer ==
local Players = game:GetService('Players')
local player = Players.LocalPlayer
if not player then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local CoreGui = game:GetService('CoreGui')
local UserInputService = game:GetService('UserInputService')
local HttpService = game:GetService('HttpService')

-- == НОВАЯ ФУНКЦИЯ: АВТОМАТИЧЕСКИЙ ФАРМ БРЕЙНРОТОВ ==
local autoFarmEnabled = false
local autoFarmConnection = nil
local lastFarmCheck = 0
local FARM_CHECK_INTERVAL = 2 -- Проверка каждые 2 секунды

local function getNearestBrainrot()
    local character = player.Character
    if not character then return nil end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local nearest = nil
    local nearestDistance = math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        -- Ищем брейнроты (возможные названия)
        if (obj.Name:find("Breinrot") or obj.Name:find("Brainrot") or obj.Name:find("Ornament")) 
           and obj:IsA("BasePart") then
            local distance = (humanoidRootPart.Position - obj.Position).Magnitude
            if distance < nearestDistance and distance < 50 then
                nearestDistance = distance
                nearest = obj
            end
        end
    end
    
    return nearest, nearestDistance
end

local function farmBrainrots()
    if not autoFarmEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastFarmCheck < FARM_CHECK_INTERVAL then return end
    lastFarmCheck = currentTime
    
    local brainrot, distance = getNearestBrainrot()
    if not brainrot then 
        print("🔍 Брейнроты не найдены в радиусе 50 studs")
        return 
    end
    
    print("🎯 Найден брейнрот на расстоянии: " .. math.floor(distance) .. " studs")
    
    -- Телепортируемся к брейнроту
    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            -- Плавный телепорт (не мгновенный)
            local tween = TweenService:Create(
                humanoidRootPart,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                {CFrame = CFrame.new(brainrot.Position + Vector3.new(0, 3, 0))}
            )
            tween:Play()
            
            -- Имитируем взаимодействие
            task.wait(0.6)
            
            -- Пытаемся активировать брейнрот (если есть необходимое взаимодействие)
            fireproximityprompt(brainrot:FindFirstChildOfClass("ProximityPrompt"), 0)
            
            print("✅ Собран брейнрот: " .. brainrot.Name)
        end
    end
end

local function startAutoFarm()
    if autoFarmConnection then return end
    autoFarmEnabled = true
    
    autoFarmConnection = RunService.Heartbeat:Connect(function()
        farmBrainrots()
    end)
    
    print("🚀 Автофарм брейнротов ВКЛЮЧЕН!")
end

local function stopAutoFarm()
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
        autoFarmConnection = nil
    end
    autoFarmEnabled = false
    print("⛔ Автофарм брейнротов ВЫКЛЮЧЕН!")
end

-- == ФУНКЦИЯ REMOVEPLAYERR (ПОЛНОЕ УДАЛЕНИЕ ВСЕХ ИГРОКОВ ВИЗУАЛЬНО) ==
local removePlayerEnabled = false
local removePlayerConnection = nil

local function removeAllPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local character = plr.Character
            if character then
                -- Удаляем визуально все части тела
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 1
                        part.CanCollide = false
                        part.CanQuery = false
                        part.CanTouch = false
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        part.Transparency = 1
                    elseif part:IsA("Accessory") then
                        local handle = part:FindFirstChild("Handle")
                        if handle then
                            handle.Transparency = 1
                            handle.CanCollide = false
                        end
                    end
                end
            end
        end
    end
end

local function restoreAllPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local character = plr.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if part.Name ~= "HumanoidRootPart" then
                            part.Transparency = 0
                        else
                            part.Transparency = 1
                        end
                        part.CanCollide = true
                        part.CanQuery = true
                        part.CanTouch = true
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        part.Transparency = 0
                    elseif part:IsA("Accessory") then
                        local handle = part:FindFirstChild("Handle")
                        if handle then
                            handle.Transparency = 0
                            handle.CanCollide = true
                        end
                    end
                end
            end
        end
    end
end

local function startRemovePlayers()
    if removePlayerConnection then return end
    removePlayerEnabled = true

    -- Постоянное обновление для скрытия игроков
    removePlayerConnection = RunService.RenderStepped:Connect(function()
        if removePlayerEnabled then
            removeAllPlayers()
        end
    end)

    -- Обработка новых игроков
    Players.PlayerAdded:Connect(function(newPlayer)
        if newPlayer ~= player then
            newPlayer.CharacterAdded:Connect(function(character)
                if removePlayerEnabled then
                    task.wait(0.5)
                    removeAllPlayers()
                end
            end)
        end
    end)

    print("✅ RemovePlayer ВКЛЮЧЕН - все игроки скрыты!")
end

local function stopRemovePlayers()
    if removePlayerConnection then
        removePlayerConnection:Disconnect()
        removePlayerConnection = nil
    end
    removePlayerEnabled = false
    restoreAllPlayers()
    print("❌ RemovePlayer ВЫКЛЮЧЕН - игроки восстановлены!")
end

-- == ФУНКЦИЯ ПОЛНОГО ОТКЛЮЧЕНИЯ АНИМАЦИЙ ==
local function disableAllAnimations(character)
    local animate = character:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
        animate:Destroy()
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, animationTrack in pairs(animator:GetPlayingAnimationTracks()) do
                animationTrack:Stop()
                animationTrack:Destroy()
            end
            animator:Destroy()
        end
        
        local success, tracks = pcall(function()
            return humanoid:GetPlayingAnimationTracks()
        end)
        if success and tracks then
            for _, track in pairs(tracks) do
                track:Stop()
                track:Destroy()
            end
        end
    end
end

local function keepAnimationsDisabled(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, animationTrack in pairs(animator:GetPlayingAnimationTracks()) do
                animationTrack:Stop()
                animationTrack:Destroy()
            end
            animator:Destroy()
        end
    end
    
    local animate = character:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
        animate:Destroy()
    end
end

-- == СИСТЕМА INFINITY JUMP ==
local infinityJumpEnabled = true
local isSpacePressed = false

local function setupCharacterForFlight(character)
    local humanoid = character:WaitForChild("Humanoid")
    wait(0.1)
    
    disableAllAnimations(character)
    
    humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
end

local function isOnGround(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Freefall and 
           state ~= Enum.HumanoidStateType.Jumping and
           state ~= Enum.HumanoidStateType.Flying and
           humanoid.FloorMaterial ~= Enum.Material.Air
end

local function infinityJump()
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    local moveVector = humanoid.MoveDirection
    local walkSpeed = humanoid.WalkSpeed
    
    local horizontalVelocity = moveVector * walkSpeed
    
    humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
        horizontalVelocity.X,
        32,
        horizontalVelocity.Z
    )
end

local function fall()
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
    
    local moveVector = humanoid.MoveDirection
    local walkSpeed = humanoid.WalkSpeed
    
    local fastFallSpeed = -80
    
    local horizontalVelocity = moveVector * walkSpeed
    
    humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
        horizontalVelocity.X,
        fastFallSpeed,
        horizontalVelocity.Z
    )
end

local infinityJumpConnection = nil
local function startInfinityJump()
    if infinityJumpConnection then return end
    infinityJumpConnection = RunService.RenderStepped:Connect(function()
        local character = player.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        keepAnimationsDisabled(character)
        
        local onGround = isOnGround(character)
        
        if isSpacePressed then
            infinityJump()
        elseif not onGround then
            fall()
        end
    end)
end

local function stopInfinityJump()
    if infinityJumpConnection then
        infinityJumpConnection:Disconnect()
        infinityJumpConnection = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        isSpacePressed = true
    end
    
    -- Бинд на клавишу B для автофарма
    if input.KeyCode == Enum.KeyCode.B then
        if autoFarmEnabled then
            stopAutoFarm()
        else
            startAutoFarm()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        isSpacePressed = false
    end
end)

player.CharacterAdded:Connect(function(character)
    setupCharacterForFlight(character)
    
    task.wait(0.5)
    disableAllAnimations(character)
end)

if player.Character then
    setupCharacterForFlight(player.Character)
end

startInfinityJump()

-- == Стиль UI и иконки ==
local UI_THEME = {
    PanelBg = Color3.fromRGB(16, 14, 24),
    PanelStroke = Color3.fromRGB(95, 70, 160),
    Accent = Color3.fromRGB(148, 0, 211),
    Accent2 = Color3.fromRGB(90, 60, 200),
    Text = Color3.fromRGB(235, 225, 255),
    ButtonOn = Color3.fromRGB(40, 160, 120),
    ButtonOff = Color3.fromRGB(160, 60, 80),
}
local ICONS = {
    Zap = "rbxassetid://7733911822", 
    Eye = "rbxassetid://7733745385", 
    Camera = "rbxassetid://7733871300",
    Jump = "rbxassetid://7733708835",
    Farm = "rbxassetid://7733964150"  -- Новая иконка для фарма
}
local ESP_SETTINGS = { MaxDistance = 500, Font = Enum.Font.GothamBold, Color = Color3.fromRGB(148, 0, 211),
    BgColor = Color3.fromRGB(24, 16, 40), TxtColor = Color3.fromRGB(225, 210, 255), TextSize = 16 }
    
-- Обновленный список объектов с фильтрацией
local OBJECT_EMOJIS = {
    -- ТОЛЬКО интерактивные объекты (можно получить)
    ['La Vacca Saturno Saturita'] = '🐮', 
    ['Nooo My Hotspot'] = '👽', 
    ['La Supreme Combinasion'] = '🔫',
    ['La Taco Combinasion'] = '👒',
    ['Mariachi Corazoni'] = '💀',
    ['Tacorita Bicicleta'] = '🚵‍♂️',
    ['1x1x1x1'] = '🈯️',
    ['Cooki and Milki'] = '🍪',
    ['Los Puggies'] = '🦮',
    ['La Ginger Sekolah'] = '🎄',
    ['Ketupat Kepat'] = '⚰️',
    ['Graipuss Medussi'] = '🦑',
    ['Torrtuginni Dragonfrutini'] = '🐢',
    ['Tictac Sahur'] = '🕰',
    ["Tang Tang Keletang"] = "📢",
    ["Money Money Puggy"] = "🐶",
    ["Los Primos"] = "🙆‍♂️",
    ['Los Tacoritas'] = '🚴',
    ['Guest 666'] = '㊙️',
    ['Fragrama and Chocrama'] = '🍫',
    ['Christmas Chicleteira'] = '🛷',
    ['Pot Hotspot'] = '📱',
    ['La Grande Combinasion'] = '❗️',
    ['Garama and Madundung'] = '🥫',
    ['La Spooky Grande'] = '🟧',
    ['Spooky and Pumpky'] = '🎃',
    ['La Casa Boo'] = '👁‍🗨',
    ["Burrito Bandito"] = "👮‍♀️",
    ["Capitano Moby"] = "🚢",
    ['Los Spaghettis'] = '🚾',
    ['Los Planitos'] = '🪐',
    ['La Jolly Grande'] = '☃️',
    ['Secret Lucky Block'] = '⬛️',
    ['Strawberry Elephant'] = '🐘',
    ['Nuclearo Dinossauro'] = '🦕',
    ['Spaghetti Tualetti'] = '🚽',
    ['Meowl'] = '🐈',
    ['Mieteteira Bicicleteira'] = '☠️',
    ['Headless Horseman'] = '🐴',
    ['W or L'] = '🟩',
    ['Fishino Clownino'] = '🤡',
    ['Orcaledon'] = '🐳',
    ['Ginger'] = '🧸',
    ['Los Mobilis'] = '🧕',
    ['Chicleteira Bicicleteira'] = '🚲',
    ['Los Combinasionas'] = '⚒️',
    ['Ketchuru and Musturu'] = '🍾',
    ['Los Hotspotsitos'] = '☎️',
    ["Chillin Chili"] = "🌶",
    ["Eviledon"] = "👹",
    ['Lavadorito Spinito'] = '📺',
    ['Gobblino Uniciclino'] = '🕊',
    ['Celularcini Viciosini'] = '📱',
    ['Los Nooo My Hotspotsitos'] = '🔔',
    ['Esok Sekolah'] = '🏠',
    ['Los Bros'] = '✊',
    ["Tralaledon"] = "🦈",
    ["La Extinct Grande"] = "🦴",
    ["Las Sis"] = "👧",
    ["Los Chicleteiras"] = "🚳",
    ["Dragon Cannelloni"] = "🐉",
    ["La Secret Combinasion"] = "❓",
    ["Burguro And Fryuro"] = "🍔",
    ['Santa Chicleteira'] = '🎅🏿',
}

-- Список объектов, которые НЕ должны показываться в ESP (брейнроты и декорации)
local EXCLUDED_OBJECTS = {
    "Breinrot", "Brainrot", "Ornament", "Gift", "Present", "Decoration",
    "Tree", "ChristmasTree", "Calendar", "Advent", "Reward"
}

-- == ИСПРАВЛЕННЫЙ ESP (НЕ ПОКАЗЫВАЕТ БРЕЙНРОТЫ) ==
local espCache, esp3DRoot, heartbeatConnection = {}, nil, nil
local camera = workspace.CurrentCamera
local ESP_UPDATE_INTERVAL = 0.25
local MAX_ESP_TARGETS = 24
local lastESPUpdate = 0

-- Проверяем, является ли объект исключенным (брейнрот или декорация)
local function isExcludedObject(obj)
    if not obj or not obj.Parent then return false end
    
    -- Проверяем имя объекта
    local objName = obj.Name:lower()
    for _, excludedName in ipairs(EXCLUDED_OBJECTS) do
        if objName:find(excludedName:lower()) then
            return true
        end
    end
    
    -- Проверяем цепочку родителей
    local current = obj.Parent
    while current do
        local parentName = current.Name:lower()
        for _, excludedName in ipairs(EXCLUDED_OBJECTS) do
            if parentName:find(excludedName:lower()) then
                return true
            end
        end
        current = current.Parent
    end
    
    -- Проверяем, находится ли объект в календаре или на ёлке
    if obj.Parent then
        local parentName = obj.Parent.Name
        if parentName:find("Calendar") or parentName:find("Tree") or parentName:find("Advent") then
            return true
        end
    end
    
    return false
end

local function getRootPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild('HumanoidRootPart') or obj:FindFirstChildWhichIsA('BasePart')
    end
    return nil
end

local function isValidTarget(obj)
    -- Проверяем, что объект существует и имеет подходящее имя
    if not OBJECT_EMOJIS[obj.Name] then return false end
    
    -- Исключаем брейнроты и декорации
    if isExcludedObject(obj) then return false end
    
    -- Проверяем, что объект доступен для взаимодействия
    local rootPart = getRootPart(obj)
    if not rootPart then return false end
    
    -- Дополнительная проверка: объект должен быть в основной области игры
    -- (не в декоративных частях)
    if obj:IsA("Model") then
        -- Проверяем, что модель не является частью статичной декорации
        local parent = obj.Parent
        while parent do
            local parentName = parent.Name:lower()
            if parentName:find("decoration") or parentName:find("props") or parentName:find("static") then
                return false
            end
            if parent == workspace then break end
            parent = parent.Parent
        end
    end
    
    return true
end

local function clearOldESP()
    for obj,data in pairs(espCache) do
        if not obj or not obj.Parent then 
            if data and data.gui then 
                data.gui:Destroy() 
            end
            espCache[obj]=nil 
        end
    end
end

local function createESP(obj)
    local rootPart = getRootPart(obj) 
    if not rootPart then return nil end
    
    local gui = Instance.new('BillboardGui')
    gui.Adornee = rootPart 
    gui.Size = UDim2.new(0,220,0,30) 
    gui.AlwaysOnTop = true
    gui.MaxDistance = ESP_SETTINGS.MaxDistance 
    gui.LightInfluence = 0 
    gui.StudsOffset = Vector3.new(0,3,0)
    gui.Parent = esp3DRoot
    
    local frame = Instance.new('Frame', gui)
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = ESP_SETTINGS.BgColor
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0,8)
    
    local border = Instance.new('UIStroke', frame)
    border.Color = ESP_SETTINGS.Color
    border.Thickness = 1.5
    
    local textLabel = Instance.new('TextLabel', frame)
    textLabel.Size = UDim2.new(1, -8, 1, -4)
    textLabel.Position = UDim2.new(0,4,0,2)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = ESP_SETTINGS.TxtColor
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 16
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Text = OBJECT_EMOJIS[obj.Name].." "..obj.Name
    textLabel.TextScaled = true
    textLabel.ClipsDescendants = true
    
    return {gui=gui, rootPart=rootPart}
end

local function updateESP()
    if tick() - lastESPUpdate < ESP_UPDATE_INTERVAL then return end
    lastESPUpdate = tick()
    
    clearOldESP()
    
    local candidates = {}
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isValidTarget(obj) then
            local root = getRootPart(obj)
            if root then
                table.insert(candidates, {
                    obj=obj, 
                    dist=(root.Position-camera.CFrame.Position).Magnitude
                })
            end
        end
    end
    
    table.sort(candidates, function(a,b) 
        return a.dist < b.dist 
    end)
    
    for i, data in ipairs(candidates) do
        if i > MAX_ESP_TARGETS then break end
        
        local obj = data.obj
        local root = getRootPart(obj)
        
        if not espCache[obj] then
            local d = createESP(obj)
            if d then 
                espCache[obj] = d 
            end
        end
        
        local dat = espCache[obj]
        if dat then
            local _, onScreen = camera:WorldToViewportPoint(root.Position)
            dat.gui.Enabled = onScreen and (data.dist <= ESP_SETTINGS.MaxDistance)
        end
    end
end

local function startESP()
    if not heartbeatConnection then 
        heartbeatConnection = RunService.Heartbeat:Connect(updateESP) 
    end
end

local function stopESP()
    if heartbeatConnection then 
        heartbeatConnection:Disconnect() 
        heartbeatConnection = nil 
    end
    clearOldESP()
end

-- == CAMERAUP ==
local isCameraRaised, cameraFollowConnection = false, nil
local CAMERA_HEIGHT_OFFSET = 20
local function enableFollowCamera()
    if isCameraRaised then return end
    camera.CameraType = Enum.CameraType.Scriptable
    cameraFollowConnection = RunService.RenderStepped:Connect(function()
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if hrp then
                local pos = hrp.Position
                camera.CFrame = CFrame.lookAt(pos + Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0), pos)
            end
        end
    end)
    isCameraRaised = true
end
local function disableFollowCamera()
    if not isCameraRaised then return end
    if cameraFollowConnection then cameraFollowConnection:Disconnect() cameraFollowConnection = nil end
    camera.CameraType = Enum.CameraType.Custom isCameraRaised = false
end

-- == FPSDevourer ==
local function removeAllAccessoriesFromCharacter()
    local char = player.Character
    if not char then return end
    for _,item in ipairs(char:GetChildren()) do
        if item:IsA('Accessory') or item:IsA('LayeredClothing') or item:IsA('Shirt')
        or item:IsA('ShirtGraphic') or item:IsA('Pants') or item:IsA('BodyColors') or item:IsA('CharacterMesh') then
            pcall(function() item:Destroy() end)
        end
    end
end
player.CharacterAdded:Connect(function() task.wait(0.2) removeAllAccessoriesFromCharacter() end)
if player.Character then task.defer(removeAllAccessoriesFromCharacter) end
local FPSDevourer = {}
do
    FPSDevourer.running = false
    local TOOL_NAME = 'Dark Matter Slap'
    local function equip() local c=player.Character local b=player:FindFirstChild('Backpack') if not c or not b then return false end local t=b:FindFirstChild(TOOL_NAME) if t then t.Parent=c return true end return false end
    local function unequip() local c=player.Character local b=player:FindFirstChild('Backpack') if not c or not b then return false end local t=c:FindFirstChild(TOOL_NAME) if t then t.Parent=b return true end return false end
    function FPSDevourer:Start()
        if FPSDevourer.running then return end FPSDevourer.running=true; FPSDevourer._stop=false
        task.spawn(function()
            while FPSDevourer.running and not FPSDevourer._stop do equip(); task.wait(0.035); unequip(); task.wait(0.035); end
        end)
    end
    function FPSDevourer:Stop() FPSDevourer.running = false; FPSDevourer._stop = true; unequip() end
    player.CharacterAdded:Connect(function() FPSDevourer.running=false FPSDevourer._stop=true end)
end

-- == ФУНКЦИЯ ПЕРЕТАСКИВАНИЯ GUI ==
local function makeDraggable(frame)
    local dragging = false
    local dragInput, mousePos, framePos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
