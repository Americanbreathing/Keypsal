-- ============================================================================
-- PXHB FF2 - New UI Edition
-- Complete feature integration with BlackHoleUI
-- ============================================================================

-- Console cleaning
local old_print = print
local old_warn = warn

getgenv().print = function(...)
    local args = {...}
    local msg = tostring(args[1])
    if string.find(msg, "%[PXHB%]") then
        return old_print(...)
    end
end

getgenv().warn = function(...)
    local args = {...}
    local msg = tostring(args[1])
    if string.find(msg, "%[PXHB%]") then
        return old_warn(...)
    end
end

getgenv().info = function(...) return end

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- [[ PXHB SECURITY SYSTEM ]] --
-- 1. Create a file named 'PXHB_Key.txt' in your workspace folder with your key inside.
-- 2. Paste your Railway Bot URL below (e.g. https://my-bot.up.railway.app)
local AUTH_URL = "https://keypsal-production.up.railway.app" 

task.spawn(function()
    if AUTH_URL == "REPLACE_WITH_YOUR_BOT_URL" then
        LocalPlayer:Kick("PXHB Critical: AUTH_URL not configured in script! Contact Developer.")
        return
    end
    print("PXHB: Authenticating...")

    local key = _G.LicenseKey or "" -- Support loader key
    
    -- If no loader key, try file
    if key == "" then
        pcall(function()
            if isfile and isfile("PXHB_Key.txt") then
                key = readfile("PXHB_Key.txt")
                key = string.gsub(key, "%s+", "") -- trim whitespace
            end
        end)
    end

    if key == "" then
        LocalPlayer:Kick("PXHB Security: 'PXHB_Key.txt' not found or empty.")
        return
    end

    -- Gather Identity
    local hwid = gethwid and gethwid() or game:GetService("RbxAnalyticsService"):GetClientId()
    local rid = tostring(LocalPlayer.UserId)

    local success, response = pcall(function()
        return request({
            Url = AUTH_URL .. "/verify",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                key = key,
                hwid = hwid,
                roblox_id = rid
            })
        })
    end)

    if not success then
        LocalPlayer:Kick("PXHB Security: Connection Failed. Check Bot URL.")
        return
    end

    -- Parse JSON response
    local data
    local jsonSuccess, decoded = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    
    if jsonSuccess then
        data = decoded
    else
        data = { success = false, error = "Server Error: Invalid JSON response" }
    end

    -- Logical Check: Success MUST be true
    if not data.success or response.StatusCode ~= 200 then
        local err = data.error or "Unknown Error"
        if response.StatusCode ~= 200 then
            err = err .. " (" .. tostring(response.StatusCode) .. ")"
        end
        
        if err == "HWID Mismatch" then
            LocalPlayer:Kick("PXHB Security: HWID Mismatch! Key locked to another PC.")
        elseif err == "Account Mismatch" then
            LocalPlayer:Kick("PXHB Security: Account Mismatch! Key locked to another Roblox Account.")
        elseif err == "Key Expired" then
            LocalPlayer:Kick("PXHB Security: Your Key has Expired.")
        else
            LocalPlayer:Kick("PXHB Security: " .. err)
        end
        
        script:Destroy() 
        return
    end
    
    print("PXHB Security: Success. Welcome, " .. LocalPlayer.Name)
    
    -- Load Anti-Detection Bypass (after key success)
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Americanbreathing/Database/refs/heads/main/sa"))()
        print("[PXHB] Anti-detection bypass loaded!")
    end)
    task.wait(1) -- Let bypass initialize
end)
-- [[ END SECURITY ]] --

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 10)
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)

local PracticeMode = game.PlaceId == 8206123457

-- ============================================================================
-- LICENSE SYSTEM
-- ============================================================================
local KeyAuth = {}
local SECRET_KEY = "PXHB_SECRET_KEY_8829"

local function Notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = duration or 5
    })
end

local function mime_val(c)
    if c >= 65 and c <= 90 then return c - 65
    elseif c >= 97 and c <= 122 then return c - 71
    elseif c >= 48 and c <= 57 then return c + 4
    elseif c == 43 then return 62
    else return 63 end
end

local function base64_decode(text)
    local decoded = ""
    local phase = 0
    local accumulator = 0
    
    for i = 1, #text do
        local c = string.byte(text, i)
        if c == 61 then break end
        
        local val = mime_val(c)
        accumulator = (accumulator * 64) + val
        phase = phase + 1
        
        if phase == 4 then
            local b1 = math.floor(accumulator / 65536)
            local b2 = math.floor((accumulator % 65536) / 256)
            local b3 = accumulator % 256
            decoded = decoded .. string.char(b1, b2, b3)
            phase = 0
            accumulator = 0
        end
    end
    
    if phase == 2 then
        decoded = decoded .. string.char(math.floor(accumulator / 16))
    elseif phase == 3 then
        decoded = decoded .. string.char(math.floor(accumulator / 1024), math.floor((accumulator % 1024) / 4))
    end
    
    return decoded
end

local function xor_decrypt(text, key)
    local result = {}
    local key_len = #key
    for i = 1, #text do
        local char = string.byte(text, i)
        local key_char = string.byte(key, (i-1) % key_len + 1)
        table.insert(result, string.char(bit32.bxor(char, key_char)))
    end
    return table.concat(result)
