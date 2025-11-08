--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (COMPLETE WITH FISHING SYSTEM)
-- Rayfield UI + Lucide icons + Advanced Fishing Automation
-- Clean, modern, professional design
-- Author: Anggazyy (refactor + fishing system integration)
--//////////////////////////////////////////////////////////////////////////////////

-- CONFIG: ubah sesuai kebutuhan
local AUTO_FISH_REMOTE_NAME = "UpdateAutoFishingState"
local NET_PACKAGES_FOLDER = "Packages"
local RAYFIELD_URL = 'https://sirius.menu/rayfield'

-- Services & Variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer

-- =================================================================
-- FISHING SYSTEM IMPORTS (From Document 1)
-- =================================================================
local Signal, Trove, Net, spr, Constants, Soundbook, GuiControl, HUDController
local AnimationController, TextNotificationController, BlockedHumanoidStates

pcall(function()
    Signal = require(ReplicatedStorage.Packages.Signal)
    Trove = require(ReplicatedStorage.Packages.Trove)
    Net = require(ReplicatedStorage.Packages.Net)
    spr = require(ReplicatedStorage.Packages.spr)
    Constants = require(ReplicatedStorage.Shared.Constants)
    Soundbook = require(ReplicatedStorage.Shared.Soundbook)
    GuiControl = require(ReplicatedStorage.Modules.GuiControl)
    HUDController = require(ReplicatedStorage.Controllers.HUDController)
    AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
    TextNotificationController = require(ReplicatedStorage.Controllers.TextNotificationController)
    BlockedHumanoidStates = require(ReplicatedStorage.Shared.BlockedHumanoidStates)
end)

-- =================================================================
-- FISHING SYSTEM VARIABLES
-- =================================================================
local PlayerGui = LocalPlayer.PlayerGui
local Charge_upvr, Fishing_upvr, Main_upvr, CanvasGroup_upvr

pcall(function()
    Charge_upvr = PlayerGui:WaitForChild("Charge", 5)
    Fishing_upvr = PlayerGui:WaitForChild("Fishing", 5)
    if Fishing_upvr then
        Main_upvr = Fishing_upvr.Main
        CanvasGroup_upvr = Main_upvr.Display.CanvasGroup
    end
end)

-- Fishing Internal Variables
local var17_upvw = nil 
local var32_upvw = false 
local var34_upvw = false
local var35_upvw = nil
local var36_upvw = nil
local var37_upvw = nil
local var38_upvw = 0
local var40_upvw = nil
local var109_upvw = false

-- Trove untuk pembersihan koneksi
local fishingTrove = Trove and Trove.new() or nil
local chargeTrove = Trove and Trove.new() or nil
local minigameTrove = Trove and Trove.new() or nil

-- Signal untuk Minigame Changes
local MinigameChangedSignal = Signal and Signal.new() or nil

-- Original System Variables
local autoFishEnabled = false
local autoFishLoopThread = nil
local coordinateGui = nil
local statusParagraph = nil
local currentSelectedMap = nil

-- Advanced Fishing System Variables
local advancedFishingEnabled = false
local autoChargeDelay = 0.6
local autoMinigameEnabled = true

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

-- UI Configuration
local COLOR_ENABLED = Color3.fromRGB(76, 175, 80)
local COLOR_DISABLED = Color3.fromRGB(244, 67, 54)
local COLOR_PRIMARY = Color3.fromRGB(103, 58, 183)
local COLOR_SECONDARY = Color3.fromRGB(30, 30, 46)

-- =================================================================
-- FISHING SYSTEM HELPER FUNCTIONS
-- =================================================================

local function RefreshIdle() 
    pcall(function()
        if AnimationController then
            AnimationController:StopAnimation("ReelingIdle")
            AnimationController:StopAnimation("ReelStart")
        end
    end)
end

local function FishingRodEquipped(id) 
    return id ~= nil 
end

local function GetItemDataFromEquippedItem(id) 
    if not id then return nil end
    return { Data = { Type = "Fishing Rods", Name = "FishingRodSound" } }
end

-- =================================================================
-- FISHING SYSTEM NETWORK COMMUNICATION
-- =================================================================

local CastFishingRod_Net, FishingMinigameStarted_Net, FishingCompleted_Net, ChargeFishingRod_Net

