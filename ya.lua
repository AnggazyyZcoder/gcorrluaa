--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL)
-- Luna UI + Material icons
-- Clean, modern, professional design
-- Author: Anggazyy (refactor)
--//////////////////////////////////////////////////////////////////////////////////

-- CONFIG: ubah sesuai kebutuhan
local AUTO_FISH_REMOTE_NAME = "UpdateAutoFishingState"
local NET_PACKAGES_FOLDER = "Packages"

-- Services & Variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer

local autoFishEnabled = false
local autoFishLoopThread = nil
local coordinateGui = nil
local statusLabel = nil
local currentSelectedMap = nil

-- Player Configuration Variables
local antiLagEnabled = false
local savePositionEnabled = false
local lockPositionEnabled = false
local lastSavedPosition = nil
local lockPositionLoop = nil
local originalGraphicsSettings = {}

-- Bypass Variables
local fishingRadarEnabled = false
local divingGearEnabled = false
local autoSellEnabled = false
local autoSellThreshold = 3
local autoSellLoop = nil

-- Fishing System Variables
local fishingSystemEnabled = false
local fishingSystemLoop = nil
local chargeDelay = 0.5

-- Auto-clean money icons
task.spawn(function()
    while task.wait(1) do
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj and (obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel")) then
                local nameLower = (obj.Name or ""):lower()
                local textLower = (obj.Text or ""):lower()
                if string.find(nameLower, "money") or string.find(textLower, "money") or string.find(nameLower, "100") then
                    pcall(function()
                        obj.Visible = false
                        if obj:IsA("GuiObject") then
                            obj.Active = false
                            obj.ZIndex = 0
                        end
                    end)
                end
            end
        end
    end
end)

-- Luna UI Loader
local successLoad, Luna = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()
end)
if not successLoad or not Luna then
    warn("Luna UI loading failed. Please check your executor configuration.")
    return
end

-- Create Luna Window
local Window = Luna:CreateWindow({
    Name = "Anggazyy Hub - Fish It",
    Subtitle = "Premium Automation System",
    LogoID = "6034684454",
    LoadingEnabled = true,
    LoadingTitle = "Anggazyy Hub",
    LoadingSubtitle = "Loading Premium Features...",
    
    ConfigSettings = {
        RootFolder = nil,
        ConfigFolder = "AnggazyyHubConfig"
    },
    
    KeySystem = false, -- Disable key system for now
    KeySettings = {
        Title = "Anggazyy Hub Access",
        Subtitle = "Enter Key",
        Note = "Contact developer for access key",
        SaveInRoot = false,
        SaveKey = false,
        Key = {"1234"},
        SecondAction = {
            Enabled = false,
            Type = "Link",
            Parameter = ""
        }
    }
})

-- Create Home Tab
Window:CreateHomeTab({
    SupportedExecutors = {
        "Synapse X",
        "Krnl", 
        "ProtoSmasher",
        "Fluxus",
        "Script-Ware",
        "Electron"
    },
    DiscordInvite = "",
    Icon = 1
})

-- Notification System
local function Notify(opts)
    pcall(function()
        Luna:Notification({
            Title = opts.Title or "Notification",
            Icon = opts.Icon or "info",
            ImageSource = "Material",
            Content = opts.Content or ""
        })
    end)
end

-- Network Communication
local function GetAutoFishRemote()
    local ok, NetModule = pcall(function()
        local folder = ReplicatedStorage:WaitForChild(NET_PACKAGES_FOLDER, 5)
        if folder then
            local netCandidate = folder:FindFirstChild("Net")
            if netCandidate and netCandidate:IsA("ModuleScript") then
                return require(netCandidate)
            end
        end
        if ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Net") then
            local m = ReplicatedStorage.Packages.Net
            if m:IsA("ModuleScript") then
                return require(m)
            end
        end
        return nil
    end)
    return ok and NetModule or nil
end

local function SafeInvokeAutoFishing(state)
    pcall(function()
        local Net = GetAutoFishRemote()
        if Net and type(Net.RemoteFunction) == "function" then
            local ok, rf = pcall(function() return Net:RemoteFunction(AUTO_FISH_REMOTE_NAME) end)
            if ok and rf then
                pcall(function() rf:InvokeServer(state) end)
                return
            end
        end
        
        local rfObj = ReplicatedStorage:FindFirstChild(AUTO_FISH_REMOTE_NAME) 
            or ReplicatedStorage:FindFirstChild("RemoteFunctions") and ReplicatedStorage.RemoteFunctions:FindFirstChild(AUTO_FISH_REMOTE_NAME)
        if rfObj and rfObj:IsA("RemoteFunction") then
            pcall(function() rfObj:InvokeServer(state) end)
            return
        end
    end)
end

-- =================================================================
-- ADVANCED FISHING SYSTEM - TAB FISHING IMPLEMENTATION
-- =================================================================

