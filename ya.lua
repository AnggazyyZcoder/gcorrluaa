--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL) + Weather Machine + Trick or Treat
-- Luna Interface - Modern Glassmorphism Design
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
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local autoFishEnabled = false
local autoFishLoopThread = nil
local coordinateGui = nil
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

-- Weather System Variables
local selectedWeathers = {}
local availableWeathers = {}

-- Trick or Treat Variables
local autoTrickTreatEnabled = false
local trickTreatLoop = nil

-- UI Configuration
local COLOR_ENABLED = Color3.fromRGB(76, 175, 80)  -- Green
local COLOR_DISABLED = Color3.fromRGB(244, 67, 54) -- Red
local COLOR_PRIMARY = Color3.fromRGB(103, 58, 183) -- Purple

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

-- Luna Interface Loader
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

-- Create Main Window
local Window = Luna:CreateWindow({
	Name = "Anggazyy Hub - Fish It",
	Subtitle = "Premium Automation System",
	LogoID = nil,
	LoadingEnabled = true,
	LoadingTitle = "Anggazyy Hub",
	LoadingSubtitle = "Loading Premium Features...",

	ConfigSettings = {
		RootFolder = nil,
		ConfigFolder = "AnggazyyHub"
	},

	KeySystem = false,
	KeySettings = {
		Title = "Anggazyy Hub Access",
		Subtitle = "Premium Key System",
		Note = "Enter your access key to use Anggazyy Hub features",
		SaveInRoot = false,
		SaveKey = true,
		Key = {"AnggazyyPremium2024"},
		SecondAction = {
			Enabled = false,
			Type = "Link",
			Parameter = ""
		}
	}
})

