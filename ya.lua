local Window = Luna:CreateWindow({
    Name = "Luna Example Window",
    Subtitle = "Test",
    LogoID = "6031097225",
    LoadingEnabled = true,
    LoadingTitle = "Luna Interface Suite",
    LoadingSubtitle = "by Nebula Softworks",
    KeySystem = true,
    KeySettings = {
        Title = "Luna Example Key",
        Subtitle = "Key System",
        Note = "Please Enter Your Key To Use Example Hub",
        FileName = "Key", -- the name of the key file. this will be saved in ur RootFolder. However, if you don't have one, it'll save in ur config folder instead
        SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
        Key = {"Example Key"} -- List of keys that will be accepted by the system, please use a system like Pelican or Luarmor that provide key strings based on your HWID since putting a simple string is very easy to bypass
    }
})

Luna:Notification({ 
    Title = "Welcome to Luna",
    Icon = "sparkle",
    ImageSource = "Material",
    Content = "Welcome to the Luna Interface Suite. This Is an Amazing Quality Freemium UI Library For Roblox Exploiting Made By Nebula Softworks. Luna was Created in hopes of improving the standard of UI Library designs by being the golden standard for it. Luna Has Amazing Features like a key system, notification and perfection in aesthetics and design. So, What Are You Waiting For? Start Using Luna Today at " .. website
})

    local Tabs = {
        Main = Window:CreateTab({
            Name = "Tab Example 1",
            Icon = "view_in_ar",
            ImageSource = "Material",
            ShowTitle = true
        }),
        Main2 = Window:CreateTab({
            Name = "Tab Example 2",
            Icon = "location_searching",
            ImageSource = "Material",
            ShowTitle = false
        }),
        Premium = Window:CreateTab({
            Name = "Premium Tab",
            Icon = "sparkle",
            ImageSource = "Material",
            ShowTitle = true
        }),
        Debug = Window:CreateTab({
            Name = "Debug",
            Icon = "settings"
        })
    }


    Window:CreateHomeTab()
    local bleh =Tabs.Debug:CreateColorPicker()
    Tabs.Debug:CreateButton({
        Callback = function()
            bleh:Set({
                Color = Color3.fromRGB(0,0,0)
            })
        end,
    })

    Tabs.Main:CreateSection("Section Example")
    Tabs.Main:CreateButton({
        Name = "Button Example!",
        Description = "Every Element Except For Sliders Can Have a description like this"
    })
    Tabs.Main:CreateLabel({
        Text = "Label Example",
        Style = 1
    })
    Tabs.Main:CreateLabel({
        Text = "Information Example",
        Style = 2
    })
    Tabs.Main:CreateLabel({
        Text = "Warning Example",
        Style = 3
    })
    Tabs.Main:CreateParagraph({
        Title = "Paragraph Example ",
        Text = "This Is A Paragraph. You Can Type Very Long Strings Here And They'll Automatically Fit! This Counts As A Description Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Right? Also Did I Mention This Has Rich Text? Also Did I Mention This Has Rich Text? Also Did I Mention This Has Rich Text? Also Did I Mention This Has Rich Text? Also Did I Mention This Has Rich Text? Also Did I Mention This Has Rich Text?"
    })
    Tabs.Main:CreateSlider({
        Name = "Slider Example",
        Range = {0, 200},
        Increment = 0.1,
        CurrentValue = 100,
        Flag = "Slider",
    })
    Tabs.Main:CreateToggle({
        Name = "Toggle Example",
        Description = "This Is A Toggle. See I Was Right? Sliders Don't Have Descriptions!",
        CurrentValue = false,
    })

    Tabs.Main:CreateBind({
        Name = "Bind Example",
        Description = "Btw Using CreateKeybind is deprecated, use CreateBind For Future Binds :)",
        CurrentKeybind = "Q",
        HoldToInteract = false,
    })
    Tabs.Main:CreateInput({
        Name = "Dynamic Input Example",
        Description = "Every Element has :Set(). Sadly this one is broken;the text wont update :(",
        PlaceholderText = "Input Placeholder",
        CurrentValue = "",
        Numeric = false,
        MaxCharacters = nil,
        Enter = false
    })
    Tabs.Main:CreateDropdown({
        Name = "Dropdown Example",
        Description = "U can access a element's values using .Settings!",
        Options = {"Option 1","Option 2","Option 3","Option 4","Option 5","Option 6"},
        CurrentOption = "Option 1",
        MultipleOptions = false,
        SpecialType = nil
    })

    Tabs.Main:CreateColorPicker({
        Name = "Color Picker Example",
        Color = Color3.fromRGB(86, 171, 128),
        Flag = "ColorPicker1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Value)
            -- The function that takes place every time the color picker is moved/changed
            -- The variable (Value) is a Color3fromRGB value based on which color is selected
        end
    })

    Tabs.Main2:CreateSection("The Elements Here Are To Show Unique Features")
    Tabs.Main2:CreateToggle({
        Name = "Toggle - Default On",
        Description = "Toggles Can be Onned By Default!",
        CurrentValue = true
    })
    Tabs.Main2:CreateBind({
        Name = "Hold To Interact - Walkspeed Example",
        Description = "Binds Can Be Made to only Callback when held",
        HoldToInteract = true,
        CurrentBind = "E",
        Callback = function(v)
            if v then 
                Players.LocalPlayer.Character.Humanoid.WalkSpeed = 100
            else
                Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end,
    })
    Tabs.Main2:CreateInput({
        Name = "Numeric And 12 Max Characters",
        Description = "You Can Limit The Max Characters or Allow Only Numbers",
        Numeric = true,
        MaxCharacters = 12
    })
    Tabs.Main2:CreateInput({
        Name = "Require Enter",
        Description = "You Can Only make the callback happen after user hits enter",
        Enter = true
    })
    Tabs.Main2:CreateLabel({
        Text = "Every Element Can be Destroyed as well!"
    })
    Tabs.Main2:CreateDropdown({
        Name = "Dropdown - Multi Options",
        Description = "Multiple Special Features can be used on the same element!",
        Options = {"Option 1","Option 2","Option 3","Option 4","Option 5","Option 6"},
        CurrentOption = {"Option 1","Option 3","Option 6"},
        MultipleOptions = true
    })
    Tabs.Main2:CreateDropdown({
        Name = "Dropdown - Players",
        Description = "Luna's Dropdowns Has a built in Player Dropdown!",
        Options = {"u can put anything here, it wont be shown anyway"},
        CurrentOption = {"same here, itll be the first option"},
        MultipleOptions = false,
        SpecialType = "Player"
    })

    local s = Tabs.Premium:CreateSection("You can add elements inside section too")
    s:CreateButton()
    s:CreateLabel()
    s:CreateDivider()
    s:CreateDropdown()

    Tabs.Premium:BuildConfigSection()
    Tabs.Premium:BuildThemeSection()