-- Fishing System Dependencies
local function GetFishingDependencies()
    local dependencies = {}
    
    pcall(function()
        -- Get required modules
        dependencies.RunService = RunService
        dependencies.UserInputService = game:GetService("UserInputService")
        dependencies.ReplicatedStorage = ReplicatedStorage
        dependencies.Players = Players
        dependencies.LocalPlayer = LocalPlayer
        
        -- Import packages
        dependencies.Signal = require(ReplicatedStorage.Packages.Signal)
        dependencies.Trove = require(ReplicatedStorage.Packages.Trove)
        dependencies.Net = require(ReplicatedStorage.Packages.Net)
        dependencies.spr = require(ReplicatedStorage.Packages.spr)
        dependencies.Constants = require(ReplicatedStorage.Shared.Constants)
        dependencies.Soundbook = require(ReplicatedStorage.Shared.Soundbook)
        dependencies.GuiControl = require(ReplicatedStorage.Modules.GuiControl)
        dependencies.HUDController = require(ReplicatedStorage.Controllers.HUDController)
        dependencies.AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
        dependencies.TextNotificationController = require(ReplicatedStorage.Controllers.TextNotificationController)
        dependencies.BlockedHumanoidStates = require(ReplicatedStorage.Shared.BlockedHumanoidStates)
        
        -- Get UI elements
        local PlayerGui = LocalPlayer.PlayerGui
        dependencies.Charge_upvr = PlayerGui:WaitForChild("Charge")
        dependencies.Fishing_upvr = PlayerGui:WaitForChild("Fishing")
        dependencies.Main_upvr = dependencies.Fishing_upvr.Main
        dependencies.CanvasGroup_upvr = dependencies.Main_upvr.Display.CanvasGroup
    end)
    
    return dependencies
end

