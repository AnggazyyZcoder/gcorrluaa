--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL) + Weather Machine + Trick or Treat
-- Luna UI Library
-- Clean, modern, professional design
-- Author: Anggazyy (refactor)
--//////////////////////////////////////////////////////////////////////////////////

-- CONFIG: ubah sesuai kebutuhan
local AUTO_FISH_REMOTE_NAME = "UpdateAutoFishingState"
local NET_PACKAGES_FOLDER = "Packages"
local LUNA_URL = 'https://raw.nebulasoftworks.xyz/luna'

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
local COLOR_SECONDARY = Color3.fromRGB(30, 30, 46)  -- Dark

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

-- Luna Loader
local successLoad, Luna = pcall(function()
    return loadstring(game:HttpGet(LUNA_URL))()
end)
if not successLoad or not Luna then
    warn("Luna loading failed. Please check your executor configuration.")
    return
end

-- Notification System
local function Notify(opts)
    pcall(function()
        Luna:Notification({
            Title = opts.Title or "Notification",
            Icon = "notifications",
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

-- =============================================================================
-- WEATHER MACHINE SYSTEM
-- =============================================================================

local function LoadWeatherData()
    local success, result = pcall(function()
        local EventUtility = require(ReplicatedStorage.Shared.EventUtility)
        local StringLibrary = require(ReplicatedStorage.Shared.StringLibrary)
        local Events = require(ReplicatedStorage.Events)
        
        local weatherList = {}
        
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
        local Net = require(ReplicatedStorage.Packages.Net)
        local PurchaseWeatherEvent = Net:RemoteFunction("PurchaseWeatherEvent")
        local purchaseResult = PurchaseWeatherEvent:InvokeServer(weatherName)
        return purchaseResult
    end)
    
    return success, result
end

local function BuySelectedWeathers()
    if not next(selectedWeathers) then
        Notify({
            Title = "Weather Purchase",
            Content = "No weathers selected!",
        })
        return
    end
    
    local totalPurchases = 0
    local successfulPurchases = 0
    
    Notify({
        Title = "Weather Purchase",
        Content = "Processing purchases...",
    })
    
    for weatherName, selected in pairs(selectedWeathers) do
        if selected then
            totalPurchases = totalPurchases + 1
            
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
                        Content = string.format("Bought: %s", weatherData.Name),
                    })
                else
                    Notify({
                        Title = "❌ Purchase Failed",
                        Content = string.format("Failed to buy: %s", weatherData.Name),
                    })
                end
            end
            
            task.wait(0.5)
        end
    end
    
    selectedWeathers = {}
    
    Notify({
        Title = "Purchase Complete",
        Content = string.format("Successfully purchased %d/%d weathers", successfulPurchases, totalPurchases),
    })
end

local function RefreshWeatherList()
    availableWeathers = LoadWeatherData()
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
            Content = string.format("%s %s", weather.Name, state and "selected" or "deselected"),
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
        Content = "System activated - Knocking all doors...",
    })
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            local doors = FindTrickOrTreatDoors()
            
            if #doors > 0 then
                Notify({
                    Title = "🎃 Trick or Treat",
                    Content = string.format("Found %d doors, knocking...", #doors),
                })
                
                for _, door in ipairs(doors) do
                    if not autoTrickTreatEnabled then break end
                    
                    local success, result = KnockDoor(door)
                    if success then
                        if result == "Trick" then
                            print("[🎃] Trick dari " .. door.Name)
                        elseif result == "Treat" then
                            print("[🍬] Treat dari " .. door.Name)
                        end
                    end
                    
                    task.wait(0.5)
                end
            end
            
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
        Content = "System deactivated",
    })
end