end

function KeyAuth:Login(key)
    local my_hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    
    local s, encrypted_payload = pcall(function() 
        return base64_decode(key) 
    end)
    
    if not s or not encrypted_payload or #encrypted_payload < 5 then
        Notify("Login Failed", "Invalid Key Format")
        return false
    end
    
    local decrypted = xor_decrypt(encrypted_payload, SECRET_KEY)
    local split = string.split(decrypted, "|")
    if #split < 2 then
        Notify("Login Failed", "Key Tampered/Invalid")
        return false
    end
    
    local key_hwid = split[1]
    local expiry_str = split[2]
    local expiry = tonumber(expiry_str)
    
    if key_hwid == "UNBOUND" then
        Notify("Activating Key", "Binding to your device...")
        
        local function encrypt_string(text, key)
            local result = {}
            local key_len = #key
            for i = 1, #text do
                local char = string.byte(text, i)
                local key_char = string.byte(key, (i-1) % key_len + 1)
                table.insert(result, string.char(bit32.bxor(char, key_char)))
            end
            return table.concat(result)
        end
        
        local function base64_encode(data)
            local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
            return ((data:gsub('.', function(x) 
                local r,b='',x:byte()
                for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
                return r;
            end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
                if (#x < 6) then return '' end
                local c=0
                for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
                return b:sub(c+1,c+1)
            end)..({ '', '==', '=' })[#data%3+1])
        end
        
        local bound_payload = my_hwid .. "|" .. expiry_str
        local encrypted = encrypt_string(bound_payload, SECRET_KEY)
        local bound_key = base64_encode(encrypted)
        
        if writefile then
            writefile("PXHB_Key.txt", bound_key)
        end
        
        Notify("Success", "Key Activated! Welcome.")
        return true
    end
    
    if key_hwid ~= my_hwid then
        Notify("Login Failed", "Key Already Bound To Another Device!")
        return false
    end
    
    if expiry < os.time() then
        Notify("Login Failed", "Key Expired!")
        return false
    end
    
    Notify("Success", "Welcome Back! License Valid.")
    return true
end

function KeyAuth:Init() return true end

local function AutoLogin(onSuccess)
    local key = _G.LicenseKey or _G.PXHB_Key
    
    if not key or key == "" then
        if isfile and isfile("PXHB_Key.txt") then
            key = readfile("PXHB_Key.txt")
        end
    end
    
    if not key or key == "" then
        StarterGui:SetCore("SendNotification", {
            Title = "PXHB Error",
            Text = "No license key found! Get your script from Discord.",
            Duration = 10
        })
        return
    end
    
    if KeyAuth:Init() and KeyAuth:Login(key) then
        if writefile then 
            writefile("PXHB_Key.txt", key) 
        end
        onSuccess()
    else
        StarterGui:SetCore("SendNotification", {
            Title = "PXHB Error",
            Text = "Invalid or expired license key!",
            Duration = 5
        })
    end
end

-- ============================================================================
-- CONFIG TABLES
-- ============================================================================
local Config = {
    QB = {
        Enabled = false,
        Mode = "Dot",
        PowerBased = true,
        DesiredPower = 94,
        MaxAirTime = 20,
        YOffset = 1.25,
        XZOffset = 0,
        JumpPassHeight = 8.01
    },
    
    Mags = {
        Enabled = false,
        Preset = "Legit",
        Presets = {
            Blatant = {MagDistance = 50, AutoDive = true, DiveDistance = 100, Delay = 0},
            Legit = {MagDistance = 28, AutoDive = true, DiveDistance = 55, Delay = 0.03},
            League = {MagDistance = 12, AutoDive = false, DiveDistance = 0, Delay = 0.08}
        }
    },
    
    Visuals = {
        BallTrajectory = false,
        BallInfo = false,
        SkeletonESP = false,
        ShowMagRange = false,
        ShowBallHitbox = false,
        CatchAssist = false,
        TrajectoryColor = Color3.fromRGB(0, 255, 150),
        ESPColor = Color3.fromRGB(255, 255, 255)
    },
    
    Settings = {
        LicenseKey = "",
        LicenseExpiry = "N/A",
        LicenseValid = false,
        ConfigName = "default"
    }
}

local RouteConfigs = {
    Dot = {
        ['stationary'] = {YOffset = 0, XZOffset = 0},
        ['streak'] = {YOffset = 8, XZOffset = 0},
        ['post/corner'] = {YOffset = 5, XZOffset = 0.5},
        ['slant'] = {YOffset = 0, XZOffset = 0.5},
        ['in/out'] = {YOffset = 0, XZOffset = 0.5},
        ['curl/comeback'] = {YOffset = 0, XZOffset = 0}
    },
    Dive = {
        ['stationary'] = {YOffset = 0, XZOffset = 0},
        ['streak'] = {YOffset = 9.5, XZOffset = 0.5},
        ['post/corner'] = {YOffset = 8.5, XZOffset = 0.5},
        ['slant'] = {YOffset = 8.5, XZOffset = 0.5},
        ['in/out'] = {YOffset = 0, XZOffset = 0.5},
        ['curl/comeback'] = {YOffset = 0, XZOffset = 0}
    },
    Mag = {
        ['stationary'] = {YOffset = 0, XZOffset = 0},
        ['streak'] = {YOffset = 10, XZOffset = 0.5},
        ['post/corner'] = {YOffset = 10, XZOffset = 0.5},
        ['slant'] = {YOffset = 0, XZOffset = 0.5},
        ['in/out'] = {YOffset = 0, XZOffset = 0.5},
        ['curl/comeback'] = {YOffset = 0, XZOffset = 0}
    }
}

local State = {
    LockedTarget = nil,
    LockedTargetPos = nil,
    CurrentAirtime = 2,
    MenuOpen = false,
    LastThrowTime = 0,
    LastMagTime = 0
}

local Gravity = 28
local BallSpawnOffset = Vector3.new(0, 3, 0)
local ThrowDelay = 0.15

-- ============================================================================
-- CONFIGURATION MANAGER
-- ============================================================================
local ConfigFolder = "PXHV_Configs"
if not isfolder(ConfigFolder) then
    makefolder(ConfigFolder)
end

local function GetConfigList()
    local files = listfiles(ConfigFolder)
    local names = {}
    for _, file in pairs(files) do
        -- Extract filename, handling both / and \ separators
        local name = file:match("([^\\/]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    return names
end

local function SaveConfig(name)
    if not name or name == "" then 
        Notify("Config", "Please enter a config name!", 3)
        return 
    end
    
    -- Create a clean table to save (excluding license info)
    local saveTable = {
        QB = Config.QB,
        Mags = Config.Mags,
        Visuals = Config.Visuals,
        ConfigVersion = "1.0"
    }
    
    local success, encoded = pcall(game.HttpService.JSONEncode, game.HttpService, saveTable)
    if success then
        writefile(ConfigFolder .. "/" .. name .. ".json", encoded)
        Notify("Config", "Saved: " .. name, 3)
    else
        Notify("Config", "Failed to encode config", 3)
    end
end

local function LoadConfig(name)
    if not name or name == "" then return end
    local path = ConfigFolder .. "/" .. name .. ".json"
    
    if not isfile(path) then
        Notify("Config", "File not found!", 3)
        return
    end
    
    local data = readfile(path)
    local success, decoded = pcall(game.HttpService.JSONDecode, game.HttpService, data)
    
    if success then
        -- Safely merge settings
        if decoded.QB then
            for k, v in pairs(decoded.QB) do Config.QB[k] = v end
        end
        if decoded.Mags then
            for k, v in pairs(decoded.Mags) do Config.Mags[k] = v end
        end
        if decoded.Visuals then
            for k, v in pairs(decoded.Visuals) do Config.Visuals[k] = v end
        end
        
        Notify("Config", "Loaded: " .. name, 3)
        Notify("Config", "Settings applied (UI may not reflect changes)", 4)
    else
        Notify("Config", "Failed to decode config", 3)
    end
end

-- ============================================================================
-- UI LIBRARY (BlackHoleUI)
-- ============================================================================
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/BloxCrypto/BlackHoleUI/refs/heads/main/BlackHole.lua"
))()

local Window = Library:Window({
    Logo = "79834209547728",
    FadeSpeed = 0.15,
    PagePadding = 19
})

local Pages = {
    ["Catching"] = Window:Page({ Icon = "6031097225", Search = true }),
    ["Throwing"] = Window:Page({ Icon = "6031091006", Search = true }),
    ["Visuals"]  = Window:Page({ Icon = "6031763426", Search = true }),
    ["Settings"] = Window:Page({ Icon = "6031280882", Search = false })
}

-- Catching Tab
do
    local CatchingSub = Pages["Catching"]:SubPage({ Name = "Catching" })
    local CatchingSection = CatchingSub:Section({ Name = "| PX-HB | Catching", Side = "Left" })

    CatchingSection:Toggle({
        Name = "Mags",
        Flag = "Mags",
        Default = false,
        Callback = function(v) Config.Mags.Enabled = v end
    })

    CatchingSection:Dropdown({
        Name = "Preset Mode",
        Flag = "PresetMode",
        Items = { "Blatant", "Legit", "League" },
        Callback = function(preset)
            Config.Mags.Preset = preset
        end
    })

    CatchingSection:Slider({
        Name = "Mag Distance Override",
        Flag = "MagDistance",
        Min = 5, Max = 60, Default = 28,
        Callback = function(value)
            local currentPreset = Config.Mags.Preset
            if Config.Mags.Presets[currentPreset] then
                Config.Mags.Presets[currentPreset].MagDistance = value
            end
        end
    })

    CatchingSection:Toggle({
        Name = "Auto Dive Override",
        Flag = "AutoDive",
        Callback = function(state)
            local currentPreset = Config.Mags.Preset
            if Config.Mags.Presets[currentPreset] then
                Config.Mags.Presets[currentPreset].AutoDive = state
            end
        end
    })

    CatchingSection:Slider({
        Name = "Dive Distance Override",
        Flag = "DiveDistance",
        Min = 10, Max = 100, Default = 55,
        Callback = function(value)
            local currentPreset = Config.Mags.Preset
            if Config.Mags.Presets[currentPreset] then
                Config.Mags.Presets[currentPreset].DiveDistance = value
            end
        end
    })

    CatchingSection:Slider({
        Name = "Catch Delay (ms)",
        Flag = "CatchDelay",
        Min = 0, Max = 200, Default = 30,
        Callback = function(value)
            local currentPreset = Config.Mags.Preset
            if Config.Mags.Presets[currentPreset] then
                Config.Mags.Presets[currentPreset].Delay = value / 1000
            end
        end
    })
end

-- Throwing Tab
do
    local ThrowingSub = Pages["Throwing"]:SubPage({ Name = "Throwing" })
    local ThrowingSection = ThrowingSub:Section({ Name = "| PX-HB | Throwing", Side = "Left" })

    ThrowingSection:Toggle({
        Name = "QB Aimbot",
        Flag = "QB_Aimbot",
        Default = false,
        Callback = function(v) Config.QB.Enabled = v end
    })

    ThrowingSection:Dropdown({
        Name = "Catch Mode",
        Flag = "CatchMode",
        Items = { "Dot", "Dive", "Mag" },
        Callback = function(mode) Config.QB.Mode = mode end
    })

    ThrowingSection:Toggle({
        Name = "Power Based Aiming",
        Flag = "PowerAim",
        Default = true,
        Callback = function(state) Config.QB.PowerBased = state end
    })

    ThrowingSection:Slider({
        Name = "Desired Power",
        Flag = "DesiredPower",
        Min = 50, Max = 95, Default = 94,
        Callback = function(value) Config.QB.DesiredPower = value end
    })

    ThrowingSection:Slider({
        Name = "Max Airtime",
        Flag = "MaxAirtime",
        Min = 5, Max = 30, Default = 20,
        Callback = function(value) Config.QB.MaxAirTime = value end
    })

    ThrowingSection:Slider({
        Name = "Base Airtime",
        Flag = "BaseAirtime",
        Min = 1, Max = 10, Default = 2,
        Callback = function(value) State.CurrentAirtime = value end
    })
end

-- Visuals Tab
do
    local VisualsSub = Pages["Visuals"]:SubPage({ Name = "Visuals" })
    local ESPSection = VisualsSub:Section({ Name = "| PX-HB | Visuals", Side = "Left" })

    ESPSection:Toggle({
        Name = "Ball Trajectory ESP",
        Flag = "BallESP",
        Callback = function(state) Config.Visuals.BallTrajectory = state end
    })

    ESPSection:Toggle({
        Name = "Player Skeleton ESP",
        Flag = "SkeletonESP",
        Callback = function(state) Config.Visuals.SkeletonESP = state end
    })

    ESPSection:Toggle({
        Name = "Show Mag Range",
        Flag = "MagRange",
        Callback = function(state) Config.Visuals.ShowMagRange = state end
    })

    ESPSection:Toggle({
        Name = "Show Ball Hitbox",
        Flag = "BallHitbox",
        Callback = function(state) Config.Visuals.ShowBallHitbox = state end
    })

    ESPSection:Toggle({
        Name = "Catch Assist (Highlight Best WR)",
        Flag = "CatchAssist",
        Callback = function(state) Config.Visuals.CatchAssist = state end
    })

    ESPSection:Label("Trajectory Color", "Left"):Colorpicker({
        Name = "Trajectory Color",
        Flag = "TrajectoryColor",
        Default = Color3.fromRGB(0, 255, 120),
        Callback = function(color) Config.Visuals.TrajectoryColor = color end
    })

    ESPSection:Label("ESP Color", "Left"):Colorpicker({
        Name = "ESP Color",
        Flag = "ESPColor",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(color) Config.Visuals.ESPColor = color end
    })
end

-- Settings Tab
do
    local SettingsSub = Pages["Settings"]:SubPage({ Name = "Settings" })
    local SettingsSection = SettingsSub:Section({ Name = "Settings", Side = "Left" })

    -- Config Management UI
    local ConfigNameInput = ""
    local SelectedConfig = ""

    SettingsSection:Label("Configuration Manager")

    SettingsSection:Textbox({
        Name = "Config Name",
        Flag = "ConfigNameInput",
        Placeholder = "Enter name...",
        Callback = function(text)
            ConfigNameInput = text
        end
    })

    SettingsSection:Button({
        Name = "Save Config",
        Callback = function()
            SaveConfig(ConfigNameInput)
        end
    })

    local ConfigDropdown -- Forward declaration
    
    local function RefreshConfigDropdown()
        local list = GetConfigList()
        if ConfigDropdown then
            ConfigDropdown:Refresh(list) -- Assuming library supports :Refresh
        end
    end

    SettingsSection:Label("Load Configuration")

    ConfigDropdown = SettingsSection:Dropdown({
        Name = "Available Configs",
        Flag = "ConfigList",
        Items = GetConfigList(),
        Callback = function(item)
            SelectedConfig = item
        end
    })

    SettingsSection:Button({
        Name = "Load Selected Config",
        Callback = function()
            LoadConfig(SelectedConfig)
        end
    })

    SettingsSection:Button({
        Name = "Refresh List",
        Callback = function()
            RefreshConfigDropdown()
            Notify("Config", "List Refreshed", 2)
        end
    })
    
    SettingsSection:Label("----------------")

    SettingsSection:Dropdown({
        Name = "Built-in Presets",
        Flag = "ConfigPreset",
        Items = { "Default", "Aggressive", "Passive" },
        Callback = function(preset)
            Config.Settings.ConfigName = preset
            if preset == "Aggressive" then
                Config.Mags.Preset = "Blatant"
                Config.QB.DesiredPower = 95
            elseif preset == "Passive" then
                Config.Mags.Preset = "League"
                Config.QB.DesiredPower = 85
            elseif preset == "Default" then
                Config.Mags.Preset = "Legit"
                Config.QB.DesiredPower = 94
            end
            Notify("Preset", "Applied " .. preset, 2)
        end
    })

    SettingsSection:Button({
        Name = "Save Config",
        Callback = function()
            pcall(function()
                if writefile then
                    local configData = HttpService:JSONEncode({
                        QB = Config.QB,
                        Mags = { Enabled = Config.Mags.Enabled, Preset = Config.Mags.Preset },
                        Visuals = Config.Visuals
                    })
                    writefile("PXHB_FF2_Config.json", configData)
                    Notify("Config", "Saved successfully!", 3)
                end
            end)
        end
    })

    SettingsSection:Button({
        Name = "Load Config",
        Callback = function()
            pcall(function()
                if readfile and isfile and isfile("PXHB_FF2_Config.json") then
                    local configData = readfile("PXHB_FF2_Config.json")
                    local loaded = HttpService:JSONDecode(configData)
                    
                    if loaded.QB then
                        for k, v in pairs(loaded.QB) do
                            Config.QB[k] = v
                        end
                    end
                    if loaded.Mags then
                        Config.Mags.Enabled = loaded.Mags.Enabled
                        Config.Mags.Preset = loaded.Mags.Preset
                    end
                    if loaded.Visuals then
                        for k, v in pairs(loaded.Visuals) do
                            if type(v) ~= "userdata" then
                                Config.Visuals[k] = v
                            end
                        end
                    end
                    Notify("Config", "Loaded successfully!", 3)
                end
            end)
        end
    })

    SettingsSection:Button({
        Name = "Unload UI",
        Callback = function()
            if Library.Unload then Library:Unload() end
        end
    })
end

-- ============================================================================
-- PHYSICS FUNCTIONS
-- ============================================================================
local function calcVel(startPos, targetPos, grav, T)
    local displacement = targetPos - startPos
    local xzDisplacement = Vector2.new(displacement.X, displacement.Z).Magnitude
    local yDisplacement = displacement.Y
    
    if T <= 0 then T = 0.1 end
    
    local horizontalVelocity = xzDisplacement / T
    local verticalVelocity = (yDisplacement + (0.5 * grav * T * T)) / T
    
    local diff3_XZ = displacement * Vector3.new(1, 0, 1)
    local dir3_XZ
    
    if diff3_XZ.Magnitude > 0.1 then
        dir3_XZ = diff3_XZ.Unit
    else
        dir3_XZ = (HumanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
    end
    
    return dir3_XZ * horizontalVelocity + Vector3.new(0, verticalVelocity, 0)
end

local function angleToHitCoords(distXZ, targetHeightRel, projSpeed, grav)
    local discriminant = projSpeed^4 - grav * (grav * distXZ^2 + 2 * targetHeightRel * projSpeed^2)
    if discriminant < 0 then return nil, nil end
    
    local sqrtTerm = math.sqrt(discriminant)
    return math.atan((projSpeed^2 - sqrtTerm) / (grav * distXZ)),
           math.atan((projSpeed^2 + sqrtTerm) / (grav * distXZ))
end

local function getAirTimeForPower(power, distXZ, heightDiff, grav)
    if distXZ < 1 then distXZ = 1 end
    local normalAngle, _ = angleToHitCoords(distXZ, heightDiff, power, grav)
    if not normalAngle then return nil end
    
    local angleDeg = math.deg(normalAngle)
    local v0y = power * math.sin(math.rad(angleDeg))
    local tMax = v0y / grav
    
    return heightDiff >= 0 and (tMax + v0y/grav) or (2 * tMax)
end

local invalidPower_retryDir = 1

local function throw(targetPos, _Time)
    if (tick() - State.LastThrowTime) < 0.5 then return end
    
    local fbTool = Character:FindFirstChild("Football")
    if not fbTool then return end
    local fb = fbTool:FindFirstChild("Handle")
    if not fb then return end
    local fbRemote = fb:FindFirstChildOfClass("RemoteEvent")
    if not fbRemote then return end
    
    local head = Character:FindFirstChild("Head")
    if not head then return end
    
    local originPos = head.Position + BallSpawnOffset
    local T = _Time or 0.5
    
    for attempt = 1, 20 do
        local vel3 = calcVel(originPos, targetPos, Gravity, T)
        local pow = vel3.Magnitude
        
        if pow <= 95 then
            local powerRoundedClamped = math.clamp(math.round(pow), 1, 95)
            
            fbRemote:FireServer("Clicked", originPos, targetPos, powerRoundedClamped, powerRoundedClamped)
            
            State.CurrentAirtime = T
            State.LastThrowTime = tick()
            return
        end
        
        if T > Config.QB.MaxAirTime or T <= 0.1 then
            invalidPower_retryDir = -invalidPower_retryDir
        end
        T = T + (0.05 * invalidPower_retryDir)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getPing()
    local s, p = pcall(function() return Stats.PerformanceStats.Ping:GetValue() end)
    return s and p or 50
end

local function getServerPing()
    local s, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return s and p or 50
end

local function clampToBounds(pos)
    if PracticeMode then return pos end
    return Vector3.new(math.clamp(pos.X, -95, 95), pos.Y, math.clamp(pos.Z, -195, 195))
end

local function detectRoute(player)
    local char = player.Character
    if not char then return "stationary" end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return "stationary" end
    
    local md = hum.MoveDirection
    if md.Magnitude < 0.1 then return "stationary" end
    
    local toTarget = (hrp.Position - HumanoidRootPart.Position) * Vector3.new(1, 0, 1)
    if toTarget.Magnitude < 0.1 then return "stationary" end
    
    local dot = md:Dot(toTarget.Unit)
    
    if dot >= 0.8 then return "streak"
    elseif dot >= 0.45 then return "post/corner"
    elseif dot >= 0.2 then return "slant"
    elseif dot >= -0.2 then return "in/out"
    else return "curl/comeback" end
end

local function applyRouteOffsets(route)
    local config = RouteConfigs[Config.QB.Mode]
    if config and config[route] then
        Config.QB.YOffset = config[route].YOffset
        Config.QB.XZOffset = config[route].XZOffset
    end
end

local function predictPosition(player, airtime)
    local char = player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return nil end
    
    local speed = hrp.Velocity.Magnitude
    local moveDir = hum.MoveDirection
    local currentPos = hrp.Position
    
    local isJumpPass = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
    local jumpHeight = isJumpPass and Config.QB.JumpPassHeight or 0
    
    local yOffset = Config.QB.YOffset + jumpHeight
    local offset = moveDir * Config.QB.XZOffset + Vector3.new(0, yOffset, 0)
    
    return clampToBounds(currentPos + moveDir * speed * airtime + offset)
end

local function getNearestTeammateToMouse()
    local nearest = nil
    local shortestDist = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team == LocalPlayer.Team then
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                
                if hum and hrp and hum.Health > 0 then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local mousePos = UserInputService:GetMouseLocation()
                        local dist = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                        
                        if dist < shortestDist then
                            nearest = player
                            shortestDist = dist
                        end
                    end
                end
            end
        end
    end
    
    return nearest
end

-- ============================================================================
-- MAGS SYSTEM
-- ============================================================================
local function waitForTouchTransmitter(object, timeout)
    local elapsed = 0
    timeout = timeout or 3
    
    while elapsed < timeout do
        local transmitter = object:FindFirstChildOfClass("TouchTransmitter")
        if transmitter then return transmitter end
        elapsed = elapsed + task.wait()
    end
    return nil
end

local function getCatchParts(char)
    local parts = {}
    
    local specific = {"CatchRight", "CatchLeft", "Catch"}
    for _, name in pairs(specific) do
        local p = char:FindFirstChild(name)
        if p then table.insert(parts, p) end
    end
    
    local limbs = {"RightHand", "LeftHand", "Right Arm", "Left Arm"}
    for _, name in pairs(limbs) do
        local p = char:FindFirstChild(name)
        if p then table.insert(parts, p) end
    end
    
    local head = char:FindFirstChild("Head")
    if head then table.insert(parts, head) end
    
    return parts
end

local function findBestCatchPart(football, catchParts)
    local nearestDist = math.huge
    local nearestPart = nil
    
    for _, part in pairs(catchParts) do
        local dist = (part.Position - football.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestPart = part
        end
    end
    
    return nearestDist, nearestPart
end

Workspace.ChildAdded:Connect(function(object)
    if object.Name ~= "Football" then return end
    if not waitForTouchTransmitter(object, 3) then return end
    
    local character = LocalPlayer.Character
    
    while object and object.Parent == Workspace and character do
        if Config.Mags.Enabled == true then
            local presetName = Config.Mags.Preset
            local preset = Config.Mags.Presets[presetName]
            
            if preset then
                local validParts = getCatchParts(character)
                local distance, catchPart = findBestCatchPart(object, validParts)
                
                if catchPart then
                    if distance <= preset.MagDistance then
                        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            local jitter = 0.25 + (math.random() * 0.15)
                            if (tick() - State.LastMagTime) > jitter then
                                if preset.Delay and preset.Delay > 0 then
                                    task.wait(preset.Delay)
                                end
                                
                                if firetouchinterest then
                                    firetouchinterest(catchPart, object, 1)
                                    firetouchinterest(catchPart, object, 0)
                                end
                                
                                State.LastMagTime = tick()
                            end
                        end
                    end
                end
            end
        end
        
        RunService.Stepped:Wait()
    end
end)

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================
local function isTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

GuiService.MenuOpened:Connect(function() State.MenuOpen = true end)
GuiService.MenuClosed:Connect(function() State.MenuOpen = false end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E and Config.QB.Enabled then
        local hasFootball = Character and Character:FindFirstChild("Football")
        if hasFootball and State.LockedTarget and State.LockedTargetPos then
            local throwPos = State.LockedTargetPos
            local throwTime = State.CurrentAirtime
            
            local head = Character:FindFirstChild("Head")
            if head and Config.QB.PowerBased then
                local origin = head.Position + BallSpawnOffset
                local distXZ = ((origin - throwPos) * Vector3.new(1, 0, 1)).Magnitude
                local heightDiff = throwPos.Y - origin.Y
                
                local calcTime = getAirTimeForPower(Config.QB.DesiredPower, distXZ, heightDiff, Gravity)
                if calcTime and calcTime == calcTime and calcTime > 0 then
                    throwTime = calcTime
                end
            end
            
            throw(throwPos, throwTime)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid", 10)
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
end)

-- ============================================================================
-- VISUALS RENDERING
-- ============================================================================
local Drawings = {
    BallInfo = nil,
    CatchAssist = nil,
    MagRange = nil,
    BallHitbox = nil,
    TrajectoryPool = nil,
    SkeletonPool = nil
}

local SkeletonBonesR15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local SkeletonBonesR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function getFootballPart()
    local football = Workspace:FindFirstChild("Football")
    
    if not football then
        for _, child in pairs(Workspace:GetChildren()) do
            if child.Name == "Football" then
                football = child
                break
            end
        end
    end
    
    if not football then return nil end
    
    if football:IsA("BasePart") then
        return football
    elseif football:IsA("Model") then
        local primary = football.PrimaryPart or football:FindFirstChildWhichIsA("BasePart")
        return primary
    end
    
    return football:FindFirstChildWhichIsA("BasePart")
end

local function getSkeletonBones(char)
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.RigType == Enum.HumanoidRigType.R15 then
        return SkeletonBonesR15
    else
        return SkeletonBonesR6
    end
end

local function createBallInfoDisplay()
    if Drawings.BallInfo then return end
    if Drawing then
        Drawings.BallInfo = Drawing.new("Text")
        Drawings.BallInfo.Size = 18
        Drawings.BallInfo.Font = 2
        Drawings.BallInfo.Outline = true
        Drawings.BallInfo.Center = true
        Drawings.BallInfo.Visible = false
        Drawings.BallInfo.Color = Color3.fromRGB(0, 255, 150)
    end
end

local function createCatchAssist()
    if Drawings.CatchAssist then return end
    if Drawing then
        Drawings.CatchAssist = Drawing.new("Circle")
        Drawings.CatchAssist.Radius = 30
        Drawings.CatchAssist.Thickness = 3
        Drawings.CatchAssist.Filled = false
        Drawings.CatchAssist.Color = Color3.fromRGB(255, 200, 0)
        Drawings.CatchAssist.Visible = false
    end
end

local function createMagRange()
    if Drawings.MagRange then return end
    if Drawing then
        Drawings.MagRange = Drawing.new("Circle")
        Drawings.MagRange.Thickness = 2
        Drawings.MagRange.Filled = false
        Drawings.MagRange.Color = Color3.fromRGB(0, 150, 255)
        Drawings.MagRange.Visible = false
    end
end

createBallInfoDisplay()
createCatchAssist()
createMagRange()

-- Main render loop
RunService.RenderStepped:Connect(function()
    -- Update target lock
    if Config.QB.Enabled then
        local target = getNearestTeammateToMouse()
        if target then
            State.LockedTarget = target
            local route = detectRoute(target)
            applyRouteOffsets(route)
            State.LockedTargetPos = predictPosition(target, State.CurrentAirtime)
        else
            State.LockedTarget = nil
            State.LockedTargetPos = nil
        end
    end

    -- Ball Trajectory ESP
    if Config.Visuals.BallTrajectory == true then
        if not Drawings.TrajectoryPool then
            Drawings.TrajectoryPool = {}
            if Drawing then
                for i = 1, 15 do
                    local line = Drawing.new("Line")
                    line.Thickness = 2
                    line.Visible = false
                    table.insert(Drawings.TrajectoryPool, line)
                end
            end
        end
        
        local football = getFootballPart()
        if football and Drawings.TrajectoryPool then
            local ballPos = football.Position
            local ballVel = football.Velocity or Vector3.new(0,0,0)
            local screenPos, onScreen = Camera:WorldToViewportPoint(ballPos)
            
            if onScreen and ballVel.Magnitude > 1 then
                for i, line in ipairs(Drawings.TrajectoryPool) do
                    local t = i * 0.1
                    local futurePos = ballPos + ballVel * t + Vector3.new(0, -0.5 * Gravity * t * t, 0)
                    local futureScreen, futureOnScreen = Camera:WorldToViewportPoint(futurePos)
                    
                    if futureOnScreen then
                        line.From = Vector2.new(screenPos.X, screenPos.Y)
                        line.To = Vector2.new(futureScreen.X, futureScreen.Y)
                        line.Color = Config.Visuals.TrajectoryColor
                        line.Visible = true
                        screenPos = futureScreen
                    else
                        line.Visible = false
                    end
                end
            else
                for _, line in ipairs(Drawings.TrajectoryPool) do
                    line.Visible = false
                end
            end
        else
            if Drawings.TrajectoryPool then
                for _, line in ipairs(Drawings.TrajectoryPool) do
                    line.Visible = false
                end
            end
        end
    else
        if Drawings.TrajectoryPool then
            for _, line in ipairs(Drawings.TrajectoryPool) do
                line.Visible = false
            end
        end
    end
    
    -- Skeleton ESP
    if Config.Visuals.SkeletonESP == true then
        if not Drawings.SkeletonPool then
            Drawings.SkeletonPool = {}
            if Drawing then
                for i = 1, 100 do
                    local line = Drawing.new("Line")
                    line.Thickness = 1.5
                    line.Visible = false
                    table.insert(Drawings.SkeletonPool, line)
                end
            end
        end
        
        local lineIndex = 1
        if Drawings.SkeletonPool then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team == LocalPlayer.Team then
                    local char = player.Character
                    if char then
                        local bones = getSkeletonBones(char)
                        
                        for _, bone in pairs(bones) do
                            local part1 = char:FindFirstChild(bone[1])
                            local part2 = char:FindFirstChild(bone[2])
                            
                            if part1 and part2 and lineIndex <= #Drawings.SkeletonPool then
                                local screen1, on1 = Camera:WorldToViewportPoint(part1.Position)
                                local screen2, on2 = Camera:WorldToViewportPoint(part2.Position)
                                
                                local line = Drawings.SkeletonPool[lineIndex]
                                if on1 and on2 then
                                    line.From = Vector2.new(screen1.X, screen1.Y)
                                    line.To = Vector2.new(screen2.X, screen2.Y)
                                    line.Color = Config.Visuals.ESPColor
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                                lineIndex = lineIndex + 1
                            end
                        end
                    end
                end
            end
            
            for i = lineIndex, #Drawings.SkeletonPool do
                Drawings.SkeletonPool[i].Visible = false
            end
        end
    else
        if Drawings.SkeletonPool then
            for _, line in ipairs(Drawings.SkeletonPool) do
                line.Visible = false
            end
        end
    end
    
    -- Mag Range
    if Config.Visuals.ShowMagRange == true then
        if not Drawings.MagRange then createMagRange() end
        
        if Drawings.MagRange and Character and HumanoidRootPart then
            local currentPreset = Config.Mags.Presets[Config.Mags.Preset]
            if currentPreset then
                local magDist = currentPreset.MagDistance
                local rootPos = HumanoidRootPart.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos - Vector3.new(0, 3, 0))
                
                if onScreen then
                    local camPos = Camera.CFrame.Position
                    local dist = (rootPos - camPos).Magnitude
                    local fov = Camera.FieldOfView
                    local viewportSize = Camera.ViewportSize
                    
                    local radiusRaw = (magDist / math.tan(math.rad(fov) / 2)) * (viewportSize.Y / 2) / dist
                    
                    Drawings.MagRange.Radius = radiusRaw
                    Drawings.MagRange.Position = Vector2.new(screenPos.X, screenPos.Y)
                    Drawings.MagRange.Visible = true
                else
                    Drawings.MagRange.Visible = false
                end
            end
        elseif Drawings.MagRange then
            Drawings.MagRange.Visible = false
        end
    elseif Drawings.MagRange then
        Drawings.MagRange.Visible = false
    end
    
    -- Ball Hitbox
    if Config.Visuals.ShowBallHitbox == true then
        local football = getFootballPart()
        
        if football then
            if not Drawings.BallHitbox and Drawing then
                Drawings.BallHitbox = Drawing.new("Circle")
                Drawings.BallHitbox.Color = Color3.fromRGB(0, 255, 100)
                Drawings.BallHitbox.Thickness = 2
                Drawings.BallHitbox.Filled = false
                Drawings.BallHitbox.NumSides = 32
                Drawings.BallHitbox.Visible = false
            end
            
            if Drawings.BallHitbox then
                local ballPos = football.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(ballPos)
                
                if onScreen then
                    local hitboxRadius = 2.5
                    local camPos = Camera.CFrame.Position
                    local dist = (ballPos - camPos).Magnitude
                    local fov = Camera.FieldOfView
                    local viewportSize = Camera.ViewportSize
                    
                    local radiusRaw = (hitboxRadius / math.tan(math.rad(fov) / 2)) * (viewportSize.Y / 2) / dist
                    
                    Drawings.BallHitbox.Radius = math.max(radiusRaw, 5)
                    Drawings.BallHitbox.Position = Vector2.new(screenPos.X, screenPos.Y)
                    Drawings.BallHitbox.Visible = true
                else
                    Drawings.BallHitbox.Visible = false
                end
            end
        elseif Drawings.BallHitbox then
            Drawings.BallHitbox.Visible = false
        end
    elseif Drawings.BallHitbox then
        Drawings.BallHitbox.Visible = false
    end
    
    -- Catch Assist
    if Config.Visuals.CatchAssist == true and State.LockedTarget then
        if not Drawings.CatchAssist then createCatchAssist() end
        
        if Drawings.CatchAssist then
            local targetChar = State.LockedTarget.Character
            if targetChar then
                local hrp = targetChar:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        Drawings.CatchAssist.Position = Vector2.new(screenPos.X, screenPos.Y)
                        Drawings.CatchAssist.Color = Color3.fromRGB(255, 200, 0)
                        Drawings.CatchAssist.Visible = true
                    else
                        Drawings.CatchAssist.Visible = false
                    end
                else
                    Drawings.CatchAssist.Visible = false
                end
            else
                Drawings.CatchAssist.Visible = false
            end
        end
    elseif Drawings.CatchAssist then
        Drawings.CatchAssist.Visible = false
    end
end)

Library:Notification("PX-HB", "All features loaded! Press E to throw.", 4)