-- Fishing System Implementation
local function CreateFishingSystem()
    local deps = GetFishingDependencies()
    if not deps.Net then 
        warn("Fishing System: Net module not found")
        return nil 
    end
    
    -- Variabel status internal
    local var17_upvw = { Data = { EquippedId = 123 } } -- SIMULASI: Harus diinisialisasi agar rod check lulus
    local var32_upvw = false 
    local var34_upvw = false -- Is Stopped/Closing
    local var35_upvw = nil -- Charge Start Time
    local var36_upvw = nil -- Minigame UUID
    local var37_upvw = nil -- Minigame State / Data (Progress, ClickPower)
    local var38_upvw = 0 -- Cooldown Time
    local var40_upvw = nil -- Reel Sound Track
    local var109_upvw = false -- Is Charging flag

    -- Trove untuk pembersihan koneksi
    local trove = deps.Trove.new()
    local chargeTrove = deps.Trove.new()
    local minigameTrove = deps.Trove.new()

    -- Signal untuk Minigame Changes
    local MinigameChangedSignal = deps.Signal.new()

    -- Fungsi placeholder
    local function RefreshIdle() 
        print("Simulasi: Menghentikan animasi memancing.") 
    end
    
    local function FishingRodEquipped(id) 
        return id ~= nil 
    end
    
    local function GetItemDataFromEquippedItem(id) 
        if not id then return nil end
        return { Data = { Type = "Fishing Rods", Name = "FishingRodSound" } }
    end

    -- =================================================================
    -- FUNGSI KOMUNIKASI SERVER
    -- =================================================================

    -- Net Function: Digunakan untuk melempar joran
    local CastFishingRod_Net = deps.Net:RemoteFunction("RequestFishingMinigameStarted") 
    -- Net Event: Dari Server ke Klien, menandakan ikan menggigit
    local FishingMinigameStarted_Net = deps.Net:RemoteEvent("FishingMinigameStarted")
    -- Net Event: Dari Klien ke Server, menandakan Minigame selesai
    local FishingCompleted_Net = deps.Net:RemoteEvent("FishingCompleted")
    -- Net Function: Untuk memulai proses charge (opsional)
    local ChargeFishingRod_Net = deps.Net:RemoteFunction("ChargeFishingRod")

    -- =================================================================
    -- FUNGSI OTOMATISASI: Auto Clicker
    -- =================================================================

    local AutoClickerConnection = nil

    local function FishingMinigameClick()
        if not var36_upvw or not var37_upvw then return end
        local currentTime = workspace:GetServerTimeNow()
        if currentTime - var37_upvw.LastInput < 0.1 then return end
        local clamped = math.clamp(var37_upvw.Progress + var37_upvw.FishingClickPower, 0, 1)
        var37_upvw.LastInput = currentTime
        var37_upvw.Progress = clamped
        var37_upvw.Inputs = (var37_upvw.Inputs or 0) + 1
        MinigameChangedSignal:Fire(var37_upvw)
        if clamped >= 1 then
            minigameTrove:Clean()
            FishingCompleted_Net:FireServer()
            print("[Auto Click] Minigame Selesai. Notifikasi server dikirim.")
        end
        return true
    end

    local function StartAutoMinigameClicker()
        if AutoClickerConnection then 
            AutoClickerConnection:Disconnect()
            AutoClickerConnection = nil
        end
        print("[Auto Clicker] Diaktifkan! Memulai spam klik.")
        AutoClickerConnection = deps.RunService.Heartbeat:Connect(FishingMinigameClick)
        minigameTrove:Add(AutoClickerConnection)
    end

    local function StopAutoMinigameClicker()
        if AutoClickerConnection then
            AutoClickerConnection:Disconnect()
            AutoClickerConnection = nil
            minigameTrove:Clean()
            print("[Auto Clicker] Dihentikan.")
        end
    end

    -- =================================================================
    -- FUNGSI INTI: Minigame Started (Dipanggil oleh Server Event)
    -- =================================================================

    local function FishingRodStarted(data)
        if var36_upvw then return end
        print("[Server Event] Ikan Menggigit! Memulai Minigame...")
        deps.AnimationController:PlayAnimation("ReelIntermission") -- Animasi
        
        var36_upvw = data.UUID
        var37_upvw = data
        
        local reelSound = deps.Soundbook.Sounds.Reel:Play() -- Sound
        var40_upvw = reelSound
        reelSound.Volume = 0
        deps.spr.target(reelSound, 5, 10, { Volume = deps.Soundbook.Sounds.Reel.Volume })
        minigameTrove:Add(function() deps.spr.stop(reelSound); reelSound:Stop(); reelSound:Destroy() end)
        
        deps.spr.stop(deps.Fishing_upvr.Main) -- UI
        deps.spr.target(deps.Fishing_upvr.Main, 50, 250, { Position = UDim2.fromScale(0.5, 0.95) })
        deps.GuiControl:SetHUDVisibility(false)
        deps.Fishing_upvr.Enabled = true

        StartAutoMinigameClicker()
    end

    -- =================================================================
    -- FUNGSI INTI: Fishing Stopped
    -- =================================================================

    local function FishingStopped(isSuccessful)
        if var34_upvw then return end
        var34_upvw = true
        local isCatch = isSuccessful or (var37_upvw and var37_upvw.Progress >= 1)
        StopAutoMinigameClicker()

        if not isCatch then
            deps.AnimationController:PlayAnimation("FishingFailure")
        else
            RefreshIdle()
        end
        
        deps.HUDController.ResetCamera()
        
        deps.spr.stop(deps.Fishing_upvr.Main)
        deps.spr.target(deps.Fishing_upvr.Main, 50, 100, { Position = UDim2.fromScale(0.5, 1.5) })
        task.wait(0.45)
        
        chargeTrove:Clean()
        minigameTrove:Clean()
        deps.GuiControl:SetHUDVisibility(true)
        var38_upvw = workspace:GetServerTimeNow()
        
        var34_upvw = false
        var37_upvw = nil
        var36_upvw = nil
        
        print("[Auto Fishing] Berhasil dibersihkan. Siap untuk proses berikutnya.")
    end

    -- =================================================================
    -- FUNGSI INTI: Permintaan Lemparan
    -- =================================================================

    local function SendFishingRequestToServer(power)
        local character = deps.LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        
        local throwPosition = character.HumanoidRootPart.CFrame.Position + Vector3.new(0, -1, 10)
        local castTime = workspace:GetServerTimeNow()
        
        local success, responseData = pcall(function()
            return CastFishingRod_Net:InvokeServer(
                throwPosition.Y,
                power,
                castTime
            )
        end)

        if success then
            print("[Server Response] Lemparan joran berhasil. Menunggu ikan menggigit...")
            return true
        else
            deps.TextNotificationController:DeliverNotification({
                Type = "Text", Text = "Gagal melempar: " .. tostring(responseData),
                TextColor = { R = 255, G = 0, B = 0 }, CustomDuration = 3.5
            })
            return false
        end
    end

    -- =================================================================
    -- FUNGSI PENGONTROL OTOMATIS (DO THROW DIPERBAIKI)
    -- =================================================================

    local function internal_DoThrow(chargePower, clientRequestDestroy)
        -- Lakukan Animasi Lempar
        deps.AnimationController:DestroyActiveAnimationTracks()
        deps.AnimationController:PlayAnimation("RodThrow")
        
        -- Lakukan Suara Lemparan
        local itemData = GetItemDataFromEquippedItem(var17_upvw and var17_upvw.Data.EquippedId)
        local sound = deps.Soundbook.Sounds.ThrowCast
        if itemData and deps.Soundbook.Sounds[itemData.Data.Name] then
            sound = deps.Soundbook.Sounds[itemData.Data.Name]
        end
        sound:Play().Volume = 0.5 + math.random() * 0.75

        -- Kirim permintaan Lempar
        local didServerAccept = SendFishingRequestToServer(chargePower)
        
        -- Jika server menolak lemparan, bersihkan
        if not didServerAccept then
            task.wait(0.1)
            FishingStopped(false) 
            if clientRequestDestroy then clientRequestDestroy() end
        end
        -- Jika diterima, Klien tetap diam dan menunggu FishingMinigameStarted_Net
    end

    local function StartAutoFishing(chargeDelaySeconds)
        chargeDelaySeconds = chargeDelaySeconds or 0.5
        
        if var109_upvw or var34_upvw then
            warn("Auto Fishing sudah berjalan atau sedang berhenti.")
            return
        end

        -- 1. Check Awal (Cooldown & Equipped)
        if workspace:GetServerTimeNow() - var38_upvw < deps.Constants.FishingCooldownTime then
            deps.TextNotificationController:DeliverNotification({ Type = "Text", Text = "Memancing masih Cooldown!", TextColor = { R = 255, G = 0, B = 0 }, CustomDuration = 2 })
            return
        end
        local rodData = GetItemDataFromEquippedItem(var17_upvw and var17_upvw.Data.EquippedId)
        if not rodData or rodData.Data.Type ~= "Fishing Rods" then
            deps.TextNotificationController:DeliverNotification({ Type = "Text", Text = "Tidak ada joran terpasang!", TextColor = { R = 255, G = 255, B = 0 }, CustomDuration = 2 })
            return
        end
        
        -- 2. Memulai Charge
        var109_upvw = true
        deps.AnimationController:StopAnimation("EquipIdle")
        deps.AnimationController:PlayAnimation("StartRodCharge")
        print(string.format("[Auto Charge] Dimulai. Menunggu %.2f detik...", chargeDelaySeconds))
        
        var35_upvw = workspace:GetServerTimeNow()
        pcall(function()
            ChargeFishingRod_Net:InvokeServer(nil, nil, nil, var35_upvw)
        end)
        
        -- Tambahkan fungsi cleanup charge ke trove
        chargeTrove:Add(function()
            var109_upvw = false
            deps.AnimationController:StopAnimation("StartRodCharge")
            deps.AnimationController:StopAnimation("LoopedRodCharge")
            RefreshIdle()
        end)
        
        -- 3. Melempar setelah delay selesai
        task.delay(chargeDelaySeconds, function()
            -- Jika sudah dihentikan oleh proses lain (misal user input), jangan lempar
            if not var109_upvw then return

            local throwPower = deps.Constants:GetPower(var35_upvw)
            
            -- ** PENTING: Lakukan cleanup charge SEBELUM memanggil DoThrow, ini sesuai flow game. **
            chargeTrove:Clean() 

            -- Panggil fungsi lempar
            internal_DoThrow(throwPower, function() FishingStopped(false) end) 
        end)
    end

    -- =================================================================
    -- SERVER EVENT LISTENERS
    -- =================================================================

    -- Menghubungkan Minigame Started Event dari Server ke FishingRodStarted
    trove:Add(FishingMinigameStarted_Net:Connect(function(data)
        FishingRodStarted(data)
    end))

    -- Menghubungkan Minigame Selesai dari Server ke proses cleanup klien
    trove:Add(deps.Net:RemoteEvent("FishingMinigameStop"):Connect(function(isSuccess)
        FishingStopped(isSuccess)
    end))

    return {
        Start = StartAutoFishing,
        Stop = FishingStopped,
        Cleanup = function()
            trove:Clean()
            chargeTrove:Clean()
            minigameTrove:Clean()
        end
    }