pcall(function()
    if Net then
        CastFishingRod_Net = Net:RemoteFunction("RequestFishingMinigameStarted")
        FishingMinigameStarted_Net = Net:RemoteEvent("FishingMinigameStarted")
        FishingCompleted_Net = Net:RemoteEvent("FishingCompleted")
        ChargeFishingRod_Net = Net:RemoteFunction("ChargeFishingRod")
    end
end)

-- =================================================================
-- FISHING SYSTEM CORE FUNCTIONS
-- =================================================================

-- Minigame Click Function
local function FishingMinigameClick()
    if not var36_upvw or not var37_upvw then return end
    
    local currentTime = workspace:GetServerTimeNow()
    
    if currentTime - var37_upvw.LastInput < 0.1 then return end
    
    local clamped = math.clamp(var37_upvw.Progress + var37_upvw.FishingClickPower, 0, 1)
    
    var37_upvw.LastInput = currentTime
    var37_upvw.Progress = clamped
    
    local var48 = var37_upvw
    var48.Inputs = (var48.Inputs or 0) + 1

    if MinigameChangedSignal then
        MinigameChangedSignal:Fire(var37_upvw)
    end
    
    if clamped >= 1 then
        if minigameTrove then minigameTrove:Clean() end
        if FishingCompleted_Net then
            FishingCompleted_Net:FireServer()
        end
        print("[Advanced Fishing] Minigame Completed!")
    end
    
    return true
end

-- Auto Clicker
local AutoClickerConnection = nil

local function StartAutoMinigameClicker()
    if AutoClickerConnection then 
        AutoClickerConnection:Disconnect()
        AutoClickerConnection = nil
    end

    print("[Advanced Fishing] Auto Clicker Activated!")
    AutoClickerConnection = RunService.Heartbeat:Connect(FishingMinigameClick)
    if minigameTrove then
        minigameTrove:Add(AutoClickerConnection)
    end
end

local function StopAutoMinigameClicker()
    if AutoClickerConnection then
        AutoClickerConnection:Disconnect()
        AutoClickerConnection = nil
        if minigameTrove then minigameTrove:Clean() end
        print("[Advanced Fishing] Auto Clicker Stopped")
    end
end

-- Fishing Rod Started (Minigame)
local function FishingRodStarted(data)
    if var36_upvw then return end
    
    print("[Advanced Fishing] Fish Bite Detected! Starting Minigame...")

    pcall(function()
        if AnimationController then
            AnimationController:StopAnimation("ReelingIdle")
            AnimationController:StopAnimation("ReelStart")
            AnimationController:PlayAnimation("ReelIntermission")
        end
    end)
    
    var36_upvw = data.UUID
    var37_upvw = data

    pcall(function()
        if Soundbook and spr then
            local reelSound = Soundbook.Sounds.Reel:Play()
            var40_upvw = reelSound
            reelSound.Volume = 0
            spr.target(reelSound, 5, 10, { Volume = Soundbook.Sounds.Reel.Volume })
            
            if minigameTrove then
                minigameTrove:Add(function()
                    spr.stop(reelSound)
                    spr.target(reelSound, 5, 10, { Volume = 0 })
                    task.wait(0.25)
                    reelSound:Stop()
                    reelSound:Destroy()
                end)
            end
        end
    end)
    
    pcall(function()
        if Fishing_upvr and spr and GuiControl then
            spr.stop(Fishing_upvr.Main)
            spr.target(Fishing_upvr.Main, 50, 250, { Position = UDim2.fromScale(0.5, 0.95) })
            GuiControl:SetHUDVisibility(false)
            Fishing_upvr.Enabled = true
        end
    end)

    if autoMinigameEnabled then
        StartAutoMinigameClicker()
    end
end

-- Send Fishing Request
local function SendFishingRequestToServer(power)
    local throwPosition = LocalPlayer.Character.HumanoidRootPart.CFrame.Position + Vector3.new(0, -1, 10)
    local castTime = workspace:GetServerTimeNow()
    
    if not CastFishingRod_Net then return false end
    
    local success, responseData = pcall(function()
        return CastFishingRod_Net:InvokeServer(throwPosition.Y, power, castTime)
    end)

    if success and responseData then
        print("[Advanced Fishing] Cast successful! Waiting for bite...")
        return true
    else
        if TextNotificationController then
            TextNotificationController:DeliverNotification({
                Type = "Text", 
                Text = "Cast failed: " .. tostring(responseData),
                TextColor = { R = 255, G = 0, B = 0 }, 
                CustomDuration = 3.5
            })
        end
        return false
    end