-- Notification System
local function Notify(opts)
    pcall(function()
        Luna:Notification({ 
            Title = opts.Title or "Notification",
            Icon = "info",
            ImageSource = "Lucide",
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

-- =============================================================================
-- WEATHER MACHINE SYSTEM
-- =============================================================================

local function LoadWeatherData()
    local success, result = pcall(function()
        -- Load required modules
        local EventUtility = require(ReplicatedStorage.Shared.EventUtility)
        local StringLibrary = require(ReplicatedStorage.Shared.StringLibrary)
        local Events = require(ReplicatedStorage.Events)
        
        local weatherList = {}
        
        -- Iterate through all events to find weather machines
        for name, data in pairs(Events) do
            local event = EventUtility:GetEvent(name)
            if event and event.WeatherMachine and event.WeatherMachinePrice then
                table.insert(weatherList, {
                    Name = event.Name or name,
                    InternalName = name,
                    Price = event.WeatherMachinePrice,
                    DisplayName = string.format("%s - %s Coins", event.Name or name, StringLibrary:AddCommas(event.WeatherMachinePrice))
                })
            end
        end
        
        -- Sort by price (ascending)
        table.sort(weatherList, function(a, b)
            return a.Price < b.Price
        end)
        
        return weatherList
    end)
    
    if success then
        return result
    else
        warn("⚠️ Failed to load weather data:", result)
        return {}
    end
end

local function PurchaseWeather(weatherName)
    local success, result = pcall(function()
        -- Load required modules
        local Net = require(ReplicatedStorage.Packages.Net)
        local PurchaseWeatherEvent = Net:RemoteFunction("PurchaseWeatherEvent")
        
        -- Purchase the weather
        local purchaseResult = PurchaseWeatherEvent:InvokeServer(weatherName)
        return purchaseResult
    end)
    
    return success, result
end

local function BuySelectedWeathers()
    if not next(selectedWeathers) then
        Notify({
            Title = "Weather Purchase",
            Content = "No weathers selected!"
        })
        return
    end
    
    local totalPurchases = 0
    local successfulPurchases = 0
    
    Notify({
        Title = "Weather Purchase",
        Content = "Processing purchases..."
    })
    
    for weatherName, selected in pairs(selectedWeathers) do
        if selected then
            totalPurchases = totalPurchases + 1
            
            -- Find weather data
            local weatherData
            for _, weather in ipairs(availableWeathers) do
                if weather.InternalName == weatherName then
                    weatherData = weather
                    break
                end
            end
            
            if weatherData then
                local success, result = PurchaseWeather(weatherName)
                if success and result then
                    successfulPurchases = successfulPurchases + 1
                    Notify({
                        Title = "✅ Purchase Successful",
                        Content = string.format("Bought: %s", weatherData.Name)
                    })
                else
                    Notify({
                        Title = "❌ Purchase Failed",
                        Content = string.format("Failed to buy: %s", weatherData.Name)
                    })
                end
            end
            
            -- Small delay between purchases
            task.wait(0.5)
        end
    end
    
    -- Clear selection after purchase
    selectedWeathers = {}
    
    Notify({
        Title = "Purchase Complete",
        Content = string.format("Successfully purchased %d/%d weathers", successfulPurchases, totalPurchases)
    })
end

local function RefreshWeatherList()
    availableWeathers = LoadWeatherData()
    
    -- Create display options for dropdown
    local weatherOptions = {}
    for _, weather in ipairs(availableWeathers) do
        table.insert(weatherOptions, weather.DisplayName)
    end
    
    return weatherOptions, availableWeathers
end

local function ToggleWeatherSelection(weatherIndex, state)
    if availableWeathers[weatherIndex] then
        local weather = availableWeathers[weatherIndex]
        selectedWeathers[weather.InternalName] = state
        
        Notify({
            Title = state and "✅ Weather Selected" or "❌ Weather Deselected",
            Content = string.format("%s %s", weather.Name, state and "selected" or "deselected")
        })
    end
end

-- =============================================================================
-- TRICK OR TREAT SYSTEM
-- =============================================================================

local function GetSpecialDialogueRemote()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local SpecialDialogueEvent = Net:RemoteFunction("SpecialDialogueEvent")
        return SpecialDialogueEvent
    end)
    
    if success then
        return result
    else
        warn("❌ Failed to load SpecialDialogueEvent:", result)
        return nil
    end
end

local function FindTrickOrTreatDoors()
    local doors = {}
    
    for _, door in pairs(workspace:GetDescendants()) do
        if door:IsA("Model") and door:FindFirstChild("Root") and door:FindFirstChild("Door") and door.Name then
            if door:GetAttribute("TrickOrTreatDoor") or string.find(door.Name, "House") then
                table.insert(doors, door)
            end
        end
    end
    
    return doors
end

local function KnockDoor(door)
    local success, result = pcall(function()
        local SpecialDialogueEvent = GetSpecialDialogueRemote()
        if not SpecialDialogueEvent then
            return false, "Remote not found"
        end
        
        local success, reward = SpecialDialogueEvent:InvokeServer(door.Name, "TrickOrTreatHouse")
        return success, reward
    end)
    
    return success, result
end

local function StartAutoTrickTreat()
    if autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = true
    
    Notify({
        Title = "🎃 Auto Trick or Treat",
        Content = "System activated - Knocking all doors..."
    })
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            local doors = FindTrickOrTreatDoors()
            
            if #doors > 0 then
                Notify({
                    Title = "🎃 Trick or Treat",
                    Content = string.format("Found %d doors, knocking...", #doors)
                })
                
                for _, door in ipairs(doors) do
                    if not autoTrickTreatEnabled then break end
                    
                    local success, result = KnockDoor(door)
                    if success then
                        if result == "Trick" then
                            print("[🎃] Trick dari " .. door.Name)
                        elseif result == "Treat" then
                            print("[🍬] Treat dari " .. door.Name .. " → +" .. tostring(result) .. " Candy Corns")
                        else
                            print("[❌] Gagal interaksi dengan " .. door.Name)
                        end
                    else
                        print("[❌] Error knocking " .. door.Name .. ": " .. tostring(result))
                    end
                    
                    task.wait(0.5) -- Jeda biar gak spam server
                end
            else
                print("[🔍] Tidak ada Trick or Treat doors yang ditemukan")
            end
            
            -- Tunggu sebelum scan ulang
            task.wait(10)
        end
    end)
end

local function StopAutoTrickTreat()
    if not autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = false
    
    if trickTreatLoop then
        task.cancel(trickTreatLoop)
        trickTreatLoop = nil
    end
    
    Notify({
        Title = "🎃 Auto Trick or Treat",
        Content = "System deactivated"
    })
end

local function ManualKnockAllDoors()
    local doors = FindTrickOrTreatDoors()
    
    if #doors == 0 then
        Notify({
            Title = "🎃 Trick or Treat",
            Content = "No Trick or Treat doors found!"
        })
        return
    end
    
    Notify({
        Title = "🎃 Manual Knock",
        Content = string.format("Knocking %d doors...", #doors)
    })
    
    local successfulKnocks = 0
    local totalCandy = 0
    
    for _, door in ipairs(doors) do
        local success, result = KnockDoor(door)
        if success then
            successfulKnocks = successfulKnocks + 1
            if result == "Treat" then
                totalCandy = totalCandy + 1
            end
        end
        task.wait(0.5)
    end
    
    Notify({
        Title = "🎃 Knock Complete",
        Content = string.format("Success: %d/%d doors | Candy: +%d", successfulKnocks, #doors, totalCandy)
    })
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    
    Notify({
        Title = "Auto Fishing", 
        Content = "System activated successfully"
    })

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
    
    Notify({
        Title = "Auto Fishing", 
        Content = "System deactivated"
    })
    
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
    
    Notify({
        Title = "Ultra Anti Lag", 
        Content = "White texture mode enabled - Maximum performance"
    })
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
    
    Notify({
        Title = "Anti Lag", 
        Content = "Graphics settings restored"
    })
end

-- Position Management System
local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify({
            Title = "Position Saved", 
            Content = "Position saved successfully"
        })
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify({
            Title = "Load Failed", 
            Content = "No position saved"
        })
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify({
            Title = "Position Loaded", 
            Content = "Teleported to saved position"
        })
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
    
    Notify({
        Title = "Position Lock", 
        Content = "Player position locked"
    })
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify({
        Title = "Position Lock", 
        Content = "Player position unlocked"
    })
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
        Notify({
            Title = "Fishing Radar", 
            Content = message
        })
    else
        Notify({
            Title = "Radar Error", 
            Content = message
        })
    end
end

local function StopFishingRadar()
    if not fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = false
        Notify({
            Title = "Fishing Radar", 
            Content = message
        })
    else
        Notify({
            Title = "Radar Error", 
            Content = message
        })
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
        Notify({
            Title = "Diving Gear", 
            Content = message
        })
    else
        Notify({
            Title = "Diving Gear Error", 
            Content = message
        })
    end
end

local function StopDivingGear()
    if not divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = false
        Notify({
            Title = "Diving Gear", 
            Content = message
        })
    else
        Notify({
            Title = "Diving Gear Error", 
            Content = message
        })
    end
end

-- Auto Sell System
local function ManualSellAllFish()
    local success, result = pcall(function()
        local VendorController = require(ReplicatedStorage.Controllers.VendorController)
        if VendorController and VendorController.SellAllItems then
            VendorController:SellAllItems()
            return true, "All fish sold successfully!"
        else
            return false, "VendorController not found"
        end
    end)
    
    if success then
        Notify({
            Title = "Manual Sell", 
            Content = result
        })
    else
        Notify({
            Title = "Sell Error", 
            Content = result
        })
    end
end

local function StartAutoSell()
    if autoSellEnabled then return end
    autoSellEnabled = true
    
    autoSellLoop = task.spawn(function()
        while autoSellEnabled do
            pcall(function()
                local Replion = require(ReplicatedStorage.Packages.Replion)
                local Data = Replion.Client:WaitReplion("Data")
                local VendorController = require(ReplicatedStorage.Controllers.VendorController)
                
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
                                Content = string.format("Sold %d fish automatically", fishCount)
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
        Content = string.format("Auto selling when fish count >= %d", autoSellThreshold)
    })
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify({
        Title = "Auto Sell", 
        Content = "Auto sell stopped"
    })
end

local function SetAutoSellThreshold(amount)
    if type(amount) == "number" and amount > 0 then
        autoSellThreshold = amount
        Notify({
            Title = "Auto Sell Threshold", 
            Content = string.format("Threshold set to %d fish", amount)
        })
        return true
    end
    return false
end

-- Auto Radar Toggle with safety
local function SafeToggleRadar()
    local success, message = ToggleFishingRadar()
    if success then
        Notify({
            Title = "Fishing Radar", 
            Content = message
        })
    else
        Notify({
            Title = "Radar Error", 
            Content = message
        })
    end
end

-- Auto Diving Gear Toggle with safety
local function SafeToggleDivingGear()
    local success, message = ToggleDivingGear()
    if success then
        Notify({
            Title = "Diving Gear", 
            Content = message
        })
    else
        Notify({
            Title = "Diving Gear Error", 
            Content = message
        })
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
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
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

-- =============================================================================
-- UI CREATION WITH LUNA INTERFACE
-- =============================================================================

-- ========== HOME TAB ==========
Window:CreateHomeTab({
	SupportedExecutors = {"Synapse X", "ScriptWare", "Krnl", "Fluxus"},
	DiscordInvite = "",
	Icon = 1,
})

-- ========== MAIN TAB ==========
local MainTab = Window:CreateTab({
	Name = "Automation",
	Icon = "fish",
	ImageSource = "Lucide",
	ShowTitle = true
})

-- Create section first, then add elements
local AutoFishSection = MainTab:CreateSection("Auto Fishing System")

MainTab:CreateParagraph({
	Title = "Auto Fishing Status",
	Text = autoFishEnabled and "🟢 ACTIVE - Fishing automation running" or "🔴 DISABLED - System inactive"
})

local AutoFishToggle = MainTab:CreateToggle({
	Name = "Enable Auto Fishing",
	Description = "Automated fishing with server communication",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			StartAutoFish()
		else
			StopAutoFish()
		end
	end
}, "AutoFishToggle")

-- ========== WEATHER TAB ==========
local WeatherTab = Window:CreateTab({
	Name = "Weather Machine",
	Icon = "cloud",
	ImageSource = "Lucide",
	ShowTitle = true
})

-- Create sections for Weather Tab
local WeatherSection = WeatherTab:CreateSection("Weather Machine")

WeatherTab:CreateParagraph({
	Title = "Weather Machine",
	Text = "Purchase and activate different weather events"
})

-- Load weather data initially
availableWeathers = LoadWeatherData()

-- Weather Selection Dropdown
local weatherOptions = {}
for _, weather in ipairs(availableWeathers) do
    table.insert(weatherOptions, weather.DisplayName)
end

local WeatherDropdown = WeatherTab:CreateDropdown({
	Name = "Available Weathers",
	Description = "Select weather to purchase",
	Options = weatherOptions,
	CurrentOption = weatherOptions[1] or "No weathers available",
	MultipleOptions = false,
	SpecialType = nil,
	Callback = function(Option)
		-- Selection handled through toggles
	end
}, "WeatherDropdown")

-- Weather Selection Toggles
local weatherToggles = {}
for index, weather in ipairs(availableWeathers) do
	local toggle = WeatherTab:CreateToggle({
		Name = weather.DisplayName,
		Description = "Select this weather for purchase",
		CurrentValue = false,
		Callback = function(Value)
			ToggleWeatherSelection(index, Value)
		end
	}, "WeatherToggle_" .. weather.InternalName)
	table.insert(weatherToggles, toggle)
end

WeatherTab:CreateButton({
	Name = "Buy Selected Weathers",
	Description = "Purchase all selected weather events",
	Callback = BuySelectedWeathers
}, "BuyWeathersButton")

WeatherTab:CreateButton({
	Name = "Refresh Weather List",
	Description = "Reload available weather data",
	Callback = function()
		local newOptions, newWeathers = RefreshWeatherList()
		WeatherDropdown:Set({Options = newOptions})
		Notify({
			Title = "Weather List Updated",
			Content = string.format("Loaded %d available weathers", #newWeathers)
		})
	end
}, "RefreshWeatherButton")

-- ========== BYPASS TAB ==========
local BypassTab = Window:CreateTab({
	Name = "Bypass",
	Icon = "shield",
	ImageSource = "Lucide",
	ShowTitle = true
})

-- Fishing Radar Section
local FishingRadarSection = BypassTab:CreateSection("Fishing Radar")

local FishingRadarToggle = BypassTab:CreateToggle({
	Name = "Fishing Radar",
	Description = "Reveal fishing spots on the map",
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
	Description = "Quick toggle fishing radar",
	Callback = SafeToggleRadar
}, "ToggleRadarButton")

-- Diving Gear Section
local DivingGearSection = BypassTab:CreateSection("Diving Gear")

local DivingGearToggle = BypassTab:CreateToggle({
	Name = "Diving Gear",
	Description = "Automatically equip diving gear",
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
	Description = "Quick toggle diving gear",
	Callback = SafeToggleDivingGear
}, "ToggleDivingGearButton")

-- Auto Sell Section
local AutoSellSection = BypassTab:CreateSection("Auto Sell Fish")

local AutoSellToggle = BypassTab:CreateToggle({
	Name = "Auto Sell Fish",
	Description = "Automatically sell fish when threshold is reached",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			StartAutoSell()
		else
			StopAutoSell()
		end
	end
}, "AutoSellToggle")

local SellThresholdSlider = BypassTab:CreateSlider({
	Name = "Sell Threshold",
	Description = "Number of fish to trigger auto sell",
	Range = {1, 50},
	Increment = 1,
	CurrentValue = 3,
	Callback = function(Value)
		SetAutoSellThreshold(Value)
	end
}, "SellThresholdSlider")

BypassTab:CreateButton({
	Name = "Sell All Fish Now",
	Description = "Manually sell all fish immediately",
	Callback = ManualSellAllFish
}, "SellAllButton")

-- Trick or Treat Section
local TrickTreatSection = BypassTab:CreateSection("🎃 Trick or Treat")

local TrickTreatToggle = BypassTab:CreateToggle({
	Name = "Auto Trick or Treat",
	Description = "Automatically knock on all Trick or Treat doors",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			StartAutoTrickTreat()
		else
			StopAutoTrickTreat()
		end
	end
}, "TrickTreatToggle")

BypassTab:CreateButton({
	Name = "Knock All Doors Now",
	Description = "Manually knock on all doors once",
	Callback = ManualKnockAllDoors
}, "KnockDoorsButton")

BypassTab:CreateParagraph({
	Title = "Trick or Treat Info",
	Text = "Automatically knocks on all Trick or Treat doors\n🎃 = Trick | 🍬 = Treat (Candy Corns)"
})

-- Quick Actions Section
local QuickActionsSection = BypassTab:CreateSection("Quick Actions")

BypassTab:CreateButton({
	Name = "Enable All Bypass",
	Description = "Activate all bypass features at once",
	Callback = function()
		StartFishingRadar()
		StartDivingGear()
		StartAutoSell()
		StartAutoTrickTreat()
		FishingRadarToggle:Set({CurrentValue = true})
		DivingGearToggle:Set({CurrentValue = true})
		AutoSellToggle:Set({CurrentValue = true})
		TrickTreatToggle:Set({CurrentValue = true})
		Notify({
			Title = "Bypass", 
			Content = "All bypass features enabled"
		})
	end
}, "EnableAllBypassButton")

BypassTab:CreateButton({
	Name = "Disable All Bypass",
	Description = "Deactivate all bypass features at once",
	Callback = function()
		StopFishingRadar()
		StopDivingGear()
		StopAutoSell()
		StopAutoTrickTreat()
		FishingRadarToggle:Set({CurrentValue = false})
		DivingGearToggle:Set({CurrentValue = false})
		AutoSellToggle:Set({CurrentValue = false})
		TrickTreatToggle:Set({CurrentValue = false})
		Notify({
			Title = "Bypass", 
			Content = "All bypass features disabled"
		})
	end
}, "DisableAllBypassButton")

-- ========== PLAYER TAB ==========
local PlayerTab = Window:CreateTab({
	Name = "Player",
	Icon = "user",
	ImageSource = "Lucide",
	ShowTitle = true
})

-- Performance Section
local PerformanceSection = PlayerTab:CreateSection("Performance")

local AntiLagToggle = PlayerTab:CreateToggle({
	Name = "Ultra Anti Lag",
	Description = "White texture mode for maximum performance",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			EnableAntiLag()
		else
			DisableAntiLag()
		end
	end
}, "AntiLagToggle")

-- Position Management Section
local PositionSection = PlayerTab:CreateSection("Position Management")

PlayerTab:CreateButton({
	Name = "Save Position",
	Description = "Save current player position",
	Callback = SaveCurrentPosition
}, "SavePositionButton")

PlayerTab:CreateButton({
	Name = "Load Position",
	Description = "Teleport to saved position",
	Callback = LoadSavedPosition
}, "LoadPositionButton")

local LockPositionToggle = PlayerTab:CreateToggle({
	Name = "Lock Position",
	Description = "Prevent player from moving away from saved position",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			StartLockPosition()
		else
			StopLockPosition()
		end
	end
}, "LockPositionToggle")

-- Movement Section
local MovementSection = PlayerTab:CreateSection("Movement")

local WalkSpeedSlider = PlayerTab:CreateSlider({
	Name = "Walk Speed",
	Description = "Adjust player walking speed",
	Range = {16, 200},
	Increment = 1,
	CurrentValue = 16,
	Callback = function(Value)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
			LocalPlayer.Character.Humanoid.WalkSpeed = Value
		end
	end
}, "WalkSpeedSlider")

local JumpPowerSlider = PlayerTab:CreateSlider({
	Name = "Jump Power",
	Description = "Adjust player jump power",
	Range = {50, 350},
	Increment = 1,
	CurrentValue = 50,
	Callback = function(Value)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
			LocalPlayer.Character.Humanoid.JumpPower = Value
		end
	end
}, "JumpPowerSlider")

PlayerTab:CreateButton({
	Name = "Reset Movement",
	Description = "Reset walk speed and jump power to default",
	Callback = function()
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
			LocalPlayer.Character.Humanoid.WalkSpeed = 16
			LocalPlayer.Character.Humanoid.JumpPower = 50
			WalkSpeedSlider:Set({CurrentValue = 16})
			JumpPowerSlider:Set({CurrentValue = 50})
			Notify({
				Title = "Reset", 
				Content = "Movement reset to default"
			})
		end
	end
}, "ResetMovementButton")

-- Teleportation Section
local TeleportationSection = PlayerTab:CreateSection("Teleportation")

local MapDropdown = PlayerTab:CreateDropdown({
	Name = "Select Destination",
	Description = "Choose location to teleport",
	Options = {"Mount Hallow"},
	CurrentOption = {"Mount Hallow"},
	MultipleOptions = false,
	SpecialType = nil,
	Callback = function(Option)
		currentSelectedMap = Option
	end
}, "MapDropdown")

PlayerTab:CreateButton({
	Name = "Teleport Now",
	Description = "Teleport to selected destination",
	Callback = function()
		local pos = Vector3.new(1819, 12, 3043)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
			Notify({
				Title = "Teleport", 
				Content = "Teleported to Mount Hallow"
			})
		end
	end
}, "TeleportButton")

local ShowCoordsToggle = PlayerTab:CreateToggle({
	Name = "Show Coordinates",
	Description = "Display player coordinates on screen",
	CurrentValue = false,
	Callback = function(Value)
		if Value then
			CreateCoordinateDisplay()
		else
			DestroyCoordinateDisplay()
		end
	end
}, "ShowCoordsToggle")

-- ========== SETTINGS TAB ==========
local SettingsTab = Window:CreateTab({
	Name = "Settings",
	Icon = "settings",
	ImageSource = "Lucide",
	ShowTitle = true
})

-- Build Theme Section
SettingsTab:BuildThemeSection()

-- UI Settings Section
local UISettingsSection = SettingsTab:CreateSection("UI Settings")

local MinimizeBind = SettingsTab:CreateBind({
	Name = "Minimize Keybind",
	Description = "Set the keybind for minimizing the UI",
	CurrentBind = "K",
	HoldToInteract = false,
	Callback = function(BindState)
		-- Handle minimize
	end,
	OnChangedCallback = function(Bind)
		Window.Bind = Bind
	end
}, "MinimizeBind")

-- Hub Controls Section
local HubControlsSection = SettingsTab:CreateSection("Hub Controls")

SettingsTab:CreateButton({
	Name = "Unload Hub",
	Description = "Safely unload the entire hub",
	Callback = function()
		StopAutoFish()
		StopLockPosition()
		DisableAntiLag()
		StopFishingRadar()
		StopDivingGear()
		StopAutoSell()
		StopAutoTrickTreat()
		DestroyCoordinateDisplay()
		Luna:Destroy()
		Notify({
			Title = "Unload", 
			Content = "Hub unloaded successfully"
		})
	end
}, "UnloadButton")

SettingsTab:CreateButton({
	Name = "Clean UI",
	Description = "Remove money icons and clean up UI",
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
		Notify({
			Title = "Clean", 
			Content = "UI cleaned"
		})
	end
}, "CleanUIButton")

-- Build Config Section (MUST BE AT BOTTOM)
SettingsTab:BuildConfigSection()

-- Load Configuration
Luna:LoadAutoloadConfig()

-- Initial Notification
Notify({
	Title = "Anggazyy Hub Ready", 
	Content = "System initialized successfully"
})

--//////////////////////////////////////////////////////////////////////////////////
-- System Initialization Complete
--//////////////////////////////////////////////////////////////////////////////////