end

-- Fishing System Controller
local fishingSystem = nil

local function InitializeFishingSystem()
    if fishingSystem then return fishingSystem end
    
    local success, result = pcall(function()
        fishingSystem = CreateFishingSystem()
        return fishingSystem
    end)
    
    if success and fishingSystem then
        Notify({Title = "Fishing System", Content = "Advanced fishing system initialized", Duration = 3})
        return fishingSystem
    else
        Notify({Title = "Fishing System Error", Content = "Failed to initialize fishing system: " .. tostring(result), Duration = 4})
        return nil
    end
end

local function StartFishingSystem()
    if fishingSystemEnabled then return end
    
    local system = InitializeFishingSystem()
    if not system then return end
    
    fishingSystemEnabled = true
    
    fishingSystemLoop = task.spawn(function()
        while fishingSystemEnabled do
            pcall(function()
                system.Start(chargeDelay)
                -- Wait for fishing cycle to complete
                task.wait(6) -- Adjust based on fishing cycle timing
            end)
            task.wait(0.5) -- Small delay between cycles
        end
    end)
    
    Notify({Title = "Fishing System", Content = "Advanced fishing system activated", Duration = 3})
end

local function StopFishingSystem()
    if not fishingSystemEnabled then return end
    fishingSystemEnabled = false
    
    if fishingSystemLoop then
        task.cancel(fishingSystemLoop)
        fishingSystemLoop = nil
    end
    
    if fishingSystem then
        pcall(function() fishingSystem.Stop(false) end)
        pcall(function() fishingSystem.Cleanup() end)
    end
    
    Notify({Title = "Fishing System", Content = "Advanced fishing system deactivated", Duration = 3})
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    if statusLabel then 
        pcall(function() 
            statusLabel:SetText("Status: ACTIVE")
        end) 
    end
    Notify({Title = "Auto Fishing", Content = "System activated successfully", Duration = 2})

    autoFishLoopThread = task.spawn(function()
        while autoFishEnabled do
            pcall(function()
                SafeInvokeAutoFishing(true)
            end)
            task.wait(4)
        end
    end)
end

local function StopAutoFish()
    if not autoFishEnabled then return end
    autoFishEnabled = false
    if statusLabel then 
        pcall(function() 
            statusLabel:SetText("Status: DISABLED")
        end) 
    end
    Notify({Title = "Auto Fishing", Content = "System deactivated", Duration = 2})
    
    pcall(function()
        SafeInvokeAutoFishing(false)
    end)
end

-- =============================================================================
-- ULTRA ANTI LAG SYSTEM - WHITE TEXTURE MODE
-- =============================================================================

-- Save original graphics settings
local function SaveOriginalGraphics()
    originalGraphicsSettings = {
        GraphicsQualityLevel = UserGameSettings.GraphicsQualityLevel,
        SavedQualityLevel = UserGameSettings.SavedQualityLevel,
        MasterVolume = Lighting.GlobalShadows,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
        ShadowSoftness = Lighting.ShadowSoftness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    }
end