end

-- Fishing Stopped
local function FishingStopped(isSuccessful)
    if var34_upvw then return end
    
    var34_upvw = true
    
    local isCatch = isSuccessful or (var37_upvw and var37_upvw.Progress >= 1)
    
    StopAutoMinigameClicker()

    pcall(function()
        if not isCatch then
            if AnimationController then
                AnimationController:DestroyActiveAnimationTracks()
                AnimationController:PlayAnimation("FishingFailure")
            end
        else
            if AnimationController then
                AnimationController:DestroyActiveAnimationTracks({"EquipIdle"})
            end
            RefreshIdle()
        end
    end)
    
    pcall(function()
        if HUDController and HUDController.ResetCamera then
            HUDController.ResetCamera()
        end
    end)
    
    pcall(function()
        if Fishing_upvr and spr then
            if isCatch then
                spr.stop(Fishing_upvr.Main)
                spr.target(Fishing_upvr.Main, 100, 150, { Position = UDim2.fromScale(0.5, 0.9) })
                task.wait(0.15)
            end

            spr.stop(Fishing_upvr.Main)
            spr.target(Fishing_upvr.Main, 50, 100, { Position = UDim2.fromScale(0.5, 1.5) })
            task.wait(0.45)
        end
    end)
    
    if chargeTrove then chargeTrove:Clean() end
    if minigameTrove then minigameTrove:Clean() end
    
    pcall(function()
        if GuiControl then
            GuiControl:SetHUDVisibility(true)
        end
    end)
    
    var38_upvw = workspace:GetServerTimeNow()
    var34_upvw = false
    var37_upvw = nil
    var36_upvw = nil
    
    print("[Advanced Fishing] Cycle Complete! Ready for next cast.")
end

-- Internal Throw Function
local function internal_DoThrow(chargePower, clientRequestDestroy)
    pcall(function()
        if AnimationController then
            AnimationController:DestroyActiveAnimationTracks()
            AnimationController:PlayAnimation("RodThrow")
        end
    end)
    
    pcall(function()
        local itemData = GetItemDataFromEquippedItem(var17_upvw and var17_upvw.Data.EquippedId)
        local sound = Soundbook and Soundbook.Sounds.ThrowCast
        if itemData and Soundbook and Soundbook.Sounds[itemData.Data.Name] then
            sound = Soundbook.Sounds[itemData.Data.Name]
        end
        if sound then
            sound:Play().Volume = 0.5 + math.random() * 0.75
        end
    end)

    local didServerAccept = SendFishingRequestToServer(chargePower)
    
    if not didServerAccept then
        task.wait(0.1)
        FishingStopped(false)
        if clientRequestDestroy then clientRequestDestroy() end
    end
end

-- Start Advanced Auto Fishing
local function StartAdvancedAutoFishing(chargeDelaySeconds)
    chargeDelaySeconds = chargeDelaySeconds or autoChargeDelay
    
    if var109_upvw or var34_upvw then
        warn("[Advanced Fishing] Already running or stopping.")
        return
    end

    if workspace:GetServerTimeNow() - var38_upvw < (Constants and Constants.FishingCooldownTime or 2) then
        print("[Advanced Fishing] Still on cooldown!")
        return
    end
    
    local rodData = GetItemDataFromEquippedItem(var17_upvw and var17_upvw.Data.EquippedId)
    if not rodData or rodData.Data.Type ~= "Fishing Rods" then
        print("[Advanced Fishing] No fishing rod equipped!")
        return
    end
    
    var109_upvw = true
    
    pcall(function()
        if AnimationController then
            AnimationController:StopAnimation("EquipIdle")
            AnimationController:PlayAnimation("StartRodCharge")
        end
    end)
    
    print(string.format("[Advanced Fishing] Charging for %.2f seconds...", chargeDelaySeconds))
    
    var35_upvw = workspace:GetServerTimeNow()
    
    if ChargeFishingRod_Net then
        pcall(function()
            ChargeFishingRod_Net:InvokeServer(nil, nil, nil, var35_upvw)
        end)
    end
    
    if chargeTrove then
        chargeTrove:Add(function()
            var109_upvw = false
            if AnimationController then
                AnimationController:StopAnimation("StartRodCharge")
                AnimationController:StopAnimation("LoopedRodCharge")
            end
            RefreshIdle()
        end)
    end
    
    task.delay(chargeDelaySeconds, function()
        local throwPower = Constants and Constants:GetPower(var35_upvw) or 0.8
        
        if chargeTrove then chargeTrove:Clean() end
        var109_upvw = false

        internal_DoThrow(throwPower, function() FishingStopped(false) end) 
    end)