local function ManualKnockAllDoors()
    local doors = FindTrickOrTreatDoors()
    
    if #doors == 0 then
        Notify({
            Title = "🎃 Trick or Treat",
            Content = "No Trick or Treat doors found!",
        })
        return
    end
    
    Notify({
        Title = "🎃 Manual Knock",
        Content = string.format("Knocking %d doors...", #doors),
    })
    
    local successfulKnocks = 0
    
    for _, door in ipairs(doors) do
        local success, result = KnockDoor(door)
        if success then
            successfulKnocks = successfulKnocks + 1
        end
        task.wait(0.5)
    end
    
    Notify({
        Title = "🎃 Knock Complete",
        Content = string.format("Success: %d/%d doors", successfulKnocks, #doors),
    })
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    if statusLabel then 
        pcall(function() 
            statusLabel:Set({Text = "Status: ACTIVE ✅"})
        end) 
    end
    Notify({Title = "Auto Fishing", Content = "System activated successfully"})

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
            statusLabel:Set({Text = "Status: DISABLED ❌"})
        end) 
    end
    Notify({Title = "Auto Fishing", Content = "System deactivated"})
    
    pcall(function()
        SafeInvokeAutoFishing(false)
    end)
end

-- =============================================================================
-- ULTRA ANTI LAG SYSTEM
-- =============================================================================

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
            end
        end
        
        settings().Rendering.QualityLevel = 1
    end)
    
    Notify({Title = "Ultra Anti Lag", Content = "White texture mode enabled - Maximum performance"})
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
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
            workspace.Terrain.WaterReflectance = 0.5
            workspace.Terrain.WaterTransparency = 0.5
        end
        
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        
        settings().Rendering.QualityLevel = 10
    end)
    
    Notify({Title = "Anti Lag", Content = "Graphics settings restored"})
end

-- Position Management System
local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify({
            Title = "Position Saved", 
            Content = "Position saved successfully",
        })
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify({Title = "Load Failed", Content = "No position saved"})
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify({Title = "Position Loaded", Content = "Teleported to saved position"})
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
    
    Notify({Title = "Position Lock", Content = "Player position locked"})
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify({Title = "Position Lock", Content = "Player position unlocked"})
end

-- =============================================================================
-- BYPASS SYSTEM
-- =============================================================================

local function ToggleFishingRadar()
    local success, result = pcall(function()
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
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
        Notify({Title = "Fishing Radar", Content = message})
    else
        Notify({Title = "Radar Error", Content = message})
    end
end

local function StopFishingRadar()
    if not fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = false
        Notify({Title = "Fishing Radar", Content = message})
    else
        Notify({Title = "Radar Error", Content = message})
    end
end

local function ToggleDivingGear()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        
        local DivingGear = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
        if not DivingGear then
            return false, "Diving Gear tidak ditemukan!"
        end

        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
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
        Notify({Title = "Diving Gear", Content = message})
    else
        Notify({Title = "Diving Gear Error", Content = message})
    end
end

local function StopDivingGear()
    if not divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = false
        Notify({Title = "Diving Gear", Content = message})
    else
        Notify({Title = "Diving Gear Error", Content = message})
    end
end

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
        Notify({Title = "Manual Sell", Content = result})
    else
        Notify({Title = "Sell Error", Content = result})
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
                                Content = string.format("Sold %d fish automatically", fishCount),
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
    })
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify({Title = "Auto Sell", Content = "Auto sell stopped"})
end

local function SetAutoSellThreshold(amount)
    if type(amount) == "number" and amount > 0 then
        autoSellThreshold = amount
        Notify({
            Title = "Auto Sell Threshold", 
            Content = string.format("Threshold set to %d fish", amount),
        })
        return true
    end
    return false
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

-- =============================================================================
-- MAIN WINDOW CREATION (LUNA UI)
-- =============================================================================

local Window = Luna:CreateWindow({
    Name = "Anggazyy Hub - Fish It",
    Subtitle = "Premium Automation",
    LogoID = "82795327169782",
    LoadingEnabled = true,
    LoadingTitle = "Anggazyy Hub",
    LoadingSubtitle = "by Anggazyy",
    
    ConfigSettings = {
        RootFolder = nil,
        ConfigFolder = "AnggazyyHub_FishIt"
    },
    
    KeySystem = false,
    KeySettings = {
        Title = "Anggazyy Hub Key",
        Subtitle = "Key System",
        Note = "Enter your key to access Anggazyy Hub",
        SaveKey = true,
        Key = {"AnggazyyHub2024"}
    }
})

-- =============================================================================
-- TABS CREATION
-- =============================================================================