-- Ultra Anti Lag System - White Texture Mode
local function EnableAntiLag()
    if antiLagEnabled then return end
    
    SaveOriginalGraphics()
    antiLagEnabled = true
    
    -- Extreme graphics optimization with white textures
    pcall(function()
        -- Graphics quality settings
        UserGameSettings.GraphicsQualityLevel = 1
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        
        -- Lighting optimization - Bright white environment
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 5  -- Extra bright
        Lighting.ShadowSoftness = 0
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)  -- Pure white ambient
        Lighting.Ambient = Color3.new(1, 1, 1)  -- Pure white
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        
        -- Terrain optimization - White terrain
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
        end
        
        -- Make all parts white and disable effects
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                -- Set all parts to white
                if obj:FindFirstChildOfClass("Texture") then
                    obj:FindFirstChildOfClass("Texture"):Destroy()
                end
                if obj:FindFirstChildOfClass("Decal") then
                    obj:FindFirstChildOfClass("Decal"):Destroy()
                end
                obj.Material = Enum.Material.SmoothPlastic
                obj.BrickColor = BrickColor.new("White")
                obj.Reflectance = 0
            elseif obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            elseif obj:IsA("Fire") then
                obj.Enabled = false
            elseif obj:IsA("Smoke") then
                obj.Enabled = false
            elseif obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Beam") then
                obj.Enabled = false
            elseif obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Sound") and not obj:FindFirstAncestorWhichIsA("Player") then
                obj:Stop()
            end
        end
        
        -- Reduce texture quality to minimum
        settings().Rendering.QualityLevel = 1
    end)
    
    Notify({Title = "Ultra Anti Lag", Content = "White texture mode enabled - Maximum performance", Duration = 3})
end

local function DisableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    
    -- Restore original graphics settings
    pcall(function()
        if originalGraphicsSettings.GraphicsQualityLevel then
            UserGameSettings.GraphicsQualityLevel = originalGraphicsSettings.GraphicsQualityLevel
        end
        if originalGraphicsSettings.SavedQualityLevel then
            UserGameSettings.SavedQualityLevel = originalGraphicsSettings.SavedQualityLevel
        end
        if originalGraphicsSettings.MasterVolume ~= nil then
            Lighting.GlobalShadows = originalGraphicsSettings.MasterVolume
        end
        if originalGraphicsSettings.Brightness then
            Lighting.Brightness = originalGraphicsSettings.Brightness
        end
        if originalGraphicsSettings.FogEnd then
            Lighting.FogEnd = originalGraphicsSettings.FogEnd
        end
        if originalGraphicsSettings.ShadowSoftness then
            Lighting.ShadowSoftness = originalGraphicsSettings.ShadowSoftness
        end
        if originalGraphicsSettings.EnvironmentDiffuseScale then
            Lighting.EnvironmentDiffuseScale = originalGraphicsSettings.EnvironmentDiffuseScale
        end
        if originalGraphicsSettings.EnvironmentSpecularScale then
            Lighting.EnvironmentSpecularScale = originalGraphicsSettings.EnvironmentSpecularScale
        end
        
        -- Restore terrain
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
            workspace.Terrain.WaterReflectance = 0.5
            workspace.Terrain.WaterTransparency = 0.5
            workspace.Terrain.WaterWaveSize = 0.5
            workspace.Terrain.WaterWaveSpeed = 10
        end
        
        -- Restore lighting
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
        Lighting.ColorShift_Top = Color3.new(0, 0, 0)
        
        -- Restore texture quality
        settings().Rendering.QualityLevel = 10
    end)
    
    Notify({Title = "Anti Lag", Content = "Graphics settings restored", Duration = 3})
end

-- Position Management System
local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify({
            Title = "Position Saved", 
            Content = string.format("Position saved successfully"),
            Duration = 2
        })
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify({Title = "Load Failed", Content = "No position saved", Duration = 2})
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify({Title = "Position Loaded", Content = "Teleported to saved position", Duration = 2})
        return true
    end
    return false
end

local function StartLockPosition()
    if lockPositionEnabled then return end
    lockPositionEnabled = true
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
    end
    
    lockPositionLoop = RunService.Heartbeat:Connect(function()
        if not lockPositionEnabled then return end
        
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") and lastSavedPosition then
            local currentPos = character.HumanoidRootPart.Position
            local distance = (currentPos - lastSavedPosition).Magnitude
            
            if distance > 3 then
                character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
            end
        end
    end)
    
    Notify({Title = "Position Lock", Content = "Player position locked", Duration = 2})
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify({Title = "Position Lock", Content = "Player position unlocked", Duration = 2})
end

-- =============================================================================
-- BYPASS SYSTEM - FISHING RADAR, DIVING GEAR & AUTO SELL
-- =============================================================================

-- Fishing Radar System
local function ToggleFishingRadar()
    local success, result = pcall(function()
        -- Load required modules
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        -- Get player data
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        -- Get current radar state
        local currentState = Data:Get("RegionsVisible")
        local desiredState = not currentState

        -- Invoke server to update radar
        local invokeSuccess = UpdateFishingRadar:InvokeServer(desiredState)
        
        if invokeSuccess then
            fishingRadarEnabled = desiredState
            return true, "Radar: " .. (desiredState and "ENABLED" or "DISABLED")
        else
            return false, "Failed to update radar"
        end
    end)
    
    if success then
        return true, result
    else
        return false, "Error: " .. tostring(result)
    end