end

-- Setup Fishing Event Listeners
pcall(function()
    if fishingTrove and FishingMinigameStarted_Net then
        fishingTrove:Add(FishingMinigameStarted_Net:Connect(function(data)
            FishingRodStarted(data)
        end))
    end
    
    if fishingTrove and Net then
        local stopEvent = Net:RemoteEvent("FishingMinigameStop")
        if stopEvent then
            fishingTrove:Add(stopEvent:Connect(function(isSuccess)
                FishingStopped(isSuccess)
            end))
        end
    end
end)

-- =================================================================
-- AUTO-CLEAN MONEY ICONS
-- =================================================================

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

-- =================================================================
-- RAYFIELD LOADER
-- =================================================================

local successLoad, Rayfield = pcall(function()
    return loadstring(game:HttpGet(RAYFIELD_URL))()
end)
if not successLoad or not Rayfield then
    warn("Rayfield loading failed. Please check your executor configuration.")
    return
end

-- =================================================================
-- NOTIFICATION SYSTEM
-- =================================================================

local function Notify(opts)
    pcall(function()
        Rayfield:Notify({
            Title = opts.Title or "Notification",
            Content = opts.Content or "",
            Duration = opts.Duration or 3,
            Image = opts.Image or 4483362458
        })
    end)
end

-- =================================================================
-- NETWORK COMMUNICATION (ORIGINAL)
-- =================================================================

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
-- AUTO FISHING SYSTEM (ORIGINAL)
-- =================================================================

local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    if statusParagraph then 
        pcall(function() 
            statusParagraph:Set("Status: ACTIVE")
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
    if statusParagraph then 
        pcall(function() 
            statusParagraph:Set("Status: DISABLED")
        end) 
    end
    Notify({Title = "Auto Fishing", Content = "System deactivated", Duration = 2})
    
    pcall(function()
        SafeInvokeAutoFishing(false)
    end)
end

-- =================================================================
-- ADVANCED FISHING SYSTEM CONTROLS
-- =================================================================

local advancedFishingLoop = nil

local function StartAdvancedFishingLoop()
    if advancedFishingEnabled then return end
    advancedFishingEnabled = true
    
    Notify({Title = "Advanced Fishing", Content = "Advanced system activated", Duration = 2})
    
    advancedFishingLoop = task.spawn(function()
        while advancedFishingEnabled do
            if not var109_upvw and not var34_upvw and not var36_upvw then
                pcall(function()
                    StartAdvancedAutoFishing(autoChargeDelay)
                end)
                task.wait(6)
            else
                task.wait(1)
            end
        end
    end)
end

local function StopAdvancedFishingLoop()
    if not advancedFishingEnabled then return end
    advancedFishingEnabled = false
    
    StopAutoMinigameClicker()
    var109_upvw = false
    var34_upvw = false
    
    Notify({Title = "Advanced Fishing", Content = "Advanced system deactivated", Duration = 2})
end

-- =================================================================
-- ULTRA ANTI LAG SYSTEM
-- =================================================================

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

local function EnableAntiLag()
    if antiLagEnabled then return end
    
    SaveOriginalGraphics()
    antiLagEnabled = true
    
    pcall(function()
        UserGameSettings.GraphicsQualityLevel = 1
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 5
        Lighting.ShadowSoftness = 0
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
        end
        
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                if obj:FindFirstChildOfClass("Texture") then
                    obj:FindFirstChildOfClass("Texture"):Destroy()
                end
                if obj:FindFirstChildOfClass("Decal") then
                    obj:FindFirstChildOfClass("Decal"):Destroy()
                end
                obj.Material = Enum.Material.SmoothPlastic
                obj.BrickColor = BrickColor.new("White")
                obj.Reflectance = 0
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Beam") or obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Sound") and not obj:FindFirstAncestorWhichIsA("Player") then
                obj:Stop()
            end
        end
        
        settings().Rendering.QualityLevel = 1
    end)
    
    Notify({Title = "Ultra Anti Lag", Content = "White texture mode enabled", Duration = 3})