local Tabs = {
    Home = Window:CreateTab({
        Name = "Home",
        Icon = "home",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Auto = Window:CreateTab({
        Name = "Automation",
        Icon = "smart_toy",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Weather = Window:CreateTab({
        Name = "Weather Machine",
        Icon = "cloud",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Bypass = Window:CreateTab({
        Name = "Bypass",
        Icon = "security",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Player = Window:CreateTab({
        Name = "Player Config",
        Icon = "person",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Teleport = Window:CreateTab({
        Name = "Teleportation",
        Icon = "flight_takeoff",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Settings = Window:CreateTab({
        Name = "Settings",
        Icon = "settings",
        ImageSource = "Material",
        ShowTitle = true
    })
}

-- =============================================================================
-- HOME TAB
-- =============================================================================

Tabs.Home:CreateParagraph({
    Title = "🐟 Anggazyy Hub - Fish It",
    Text = "Premium fishing automation system with advanced features including Auto Fishing, Weather Machine, Trick or Treat automation, and more. Built with Luna UI for the best user experience."
})

Tabs.Home:CreateDivider()

Tabs.Home:CreateLabel({
    Text = "System Status",
    Style = 2
})

Tabs.Home:CreateParagraph({
    Title = "📊 Current Features",
    Text = "• Auto Fishing System\n• Weather Machine Purchase\n• Trick or Treat Automation\n• Fishing Radar Bypass\n• Diving Gear Toggle\n• Auto Sell Fish\n• Ultra Anti Lag\n• Position Management\n• Player Speed Control"
})

-- =============================================================================
-- AUTOMATION TAB
-- =============================================================================

Tabs.Auto:CreateSection("Auto Fishing System")

Tabs.Auto:CreateParagraph({
    Title = "Auto Fishing",
    Text = "Automated fishing with server communication. Enable the toggle below to start auto fishing."
})

statusLabel = Tabs.Auto:CreateLabel({
    Text = "Status: DISABLED ❌",
    Style = 1
})

Tabs.Auto:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = "Automatically catch fish without manual input",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
}, "AutoFishToggle")

Tabs.Auto:CreateDivider()

Tabs.Auto:CreateLabel({
    Text = "Auto fishing will run in the background",
    Style = 2
})

-- =============================================================================
-- WEATHER MACHINE TAB
-- =============================================================================

Tabs.Weather:CreateSection("Weather Machine Purchase")

Tabs.Weather:CreateParagraph({
    Title = "Weather System",
    Text = "Purchase and activate different weather events. Select multiple weathers using toggles and buy them all at once."
})

-- Load weather data
availableWeathers = LoadWeatherData()

local weatherOptions = {}
for _, weather in ipairs(availableWeathers) do
    table.insert(weatherOptions, weather.DisplayName)
end

-- Weather Selection Section
Tabs.Weather:CreateSection("Available Weathers")

-- Create toggles for each weather
for index, weather in ipairs(availableWeathers) do
    Tabs.Weather:CreateToggle({
        Name = weather.DisplayName,
        Description = string.format("Price: %d Coins", weather.Price),
        CurrentValue = false,
        Callback = function(state)
            ToggleWeatherSelection(index, state)
        end
    }, "Weather_" .. weather.InternalName)
end

Tabs.Weather:CreateDivider()

-- Purchase Buttons
Tabs.Weather:CreateButton({
    Name = "💰 Buy Selected Weathers",
    Description = "Purchase all selected weather events",
    Callback = BuySelectedWeathers
})

Tabs.Weather:CreateButton({
    Name = "🔄 Refresh Weather List",
    Description = "Reload available weather events",
    Callback = function()
        Notify({
            Title = "Refreshing...",
            Content = "Reloading weather list"
        })
        task.wait(1)
        Notify({
            Title = "Weather List Updated",
            Content = "Please reload the script to see new weathers"
        })
    end
})

Tabs.Weather:CreateDivider()

Tabs.Weather:CreateParagraph({
    Title = "📝 Instructions",
    Text = "1. Select weathers using toggles above\n2. Click 'Buy Selected Weathers' to purchase\n3. Multiple selections are allowed\n4. Weather will activate automatically after purchase"
})

-- =============================================================================
-- BYPASS TAB
-- =============================================================================

-- Fishing Radar Section
Tabs.Bypass:CreateSection("🎯 Fishing Radar")

Tabs.Bypass:CreateToggle({
    Name = "Fishing Radar",
    Description = "Shows fish locations on the map",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartFishingRadar()
        else
            StopFishingRadar()
        end
    end
}, "FishingRadarToggle")

Tabs.Bypass:CreateButton({
    Name = "Toggle Radar Manually",
    Description = "Quick toggle for fishing radar",
    Callback = function()
        local success, message = ToggleFishingRadar()
        if success then
            Notify({Title = "Fishing Radar", Content = message})
        else
            Notify({Title = "Radar Error", Content = message})
        end
    end
})

-- Diving Gear Section
Tabs.Bypass:CreateSection("🤿 Diving Gear")

Tabs.Bypass:CreateToggle({
    Name = "Diving Gear",
    Description = "Automatically equip diving gear for underwater fishing",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartDivingGear()
        else
            StopDivingGear()
        end
    end
}, "DivingGearToggle")

Tabs.Bypass:CreateButton({
    Name = "Toggle Diving Gear Manually",
    Description = "Quick toggle for diving equipment",
    Callback = function()
        local success, message = ToggleDivingGear()
        if success then
            Notify({Title = "Diving Gear", Content = message})
        else
            Notify({Title = "Diving Gear Error", Content = message})
        end
    end
})

-- Auto Sell Section
Tabs.Bypass:CreateSection("💰 Auto Sell Fish")

Tabs.Bypass:CreateToggle({
    Name = "Auto Sell Fish",
    Description = "Automatically sell fish when threshold is reached",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
}, "AutoSellToggle")

Tabs.Bypass:CreateSlider({
    Name = "Sell Threshold",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 3,
    Callback = function(value)
        SetAutoSellThreshold(value)
    end
}, "AutoSellThreshold")

Tabs.Bypass:CreateButton({
    Name = "Sell All Fish Now",
    Description = "Manually sell all fish in inventory",
    Callback = ManualSellAllFish
})

-- Trick or Treat Section
Tabs.Bypass:CreateSection("🎃 Trick or Treat")

Tabs.Bypass:CreateToggle({
    Name = "Auto Trick or Treat",
    Description = "Automatically knock on all Halloween doors",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartAutoTrickTreat()
        else
            StopAutoTrickTreat()
        end
    end
}, "AutoTrickTreatToggle")

Tabs.Bypass:CreateButton({
    Name = "Knock All Doors Now",
    Description = "Manually knock on all Trick or Treat doors",
    Callback = ManualKnockAllDoors
})

Tabs.Bypass:CreateParagraph({
    Title = "🎃 Trick or Treat Info",
    Text = "Automatically knocks on all Trick or Treat doors to collect candy corns. Works during Halloween events.\n\n🎃 = Trick | 🍬 = Treat (Candy Corns)"
})

-- Quick Actions Section
Tabs.Bypass:CreateSection("⚡ Quick Actions")

Tabs.Bypass:CreateButton({
    Name = "Enable All Bypass Features",
    Description = "Activate all bypass features at once",
    Callback = function()
        StartFishingRadar()
        StartDivingGear()
        StartAutoSell()
        StartAutoTrickTreat()
        Notify({Title = "Bypass", Content = "All bypass features enabled"})
    end
})

Tabs.Bypass:CreateButton({
    Name = "Disable All Bypass Features",
    Description = "Deactivate all bypass features at once",
    Callback = function()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        StopAutoTrickTreat()
        Notify({Title = "Bypass", Content = "All bypass features disabled"})
    end
})

-- =============================================================================
-- PLAYER CONFIG TAB
-- =============================================================================

-- Performance Section
Tabs.Player:CreateSection("⚡ Performance")

Tabs.Player:CreateToggle({
    Name = "Ultra Anti Lag",
    Description = "Enable white texture mode for maximum performance",
    CurrentValue = false,
    Callback = function(state)
        if state then
            EnableAntiLag()
        else
            DisableAntiLag()
        end
    end
}, "AntiLagToggle")

Tabs.Player:CreateLabel({
    Text = "Warning: Ultra Anti Lag will make everything white",
    Style = 3
})

-- Position Management Section
Tabs.Player:CreateSection("📍 Position Management")

Tabs.Player:CreateButton({
    Name = "Save Current Position",
    Description = "Save your current location",
    Callback = SaveCurrentPosition
})

Tabs.Player:CreateButton({
    Name = "Load Saved Position",
    Description = "Teleport to saved location",
    Callback = LoadSavedPosition
})

Tabs.Player:CreateToggle({
    Name = "Lock Position",
    Description = "Prevent your character from moving",
    CurrentValue = false,
    Callback = function(state)
        if state then
            StartLockPosition()
        else
            StopLockPosition()
        end
    end
}, "LockPositionToggle")

-- Movement Section
Tabs.Player:CreateSection("🏃 Movement")

Tabs.Player:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = val
        end
    end
}, "WalkSpeed")

Tabs.Player:CreateSlider({
    Name = "Jump Power",
    Range = {50, 350},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = val
        end
    end
}, "JumpPower")

Tabs.Player:CreateButton({
    Name = "Reset Movement to Default",
    Description = "Reset speed and jump to default values",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
            Notify({Title = "Reset", Content = "Movement reset to default"})
        end
    end
})

-- Quick Actions
Tabs.Player:CreateSection("⚡ Quick Actions")

Tabs.Player:CreateButton({
    Name = "Maximum Performance Mode",
    Description = "Enable all performance optimizations",
    Callback = function()
        EnableAntiLag()
        Notify({Title = "Performance", Content = "Maximum performance enabled"})
    end
})

-- =============================================================================
-- TELEPORTATION TAB
-- =============================================================================

Tabs.Teleport:CreateSection("🗺️ Location Teleport")

Tabs.Teleport:CreateParagraph({
    Title = "Quick Travel",
    Text = "Instantly teleport to popular fishing locations. Select a destination from the dropdown and click Teleport."
})

local selectedLocation = "Mount Hallow"

Tabs.Teleport:CreateDropdown({
    Name = "Select Destination",
    Options = {"Mount Hallow", "Spawn"},
    CurrentOption = "Mount Hallow",
    MultipleOptions = false,
    Callback = function(option)
        selectedLocation = option
    end
}, "TeleportLocation")

Tabs.Teleport:CreateButton({
    Name = "🚀 Teleport Now",
    Description = "Teleport to selected location",
    Callback = function()
        local pos = selectedLocation == "Mount Hallow" and Vector3.new(1819, 12, 3043) or Vector3.new(0, 10, 0)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
            Notify({Title = "Teleport", Content = "Teleported to " .. selectedLocation})
        end
    end
})

Tabs.Teleport:CreateDivider()

-- Coordinate Display Section
Tabs.Teleport:CreateSection("📊 Coordinates")

Tabs.Teleport:CreateToggle({
    Name = "Show Coordinates",
    Description = "Display your current position on screen",
    CurrentValue = false,
    Callback = function(v)
        if v then
            CreateCoordinateDisplay()
        else
            DestroyCoordinateDisplay()
        end
    end
}, "ShowCoords")

Tabs.Teleport:CreateLabel({
    Text = "Coordinates will appear at the top of your screen",
    Style = 2
})

-- =============================================================================
-- SETTINGS TAB
-- =============================================================================

Tabs.Settings:CreateSection("⚙️ General Settings")

Tabs.Settings:CreateButton({
    Name = "🗑️ Unload Hub",
    Description = "Safely unload the entire hub and stop all features",
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
        Notify({Title = "Unload", Content = "Hub unloaded successfully"})
    end
})

Tabs.Settings:CreateButton({
    Name = "🧹 Clean UI",
    Description = "Remove money icons and clean the interface",
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
        Notify({Title = "Clean", Content = "UI cleaned successfully"})
    end
})

Tabs.Settings:CreateDivider()

-- Config & Theme Sections
Tabs.Settings:BuildConfigSection()
Tabs.Settings:BuildThemeSection()

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

-- Initial Notification
Notify({
    Title = "🐟 Anggazyy Hub Ready", 
    Content = "System initialized successfully. All features are ready to use!",
})

-- Auto-start notification after 2 seconds
task.wait(2)
Luna:Notification({
    Title = "Welcome!",
    Icon = "waving_hand",
    ImageSource = "Material",
    Content = "Thank you for using Anggazyy Hub. Press K to toggle the menu. Enjoy fishing!"
})

print("=================================")
print("Anggazyy Hub - Fish It Loaded")
print("UI: Luna Library")
print("Version: Final + Weather + ToT")
print("=================================")

-- End of Script