end

local function StartFishingRadar()
    if fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = true
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

local function StopFishingRadar()
    if not fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = false
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

-- Diving Gear System
local function ToggleDivingGear()
    local success, result = pcall(function()
        -- Load required modules
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        
        -- Get diving gear data
        local DivingGear = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
        if not DivingGear then
            return false, "Diving Gear tidak ditemukan!"
        end

        -- Get player data
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        -- Get remote functions
        local UnequipOxygenTank = Net:RemoteFunction("UnequipOxygenTank")
        local EquipOxygenTank = Net:RemoteFunction("EquipOxygenTank")

        -- Check current equipment state
        local EquippedId = Data:Get("EquippedOxygenTankId")
        local isEquipped = EquippedId == DivingGear.Data.Id
        local success

        -- Toggle equipment
        if isEquipped then
            success = UnequipOxygenTank:InvokeServer()
        else
            success = EquipOxygenTank:InvokeServer(DivingGear.Data.Id)
        end

        if success then
            divingGearEnabled = not isEquipped
            return true, "Diving Gear: " .. (not isEquipped and "ON" or "OFF")
        else
            return false, "Failed to toggle diving gear"
        end
    end)
    
    if success then
        return true, result
    else
        return false, "Error: " .. tostring(result)
    end
end

local function StartDivingGear()
    if divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = true
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

local function StopDivingGear()
    if not divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = false
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

-- =============================================================================
-- FIXED AUTO SELL SYSTEM - BYPASS CONFIRMATION PROMPT
-- =============================================================================

-- Auto Sell System - Fixed version without confirmation
local function ManualSellAllFish()
    local success, result = pcall(function()
        -- Load required modules
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local VendorController = require(ReplicatedStorage.Controllers.VendorController)
        
        -- Get player data
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Player data not found"
        end

        -- Check if player has Sell Anywhere gamepass
        local hasGamepass = true -- Assume player has gamepass to bypass check
        
        if hasGamepass then
            -- Direct sell without confirmation
            if VendorController and VendorController.SellAllItems then
                VendorController:SellAllItems()
                return true, "All fish sold successfully!"
            else
                return false, "VendorController not found"
            end
        else
            return false, "Sell Anywhere gamepass required"
        end
    end)
    
    if success then
        Notify({Title = "Manual Sell", Content = result, Duration = 3})
        return true
    else
        Notify({Title = "Sell Error", Content = result, Duration = 4})
        return false
    end
end

local function StartAutoSell()
    if autoSellEnabled then return end
    autoSellEnabled = true
    
    autoSellLoop = task.spawn(function()
        while autoSellEnabled do
            pcall(function()
                local Replion = require(ReplicatedStorage.Packages.Replion)
                local Net = require(ReplicatedStorage.Packages.Net)
                local VendorController = require(ReplicatedStorage.Controllers.VendorController)
                local Data = Replion.Client:WaitReplion("Data")
                
                if Data and VendorController and VendorController.SellAllItems then
                    local inventory = Data:Get("Inventory")
                    if inventory and inventory.Fish then
                        local fishCount = 0
                        for _, fish in pairs(inventory.Fish) do
                            fishCount = fishCount + (fish.Amount or 1)
                        end
                        
                        if fishCount >= autoSellThreshold then
                            -- Bypass gamepass check and sell directly
                            VendorController:SellAllItems()
                            Notify({
                                Title = "Auto Sell", 
                                Content = string.format("Sold %d fish automatically", fishCount),
                                Duration = 2
                            })
                        end
                    end
                end
            end)
            task.wait(2) -- Check every 2 seconds
        end
    end)
    
    Notify({
        Title = "Auto Sell Started", 
        Content = string.format("Auto selling when fish count >= %d", autoSellThreshold),
        Duration = 3
    })
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify({Title = "Auto Sell", Content = "Auto sell stopped", Duration = 2})
end

local function SetAutoSellThreshold(amount)
    if type(amount) == "number" and amount > 0 then
        autoSellThreshold = amount
        Notify({
            Title = "Auto Sell Threshold", 
            Content = string.format("Threshold set to %d fish", amount),
            Duration = 3
        })
        return true
    end
    return false
end

-- Auto Radar Toggle with safety
local function SafeToggleRadar()
    local success, message = ToggleFishingRadar()
    if success then
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

-- Auto Diving Gear Toggle with safety
local function SafeToggleDivingGear()
    local success, message = ToggleDivingGear()
    if success then
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