end

local function DisableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    
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
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
            workspace.Terrain.WaterReflectance = 0.5
            workspace.Terrain.WaterTransparency = 0.5
        end
        
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        
        settings().Rendering.QualityLevel = 10
    end)
    
    Notify({Title = "Anti Lag", Content = "Graphics restored", Duration = 3})
end

-- =================================================================
-- POSITION MANAGEMENT
-- =================================================================

local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify({Title = "Position Saved", Content = "Position saved successfully", Duration = 2})
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

-- =================================================================
-- BYPASS SYSTEM
-- =================================================================

local function ToggleFishingRadar()
    local success, result = pcall(function()
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion not found!"
        end

        local currentState = Data:Get("RegionsVisible")
        local desiredState = not currentState

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

local function ToggleDivingGear()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        
        local DivingGear = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
        if not DivingGear then
            return false, "Diving Gear not found!"
        end

        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion not found!"
        end

        local UnequipOxygenTank = Net:RemoteFunction("UnequipOxygenTank")
        local EquipOxygenTank = Net:RemoteFunction("EquipOxygenTank")

        local EquippedId = Data:Get("EquippedOxygenTankId")
        local isEquipped = EquippedId == DivingGear.Data.Id
        local success

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

local function ManualSellAllFish()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local VendorController = require(ReplicatedStorage.Controllers.VendorController)
        
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Player data not found"
        end

        local hasGamepass = true
        
        if hasGamepass then
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
            task.wait(2)
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

local function SafeToggleRadar()
    local success, message = ToggleFishingRadar()
    if success then
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

local function SafeToggleDivingGear()
    local success, message = ToggleDivingGear()
    if success then
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

-- =================================================================
-- COORDINATE DISPLAY
-- =================================================================

local function CreateCoordinateDisplay()
    if coordinateGui and coordinateGui.Parent then coordinateGui:Destroy() end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "Anggazyy_Coordinates"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(0.5, -110, 0, 15)
    frame.BackgroundColor3 = COLOR_SECONDARY
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0.3, 0)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = COLOR_PRIMARY
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

-- =================================================================
-- MAIN WINDOW CREATION
-- =================================================================

local Window = Rayfield:CreateWindow({
    Name = "Anggazyy Hub - Fish It",
    Icon = "fish",
    LoadingTitle = "Anggazyy Hub",
    LoadingSubtitle = "Premium Automation System",
    Theme = "Dark",
    ShowText = "AnggazyyHub",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AnggazyyHubConfig",
        FileName = "FishIt_Config"
    }
})

-- =================================================================
-- INFORMATION TAB
-- =================================================================

local InfoTab = Window:CreateTab("Information", "info")

InfoTab:CreateParagraph({
    Title = "Anggazyy Hub - Fish It",
    Content = "Premium fishing automation with advanced systems and performance optimization"
})

InfoTab:CreateParagraph({
    Title = "Features:",
    Content = "• Basic Auto Fishing\n• Advanced Fishing System\n• Bypass Features\n• Performance Optimization\n• Position Management"
})

-- =================================================================
-- AUTO SYSTEM TAB
-- =================================================================

local AutoTab = Window:CreateTab("Automation", "fish")

AutoTab:CreateParagraph({
    Title = "Auto Fishing System",
    Content = "Choose between basic or advanced fishing automation"
})

statusParagraph = AutoTab:CreateParagraph({
    Title = "Status:",
    Content = "DISABLED"
})

AutoTab:CreateSection("Basic Auto Fishing")

AutoTab:CreateToggle({
    Name = "Enable Basic Auto Fishing",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(state)
        if state then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
})

-- =================================================================
-- FISHING SYSTEM TAB (NEW)
-- =================================================================

local FishingTab = Window:CreateTab("Fishing System", "zap")

FishingTab:CreateParagraph({
    Title = "Advanced Fishing System",
    Content = "Complete automation with charge control and auto minigame"
})

FishingTab:CreateSection("Advanced Fishing Controls")

FishingTab:CreateToggle({
    Name = "Enable Advanced Fishing",
    CurrentValue = false,
    Flag = "AdvancedFishingToggle",
    Callback = function(state)
        if state then
            StartAdvancedFishingLoop()
        else
            StopAdvancedFishingLoop()
        end
    end
})