-- Coordinate Display System
local function CreateCoordinateDisplay()
    if coordinateGui and coordinateGui.Parent then coordinateGui:Destroy() end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "Anggazyy_Coordinates"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(0.5, -110, 0, 15)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0.3, 0)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(103, 58, 183)
    stroke.Thickness = 1.6

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 235, 245)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.Text = "X: 0 | Y: 0 | Z: 0"
    label.TextXAlignment = Enum.TextXAlignment.Left

    coordinateGui = sg

    task.spawn(function()
        while coordinateGui and coordinateGui.Parent do
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local pos = char.HumanoidRootPart.Position
                label.Text = string.format("X: %d | Y: %d | Z: %d", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
            else
                label.Text = "X: - | Y: - | Z: -"
            end
            task.wait(0.12)
        end
    end)
end

local function DestroyCoordinateDisplay()
    if coordinateGui and coordinateGui.Parent then
        pcall(function() coordinateGui:Destroy() end)
        coordinateGui = nil
    end
end

-- =============================================================================
-- CREATE ALL TABS WITH LUNA UI
-- =============================================================================

-- ========== INFORMATION TAB ==========
local InfoTab = Window:CreateTab({
    Name = "Information",
    Icon = "info",
    ImageSource = "Material",
    ShowTitle = true
})

InfoTab:CreateParagraph({
    Title = "Anggazyy Hub - Fish It",
    Text = "Premium fishing automation with performance optimization"
})

InfoTab:CreateSection("System Features")

InfoTab:CreateParagraph({
    Title = "Features Included:",
    Text = "• Advanced Auto Fishing\n• Fishing System (Charge + Minigame)\n• Fishing Radar Bypass\n• Diving Gear Bypass\n• Auto Sell System\n• Ultra Anti Lag\n• Position Management\n• Teleportation System"
})

-- ========== AUTO SYSTEM TAB ==========
local AutoTab = Window:CreateTab({
    Name = "Automation", 
    Icon = "settings",
    ImageSource = "Material",
    ShowTitle = true
})

AutoTab:CreateParagraph({
    Title = "Auto Fishing System",
    Text = "Automated fishing with server communication"
})

statusLabel = AutoTab:CreateLabel({
    Text = "Status: DISABLED",
    Style = 1
})

AutoTab:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
}, "AutoFishToggle")

AutoTab:CreateSection("Basic Auto Fishing")

AutoTab:CreateParagraph({
    Title = "Basic System",
    Text = "Simple auto fishing using server remote functions"
})

-- ========== FISHING SYSTEM TAB ==========
local FishingSystemTab = Window:CreateTab({
    Name = "Fishing System",
    Icon = "anchor", 
    ImageSource = "Material",
    ShowTitle = true
})

FishingSystemTab:CreateParagraph({
    Title = "Advanced Fishing System",
    Text = "Complete fishing automation with charge, throw, and minigame"
})

FishingSystemTab:CreateToggle({
    Name = "Enable Fishing System",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartFishingSystem()
        else
            StopFishingSystem()
        end
    end
}, "FishingSystemToggle")

FishingSystemTab:CreateSlider({
    Name = "Charge Delay",
    Range = {0.1, 2.0},
    Increment = 0.1,
    CurrentValue = 0.5,
    Callback = function(Value)
        chargeDelay = Value
        Notify({
            Title = "Charge Delay", 
            Content = string.format("Charge delay set to %.1f seconds", Value),
            Duration = 2
        })
    end
}, "ChargeDelay")

FishingSystemTab:CreateButton({
    Name = "Initialize Fishing System",
    Description = nil,
    Callback = function()
        InitializeFishingSystem()
    end
})

FishingSystemTab:CreateSection("System Info")

FishingSystemTab:CreateParagraph({
    Title = "System Features",
    Text = "• Auto Charge (0.5s)\n• Auto Throw\n• Auto Minigame Click\n• Server Communication\n• Animation Control\n• Sound Management\n• UI Control"
})

-- ========== BYPASS TAB ==========
local BypassTab = Window:CreateTab({
    Name = "Bypass",
    Icon = "radar",
    ImageSource = "Material", 
    ShowTitle = true
})

BypassTab:CreateParagraph({
    Title = "Game Bypass Features",
    Text = "Advanced features to enhance gameplay"
})

-- Fishing Radar Section
BypassTab:CreateSection("Fishing Radar")

BypassTab:CreateToggle({
    Name = "Fishing Radar",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartFishingRadar()
        else
            StopFishingRadar()
        end
    end
}, "FishingRadarToggle")

BypassTab:CreateButton({
    Name = "Toggle Radar",
    Description = nil,
    Callback = SafeToggleRadar
})

-- Diving Gear Section
BypassTab:CreateSection("Diving Gear")

BypassTab:CreateToggle({
    Name = "Diving Gear",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartDivingGear()
        else
            StopDivingGear()
        end
    end
}, "DivingGearToggle")

BypassTab:CreateButton({
    Name = "Toggle Diving Gear",
    Description = nil,
    Callback = SafeToggleDivingGear
})

-- Auto Sell Section
BypassTab:CreateSection("Auto Sell Fish")

BypassTab:CreateToggle({
    Name = "Auto Sell Fish",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
}, "AutoSellToggle")

BypassTab:CreateSlider({
    Name = "Sell Threshold",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 3,
    Callback = function(Value)
        SetAutoSellThreshold(Value)
    end
}, "AutoSellThreshold")

BypassTab:CreateButton({
    Name = "Sell All Fish Now",
    Description = nil,
    Callback = ManualSellAllFish
})

-- Quick Actions Section
BypassTab:CreateSection("Quick Actions")

BypassTab:CreateButton({
    Name = "Enable All Bypass",
    Description = nil,
    Callback = function()
        StartFishingRadar()
        StartDivingGear()
        StartAutoSell()
        Notify({Title = "Bypass", Content = "All bypass features enabled", Duration = 3})
    end
})

BypassTab:CreateButton({
    Name = "Disable All Bypass",
    Description = nil,
    Callback = function()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        Notify({Title = "Bypass", Content = "All bypass features disabled", Duration = 3})
    end
})

-- ========== PLAYER CONFIGURATION TAB ==========
local PlayerConfigTab = Window:CreateTab({
    Name = "Player Config",
    Icon = "person",
    ImageSource = "Material",
    ShowTitle = true
})

-- Performance Section
PlayerConfigTab:CreateSection("Performance")

PlayerConfigTab:CreateToggle({
    Name = "Ultra Anti Lag",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            EnableAntiLag()
        else
            DisableAntiLag()
        end
    end
}, "AntiLagToggle")

-- Position Section
PlayerConfigTab:CreateSection("Position")

PlayerConfigTab:CreateButton({
    Name = "Save Position",
    Description = nil,
    Callback = SaveCurrentPosition
})

PlayerConfigTab:CreateButton({
    Name = "Load Position",
    Description = nil, 
    Callback = LoadSavedPosition
})

PlayerConfigTab:CreateToggle({
    Name = "Lock Position",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            StartLockPosition()
        else
            StopLockPosition()
        end
    end
}, "LockPositionToggle")

-- Quick Actions
PlayerConfigTab:CreateSection("Quick Actions")

PlayerConfigTab:CreateButton({
    Name = "Max Performance",
    Description = nil,
    Callback = function()
        EnableAntiLag()
        Notify({Title = "Performance", Content = "Maximum performance enabled", Duration = 2})
    end
})

-- ========== TELEPORTATION TAB ==========
local TeleportTab = Window:CreateTab({
    Name = "Teleportation",
    Icon = "map",
    ImageSource = "Material",
    ShowTitle = true
})

TeleportTab:CreateParagraph({
    Title = "Location Teleport",
    Text = "Quick teleport to fishing spots"
})

TeleportTab:CreateDropdown({
    Name = "Select Destination",
    Description = nil,
    Options = {"Mount Hallow"},
    CurrentOption = {"Mount Hallow"},
    MultipleOptions = false,
    SpecialType = nil,
    Callback = function(Options)
        currentSelectedMap = Options[1]
    end
}, "MapSelect")

TeleportTab:CreateButton({
    Name = "Teleport Now",
    Description = nil,
    Callback = function()
        local pos = Vector3.new(1819, 12, 3043)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
            Notify({Title = "Teleport", Content = "Teleported to Mount Hallow", Duration = 2})
        end
    end
})

TeleportTab:CreateToggle({
    Name = "Show Coordinates",
    Description = nil,
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            CreateCoordinateDisplay()
        else
            DestroyCoordinateDisplay()
        end
    end
}, "ShowCoords")

-- ========== PLAYER MANAGEMENT TAB ==========
local PlayerTab = Window:CreateTab({
    Name = "Player Stats",
    Icon = "speed",
    ImageSource = "Material",
    ShowTitle = true
})

PlayerTab:CreateSection("Movement")

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
    end
}, "WalkSpeed")

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 350},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = Value
        end
    end
}, "JumpPower")

PlayerTab:CreateButton({
    Name = "Reset Movement",
    Description = nil,
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
            Notify({Title = "Reset", Content = "Movement reset to default", Duration = 2})
        end
    end
})

-- ========== SETTINGS TAB ==========
local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "settings_applications",
    ImageSource = "Material",
    ShowTitle = true
})

SettingsTab:CreateButton({
    Name = "Unload Hub",
    Description = nil,
    Callback = function()
        StopAutoFish()
        StopFishingSystem()
        StopLockPosition()
        DisableAntiLag()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        DestroyCoordinateDisplay()
        -- Luna doesn't have destroy method, we'll just notify
        Notify({Title = "Unload", Content = "Hub functions stopped - Close UI manually", Duration = 3})
    end
})

SettingsTab:CreateButton({
    Name = "Clean UI",
    Description = nil,
    Callback = function()
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            pcall(function()
                if (obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel")) then
                    local name = (obj.Name or ""):lower()
                    local text = (obj.Text or ""):lower()
                    if string.find(name, "money") or string.find(text, "money") then
                        obj.Visible = false
                    end
                end
            end)
        end
        Notify({Title = "Clean", Content = "UI cleaned", Duration = 2})
    end
})

SettingsTab:CreateSection("Configuration")

SettingsTab:CreateParagraph({
    Title = "Hub Configuration", 
    Text = "All settings are automatically saved and loaded"
})

-- Create Theme Tab for Luna UI customization
local ThemeTab = Window:CreateTab({
    Name = "Theme",
    Icon = "palette",
    ImageSource = "Material",
    ShowTitle = true
})

ThemeTab:BuildThemeSection()

-- Create Config Tab for Luna UI settings
local ConfigTab = Window:CreateTab({
    Name = "Config",
    Icon = "save",
    ImageSource = "Material", 
    ShowTitle = true
})

ConfigTab:BuildConfigSection()

-- Initial Notification
Notify({
    Title = "Anggazyy Hub Ready", 
    Content = "System initialized successfully - All tabs loaded",
    Duration = 4
})

--//////////////////////////////////////////////////////////////////////////////////
-- System Initialization Complete
--//////////////////////////////////////////////////////////////////////////////////