FishingTab:CreateSlider({
    Name = "Charge Delay",
    Range = {0.3, 2.0},
    Increment = 0.1,
    CurrentValue = 0.6,
    Suffix = "seconds",
    Flag = "ChargeDelay",
    Callback = function(value)
        autoChargeDelay = value
        Notify({
            Title = "Charge Delay", 
            Content = string.format("Set to %.1f seconds", value),
            Duration = 2
        })
    end
})

FishingTab:CreateToggle({
    Name = "Auto Minigame Clicker",
    CurrentValue = true,
    Flag = "AutoMinigame",
    Callback = function(state)
        autoMinigameEnabled = state
        Notify({
            Title = "Auto Minigame", 
            Content = state and "Enabled" or "Disabled",
            Duration = 2
        })
    end
})

FishingTab:CreateButton({
    Name = "Single Cast Test",
    Callback = function()
        if not var109_upvw and not var34_upvw then
            StartAdvancedAutoFishing(autoChargeDelay)
            Notify({Title = "Test Cast", Content = "Performing single cast", Duration = 2})
        else
            Notify({Title = "Busy", Content = "Already casting or in minigame", Duration = 2})
        end
    end
})

FishingTab:CreateSection("Minigame Controls")

FishingTab:CreateButton({
    Name = "Start Manual Clicker",
    Callback = function()
        if var36_upvw then
            StartAutoMinigameClicker()
            Notify({Title = "Manual Clicker", Content = "Started", Duration = 2})
        else
            Notify({Title = "No Minigame", Content = "Wait for fish bite", Duration = 2})
        end
    end
})

FishingTab:CreateButton({
    Name = "Stop Manual Clicker",
    Callback = function()
        StopAutoMinigameClicker()
        Notify({Title = "Manual Clicker", Content = "Stopped", Duration = 2})
    end
})

-- =================================================================
-- BYPASS TAB
-- =================================================================

local BypassTab = Window:CreateTab("Bypass", "radar")

BypassTab:CreateParagraph({
    Title = "Game Bypass Features",
    Content = "Advanced features to enhance gameplay"
})

BypassTab:CreateSection("Fishing Radar")

BypassTab:CreateToggle({
    Name = "Fishing Radar",
    CurrentValue = false,
    Flag = "FishingRadarToggle",
    Callback = function(state)
        if state then
            StartFishingRadar()
        else
            StopFishingRadar()
        end
    end
})

BypassTab:CreateButton({
    Name = "Toggle Radar",
    Callback = SafeToggleRadar
})

BypassTab:CreateSection("Diving Gear")

BypassTab:CreateToggle({
    Name = "Diving Gear",
    CurrentValue = false,
    Flag = "DivingGearToggle",
    Callback = function(state)
        if state then
            StartDivingGear()
        else
            StopDivingGear()
        end
    end
})

BypassTab:CreateButton({
    Name = "Toggle Diving Gear",
    Callback = SafeToggleDivingGear
})

BypassTab:CreateSection("Auto Sell Fish")

BypassTab:CreateToggle({
    Name = "Auto Sell Fish",
    CurrentValue = false,
    Flag = "AutoSellToggle",
    Callback = function(state)
        if state then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
})

BypassTab:CreateSlider({
    Name = "Sell Threshold",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 3,
    Suffix = "fish",
    Flag = "AutoSellThreshold",
    Callback = function(value)
        SetAutoSellThreshold(value)
    end
})

BypassTab:CreateButton({
    Name = "Sell All Fish Now",
    Callback = ManualSellAllFish
})

BypassTab:CreateSection("Quick Actions")

BypassTab:CreateButton({
    Name = "Enable All Bypass",
    Callback = function()
        StartFishingRadar()
        StartDivingGear()
        StartAutoSell()
        Notify({Title = "Bypass", Content = "All bypass features enabled", Duration = 3})
    end
})

BypassTab:CreateButton({
    Name = "Disable All Bypass",
    Callback = function()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        Notify({Title = "Bypass", Content = "All bypass features disabled", Duration = 3})
    end
})

-- =================================================================
-- PLAYER CONFIGURATION TAB
-- =================================================================

local PlayerConfigTab = Window:CreateTab("Player Config", "settings")

PlayerConfigTab:CreateSection("Performance")

PlayerConfigTab:CreateToggle({
    Name = "Ultra Anti Lag",
    CurrentValue = false,
    Flag = "AntiLagToggle",
    Callback = function(state)
        if state then
            EnableAntiLag()
        else
            DisableAntiLag()
        end
    end
})

PlayerConfigTab:CreateSection("Position")

PlayerConfigTab:CreateButton({
    Name = "Save Position",
    Callback = SaveCurrentPosition
})

PlayerConfigTab:CreateButton({
    Name = "Load Position", 
    Callback = LoadSavedPosition
})

PlayerConfigTab:CreateToggle({
    Name = "Lock Position",
    CurrentValue = false,
    Flag = "LockPositionToggle",
    Callback = function(state)
        if state then
            StartLockPosition()
        else
            StopLockPosition()
        end
    end
})

PlayerConfigTab:CreateSection("Quick Actions")

PlayerConfigTab:CreateButton({
    Name = "Max Performance",
    Callback = function()
        EnableAntiLag()
        Notify({Title = "Performance", Content = "Maximum performance enabled", Duration = 2})
    end
})

-- =================================================================
-- TELEPORTATION TAB
-- =================================================================

local TeleportTab = Window:CreateTab("Teleportation", "map-pin")

TeleportTab:CreateParagraph({
    Title = "Location Teleport",
    Content = "Quick teleport to fishing spots"
})

TeleportTab:CreateDropdown({
    Name = "Select Destination",
    Options = { "Mount Hallow" },
    CurrentOption = "Mount Hallow",
    Flag = "MapSelect",
    Callback = function(selected)
        currentSelectedMap = selected
    end
})

TeleportTab:CreateButton({
    Name = "Teleport Now",
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
    CurrentValue = false,
    Flag = "ShowCoords",
    Callback = function(v)
        if v then
            CreateCoordinateDisplay()
        else
            DestroyCoordinateDisplay()
        end
    end
})

-- =================================================================
-- PLAYER MANAGEMENT TAB
-- =================================================================

local PlayerTab = Window:CreateTab("Player Stats", "user")

PlayerTab:CreateSection("Movement")

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 16,
    Suffix = "studs/s",
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = val
        end
    end
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 350},
    Increment = 1,
    CurrentValue = 50,
    Suffix = "power",
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = val
        end
    end
})

PlayerTab:CreateButton({
    Name = "Reset Movement",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
            Notify({Title = "Reset", Content = "Movement reset to default", Duration = 2})
        end
    end
})

-- =================================================================
-- SETTINGS TAB
-- =================================================================

local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateButton({
    Name = "Unload Hub",
    Callback = function()
        StopAutoFish()
        StopAdvancedFishingLoop()
        StopLockPosition()
        DisableAntiLag()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        DestroyCoordinateDisplay()
        Rayfield:Destroy()
        Notify({Title = "Unload", Content = "Hub unloaded successfully", Duration = 2})
    end
})

SettingsTab:CreateButton({
    Name = "Clean UI",
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

-- =================================================================
-- VISUAL EFFECTS
-- =================================================================

pcall(function()
    local mainBG = Window.UIElements and Window.UIElements.MainFrame and Window.UIElements.MainFrame.Background
    if mainBG then
        task.spawn(function()
            local colors = {
                Color3.fromRGB(30, 18, 45),
                Color3.fromRGB(35, 22, 55),
                Color3.fromRGB(25, 18, 40),
            }
            local i = 1
            while task.wait(6) and mainBG.Parent do
                local nextI = i % #colors + 1
                local tween = TweenService:Create(mainBG, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = colors[nextI]})
                tween:Play()
                i = nextI
            end
        end)
    end
end)

-- =================================================================
-- CONFIGURATION LOADING & INITIALIZATION
-- =================================================================

Rayfield:LoadConfiguration()

Notify({
    Title = "Anggazyy Hub Ready", 
    Content = "Advanced Fishing System loaded successfully",
    Duration = 4
})

print("========================================")
print("Anggazyy Hub - Fish It COMPLETE")
print("Advanced Fishing System: LOADED")
print("All Features: READY")
print("========================================")

--//////////////////////////////////////////////////////////////////////////////////
-- System Initialization Complete
--//////////////////////////////////////////////////////////////////////////////////
