--[[
    ██████╗ ██╗  ██╗██╗  ██╗██████╗     ███████╗███████╗██████╗ 
    ██╔══██╗╚██╗██╔╝██║  ██║██╔══██╗    ██╔════╝██╔════╝╚════██╗
    ██████╔╝ ╚███╔╝ ███████║██████╔╝    █████╗  █████╗   █████╔╝
    ██╔═══╝  ██╔██╗ ██╔══██║██╔══██╗    ██╔══╝  ██╔══╝  ██╔═══╝ 
    ██║     ██╔╝ ██╗██║  ██║██████╔╝    ██║     ██║     ███████╗
    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝     ╚═╝     ╚═╝     ╚══════╝
    
    PXHB Football Fusion 2 - Full Script
    QB Aimbot + Auto Catch with Coastified UI
    + Anti-Cheat Bypass Module
    PXHB FF2 - Premium Script
    Protected with KeyAuth
]]

-- ============================================
-- CONSOLE CLEANER (Anti-Spam)
-- ============================================
local old_print = print
local old_warn = warn
local old_error = error
local old_info = rconsoleprint or print

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
-- getgenv().error = function(...) return end -- Optional: Uncomment to hide errors




-- ============================================
-- ANTI-CHEAT BYPASS MODULE
-- ============================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/ZenTheScripter/ZenAntiCheatBypass/main/ZenAntiCheatBypasser.lua"))()

-- CRITICAL: Wait for AC bypasser to fully initialize before continuing
task.wait(3)
print("[PXHB] AC Bypass initialized, loading main script...")


local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Request = http_request or request or HttpPost or syn.request

local function Notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = duration or 5
    })
end

-- ============================================
-- OFFLINE HWID LICENSE SYSTEM (PXHB Custom)
-- ============================================
local KeyAuth = {}  -- Reusing name for compatibility
local SECRET_KEY = "PXHB_SECRET_KEY_8829" -- Must match Generator

-- Simple Base64 Decoder (Pure Lua)
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
        if c == 61 then break end -- Padding '='
        
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
    
    -- 1. Base64 Decode
    local s, encrypted_payload = pcall(function() 
        return base64_decode(key) 
    end)
    
    if not s or not encrypted_payload or #encrypted_payload < 5 then
        Notify("Login Failed", "Invalid Key Format")
        return false
    end
    
    -- 2. XOR Decrypt
    local decrypted = xor_decrypt(encrypted_payload, SECRET_KEY)
    
    -- 3. Parse Payload "HWID|EXPIRY"
    local split = string.split(decrypted, "|")
    if #split < 2 then
        Notify("Login Failed", "Key Tampered/Invalid")
        return false
    end
    
    local key_hwid = split[1]
    local expiry_str = split[2]
    local expiry = tonumber(expiry_str)
    
    -- 4. Check if key is UNBOUND (First-Use Activation)
    if key_hwid == "UNBOUND" then
        Notify("Activating Key", "Binding to your device...")
        
        -- Generate new bound key
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
        
        -- Create bound payload
        local bound_payload = my_hwid .. "|" .. expiry_str
        local encrypted = encrypt_string(bound_payload, SECRET_KEY)
        local bound_key = base64_encode(encrypted)
        
        -- Save bound key
        if writefile then
            writefile("PXHB_Key.txt", bound_key)
        end
        
        -- NOTIFY DISCORD BOT (Webhook)
        pcall(function()
            local HttpService = game:GetService("HttpService")
            local webhook_url = "http://192.168.1.161:8080/activate"  -- AUTOMATED UPDATE
            
            local payload = HttpService:JSONEncode({
                key = key,  -- Original UNBOUND key
                hwid = my_hwid
            })
            
            local success = pcall(function()
                HttpService:PostAsync(webhook_url, payload, Enum.HttpContentType.ApplicationJson)
            end)
            
            if not success then
                print("[PXHB] Warning: Could not notify Discord bot (check webhook URL)")
            end
        end)
        
        Notify("Success", "Key Activated! Welcome.")
        return true
    end
    
    -- 5. Validate HWID (Already Bound)
    if key_hwid ~= my_hwid then
        Notify("Login Failed", "Key Already Bound To Another Device!")
        print("[PXHB] HWID Mismatch! Key HWID:", key_hwid, "Your HWID:", my_hwid)
        return false
    end
    
    -- 6. Validate Expiry
    if expiry < os.time() then
        Notify("Login Failed", "Key Expired!")
        return false
    end
    
    Notify("Success", "Welcome Back! License Valid.")
    return true
end

-- Stub Init (Not needed for offline)
function KeyAuth:Init() return true end

-- Automatic Login (No GUI - Key from Discord loadstring)
local function AutoLogin(onSuccess)
    local key = _G.LicenseKey or _G.PXHB_Key
    
    if not key or key == "" then
        -- Check for saved key file as fallback
        if isfile and isfile("PXHB_Key.txt") then
            key = readfile("PXHB_Key.txt")
        end
    end
    
    if not key or key == "" then
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("SendNotification", {
            Title = "PXHB Error",
            Text = "No license key found! Get your script from Discord.",
            Duration = 10
        })
        return
    end
    
    -- Validate the key
    if KeyAuth:Init() and KeyAuth:Login(key) then
        -- Save key for future use
        if writefile then 
            writefile("PXHB_Key.txt", key) 
        end
        -- Run the main script
        onSuccess()
    else
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("SendNotification", {
            Title = "PXHB Error",
            Text = "Invalid or expired license key!",
            Duration = 5
        })
    end
end

-- ============================================
-- SAFE MODE (Methods Fixed)
-- ============================================
task.wait(1)

-- WRAP MAIN SCRIPT
local function RunMainScript()
    print("[PXHB] Authenticated! Loading script...")

-- ============================================
-- SERVICES
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 10)
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)

local PracticeMode = game.PlaceId == 8206123457

-- ============================================
-- CONFIGURATION
-- ============================================

local Config = {
    -- QB Aimbot
    QB = {
        Enabled = false,
        Mode = "Dot",  -- Dot, Dive, Mag
        PowerBased = true,
        DesiredPower = 94,
        MaxAirTime = 20,
        YOffset = 1.25,
        XZOffset = 0,
        JumpPassHeight = 8.01
    },
    
    -- Mags
    Mags = {
        Enabled = false,
        Preset = "Legit",
        
        Presets = {
            Blatant = {
                MagDistance = 50,
                AutoDive = true,
                DiveDistance = 100,
                Delay = 0
            },
            Legit = {
                MagDistance = 28,
                AutoDive = true,
                DiveDistance = 55,
                Delay = 0.03
            },
            League = {
                MagDistance = 12,
                AutoDive = false,
                DiveDistance = 0,
                Delay = 0.08
            }
        }
    },
    
    -- Visuals
    Visuals = {
        BallTrajectory = false,
        BallInfo = false,
        SkeletonESP = false,
        CatchAssist = false,
        TrajectoryColor = Color3.fromRGB(0, 255, 150),
        ESPColor = Color3.fromRGB(255, 255, 255)
    },
    
    -- Settings
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

-- State
local State = {
    LockedTarget = nil,
    LockedTargetPos = nil,
    CurrentAirtime = 2,
    MenuOpen = false
}

local Gravity = 28
local BallSpawnOffset = Vector3.new(0, 3, 0)
local ThrowDelay = 0.15
local catchParts = {"CatchRight", "CatchLeft"}

-- ============================================
-- LOAD UI LIBRARY
-- ============================================

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/laagginq/ui-libraries/main/coastified/src.lua"))()
local Window = Lib:Window("PX-HB", "FF2", Enum.KeyCode.RightShift)

-- ============================================
-- QB TAB
-- ============================================

local QBTab = Window:Tab("QB")

QBTab:Toggle('QB Aimbot', function(state)
    Config.QB.Enabled = state
end)

QBTab:Dropdown("Catch Mode", {'Dot', 'Dive', 'Mag'}, function(mode)
    Config.QB.Mode = mode
end)

QBTab:Toggle('Power Based Aiming', function(state)
    Config.QB.PowerBased = state
end)

QBTab:Slider('Desired Power', 50, 95, 94, function(value)
    Config.QB.DesiredPower = value
end)

QBTab:Slider('Max Airtime', 5, 20, 20, function(value)
    Config.QB.MaxAirTime = value
end)

QBTab:Slider('Base Airtime', 1, 10, 2, function(value)
    State.CurrentAirtime = value
end)

-- ============================================
-- WR TAB (Mags)
-- ============================================

local WRTab = Window:Tab("WR")

WRTab:Toggle('Mags', function(state)
    Config.Mags.Enabled = state
end)

WRTab:Dropdown("Preset Mode", {'Blatant', 'Legit', 'League'}, function(preset)
    Config.Mags.Preset = preset
    
    -- Apply preset values to current settings
    local presetData = {
        Blatant = {MagDistance = 50, AutoDive = true, DiveDistance = 100, Delay = 0},
        Legit = {MagDistance = 28, AutoDive = true, DiveDistance = 55, Delay = 0.03},
        League = {MagDistance = 12, AutoDive = false, DiveDistance = 0, Delay = 0.08}
    }
    
    if presetData[preset] then
        Config.Mags.Presets[preset] = presetData[preset]
    end
end)

WRTab:Slider('Mag Distance Override', 5, 60, 28, function(value)
    -- Override the current preset's mag distance
    local currentPreset = Config.Mags.Preset
    if Config.Mags.Presets[currentPreset] then
        Config.Mags.Presets[currentPreset].MagDistance = value
    end
end)

WRTab:Toggle('Auto Dive Override', function(state)
    local currentPreset = Config.Mags.Preset
    if Config.Mags.Presets[currentPreset] then
        Config.Mags.Presets[currentPreset].AutoDive = state
    end
end)

WRTab:Slider('Dive Distance Override', 10, 100, 55, function(value)
    local currentPreset = Config.Mags.Preset
    if Config.Mags.Presets[currentPreset] then
        Config.Mags.Presets[currentPreset].DiveDistance = value
    end
end)

WRTab:Slider('Catch Delay (ms)', 0, 200, 30, function(value)
    local currentPreset = Config.Mags.Preset
    if Config.Mags.Presets[currentPreset] then
        Config.Mags.Presets[currentPreset].Delay = value / 1000
    end
end)

-- ============================================
-- VISUALS TAB
-- ============================================

local VisualsTab = Window:Tab("Visuals")

VisualsTab:Toggle('Ball Trajectory ESP', function(state)
    Config.Visuals.BallTrajectory = state
end)

VisualsTab:Toggle('Ball Speed & Distance', function(state)
    Config.Visuals.BallInfo = state
end)

VisualsTab:Toggle('Player Skeleton ESP', function(state)
    Config.Visuals.SkeletonESP = state
end)

VisualsTab:Toggle('Show Mag Range', function(state)
    Config.Visuals.ShowMagRange = state
end)

VisualsTab:Toggle('Show Ball Hitbox', function(state)
    Config.Visuals.ShowBallHitbox = state
end)

VisualsTab:Toggle('Catch Assist (Highlight Best WR)', function(state)
    Config.Visuals.CatchAssist = state
end)

VisualsTab:Colorpicker("Trajectory Color", Color3.fromRGB(0, 255, 150), function(color)
    Config.Visuals.TrajectoryColor = color
end)

VisualsTab:Colorpicker("ESP Color", Color3.fromRGB(255, 255, 255), function(color)
    Config.Visuals.ESPColor = color
end)

-- ============================================
-- SETTINGS TAB
-- ============================================

local SettingsTab = Window:Tab("Settings")

-- License System
local LicenseStatus = "Not Verified"
local LicenseExpiry = "N/A"

SettingsTab:Dropdown("License Status", {LicenseStatus}, function(status)
    -- Display only, auto-updates
end)

-- License key input workaround (using slider as placeholder until textbox)
SettingsTab:Toggle('License Verified', function(state)
    if state then
        Config.Settings.LicenseValid = false
    end
end)

-- Config System
SettingsTab:Dropdown("Config Preset", {'Default', 'Aggressive', 'Passive', 'Custom'}, function(preset)
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
end)

SettingsTab:Toggle('Save Config', function(state)
    if state then
        local success, err = pcall(function()
            if writefile then
                local configData = game:GetService("HttpService"):JSONEncode({
                    QB = Config.QB,
                    Mags = {
                        Enabled = Config.Mags.Enabled,
                        Preset = Config.Mags.Preset
                    },
                    Visuals = Config.Visuals
                })
                writefile("PXHB_FF2_Config.json", configData)
            end
        end)
    end
end)

SettingsTab:Toggle('Load Config', function(state)
    if state then
        local success, err = pcall(function()
            if readfile and isfile and isfile("PXHB_FF2_Config.json") then
                local configData = readfile("PXHB_FF2_Config.json")
                local loaded = game:GetService("HttpService"):JSONDecode(configData)
                
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
            end
        end)
    end
end)

SettingsTab:Slider('UI Toggle Delay (ms)', 0, 500, 100, function(value)
    -- Placeholder for UI responsiveness setting
end)

-- ============================================
-- QB PHYSICS
-- ============================================

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

-- ============================================
-- QB THROW SYSTEM
-- ============================================

local invalidPower_retryDir = 1
local maxRetries = 100

local function throw(targetPos, _Time)
    -- Rate limit throws (500ms minimum between throws)
    if (tick() - (State.LastThrowTime or 0)) < 0.5 then return end
    
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
    
    -- Iterative power adjustment (NOT recursive - prevents spam)
    for attempt = 1, 20 do
        local vel3 = calcVel(originPos, targetPos, Gravity, T)
        local pow = vel3.Magnitude
        
        if pow <= 95 then
            -- Valid power found, fire throw
            local powerRoundedClamped = math.clamp(math.round(pow), 1, 95)
            local throwDir = vel3.Unit
            
            -- FIXED: EXPERIMENTAL "FULL REMOVE TELEPORT"
            -- We send strict natural coordinates. No offsets.
            local originPosAdjusted = originPos
            local targetPoint = targetPos
            
            if PracticeMode then
                fbRemote:FireServer("Clicked", originPosAdjusted, targetPoint, powerRoundedClamped, powerRoundedClamped)
            else
                -- FIXED: arg4 and arg5 MUST MATCH or server detects tampering!
                fbRemote:FireServer("Clicked", originPosAdjusted, targetPoint, powerRoundedClamped, powerRoundedClamped)
            end
            
            State.CurrentAirtime = T
            State.LastThrowTime = tick()
            return
        end
        
        -- Adjust time for next attempt
        if T > Config.QB.MaxAirTime or T <= 0.1 then
            invalidPower_retryDir = -invalidPower_retryDir
        end
        T = T + (0.05 * invalidPower_retryDir)
    end
end

-- ============================================
-- QB UTILITY FUNCTIONS
-- ============================================

local function getPing()
    local s, p = pcall(function() return Stats.PerformanceStats.Ping:GetValue() end)
    return s and p or 50
end

local function getServerPing()
    local s, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return s and p or 50
end

local function getReleaseTime()
    return ThrowDelay + (getPing() + getServerPing()) / 1000
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

-- ============================================
-- MAGS UTILITY FUNCTIONS
-- ============================================



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

local function isTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

-- ============================================
-- MAGS - FOOTBALL DETECTION
-- ============================================

GuiService.MenuOpened:Connect(function() State.MenuOpen = true end)
GuiService.MenuClosed:Connect(function() State.MenuOpen = false end)

-- Helper to get all valid catch parts
local function getCatchParts(char)
    local parts = {}
    
    -- Priority: Game-specific catch parts
    local specific = {"CatchRight", "CatchLeft", "Catch"}
    for _, name in pairs(specific) do
        local p = char:FindFirstChild(name)
        if p then table.insert(parts, p) end
    end
    
    -- Fallback/Augment: Hands and Arms
    local limbs = {"RightHand", "LeftHand", "Right Arm", "Left Arm"}
    for _, name in pairs(limbs) do
        local p = char:FindFirstChild(name)
        if p then table.insert(parts, p) end
    end
    
    -- Fallback: Head (Head catches)
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
        -- Check enabled state EVERY frame from Config
        if Config.Mags.Enabled == true then
            local presetName = Config.Mags.Preset
            local preset = Config.Mags.Presets[presetName]
            
            if preset then
                -- Get all valid catch surface candidates
                local validParts = getCatchParts(character)
                local distance, catchPart = findBestCatchPart(object, validParts)
                
                if catchPart then
                    -- Auto dive
                    if preset.AutoDive == true and distance <= preset.DiveDistance and not (isTyping() or State.MenuOpen) then
                        if keypress and keyrelease then
                            keypress(67)
                            keyrelease(67)
                        end
                    end
                    
                    -- Mag catch (Manual/Legit Mode)
                    if distance <= preset.MagDistance then
                        -- Require Left Click (manual mode)
                        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then 
                            
                            -- Rate limit with JITTER (250-400ms) to avoid detection
                            local jitter = 0.25 + (math.random() * 0.15)
                            if (tick() - (State.LastMagTime or 0)) > jitter then
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

-- ============================================
-- QB INPUT HANDLING
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- QB Throw - Press E to throw (not left click, that conflicts with game)
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
            
            throw(throwPos, throwTime, 0)
        end
    end
end)

-- ============================================
-- CHARACTER RESPAWN
-- ============================================

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid", 10)
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
end)

-- ============================================
-- QB AIMBOT REMOVED
-- ============================================
-- QB Aimbot has been disabled to prevent detection.
-- Use PXHB_QB_Stealth.lua for a safer alternative.


-- ============================================
-- VISUALS RENDERING
-- ============================================

-- Drawing storage
local Drawings = {
    BallTrajectory = {},
    BallInfo = nil,
    Skeletons = {},
    CatchAssist = nil
}

-- Create ball info display
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

-- Create catch assist circle
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

-- Create mag range circle
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

-- Skeleton bone connections (R15)
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

-- Skeleton bone connections (R6)
local SkeletonBonesR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

-- Helper to find football part (searches entire workspace)
local function getFootballPart()
    -- First try direct child
    local football = Workspace:FindFirstChild("Football")
    
    -- If not found directly, search descendants
    if not football then
        for _, child in pairs(Workspace:GetChildren()) do
            if child.Name == "Football" then
                football = child
                break
            end
        end
    end
    
    if not football then return nil end
    
    -- Football might be a Model or a Part
    if football:IsA("BasePart") then
        return football
    elseif football:IsA("Model") then
        local primary = football.PrimaryPart or football:FindFirstChildWhichIsA("BasePart")
        return primary
    end
    
    return football:FindFirstChildWhichIsA("BasePart")
end

-- Helper to get skeleton bones for a character
local function getSkeletonBones(char)
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.RigType == Enum.HumanoidRigType.R15 then
        return SkeletonBonesR15
    else
        return SkeletonBonesR6
    end
end

-- Visual update loop
RunService.RenderStepped:Connect(function()
    -- Ball Trajectory ESP (OPTIMIZED: Reuse drawing objects)
    if Config.Visuals.BallTrajectory == true then
        -- Pre-create trajectory line pool ONCE
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
                -- Reuse existing line objects
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
                -- Hide all lines when no ball movement
                for _, line in ipairs(Drawings.TrajectoryPool) do
                    line.Visible = false
                end
            end
        else
            -- Hide all when no football
            if Drawings.TrajectoryPool then
                for _, line in ipairs(Drawings.TrajectoryPool) do
                    line.Visible = false
                end
            end
        end
    else
        -- Hide trajectory when disabled
        if Drawings.TrajectoryPool then
            for _, line in ipairs(Drawings.TrajectoryPool) do
                line.Visible = false
            end
        end
    end
    
    -- Ball Info Display
    if Config.Visuals.BallInfo == true then
        if not Drawings.BallInfo then createBallInfoDisplay() end
        
        local football = getFootballPart()
        if football and Drawings.BallInfo and Character and HumanoidRootPart then
            local ballPos = football.Position
            local playerPos = HumanoidRootPart.Position
            local distance = (ballPos - playerPos).Magnitude
            local speed = (football.Velocity or Vector3.new(0,0,0)).Magnitude
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(ballPos)
            
            if onScreen then
                Drawings.BallInfo.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
                Drawings.BallInfo.Text = string.format("%.0f studs | %.0f speed", distance, speed)
                Drawings.BallInfo.Color = Config.Visuals.TrajectoryColor
                Drawings.BallInfo.Visible = true
            else
                Drawings.BallInfo.Visible = false
            end
        elseif Drawings.BallInfo then
            Drawings.BallInfo.Visible = false
        end
    elseif Drawings.BallInfo then
        Drawings.BallInfo.Visible = false
    end
    
    -- Skeleton ESP (OPTIMIZED: Reuse drawing objects)
    if Config.Visuals.SkeletonESP == true then
        -- Pre-create skeleton line pool ONCE (max 100 lines for all players)
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
            
            -- Hide unused lines from the pool
            for i = lineIndex, #Drawings.SkeletonPool do
                Drawings.SkeletonPool[i].Visible = false
            end
        end
    else
        -- Hide all skeleton lines when disabled
        if Drawings.SkeletonPool then
            for _, line in ipairs(Drawings.SkeletonPool) do
                line.Visible = false
            end
        end
    end
    
    -- Mag Range Visualizer
    if Config.Visuals.ShowMagRange == true then
        if not Drawings.MagRange then createMagRange() end
        
        if Drawings.MagRange and Character and HumanoidRootPart then
            local currentPreset = Config.Mags.Presets[Config.Mags.Preset]
            if currentPreset then
                local magDist = currentPreset.MagDistance
                local rootPos = HumanoidRootPart.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos - Vector3.new(0, 3, 0)) -- Position at feet
                
                if onScreen then
                    local camPos = Camera.CFrame.Position
                    local dist = (rootPos - camPos).Magnitude
                    local fov = Camera.FieldOfView
                    local viewportSize = Camera.ViewportSize
                    
                    -- Calculate screen radius for the 3D distance
                    -- Radius = (RadiusWorld / tan(FOV/2)) * (ViewportHeight/2) / Distance
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
    
    -- Ball Hitbox Visualizer (Circle around football)
    if Config.Visuals.ShowBallHitbox == true then
        local football = getFootballPart()
        
        if football then
            -- Create ball hitbox circle if not exists
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
                    -- Ball hitbox is roughly 2-3 studs (ball size)
                    local hitboxRadius = 2.5
                    
                    local camPos = Camera.CFrame.Position
                    local dist = (ballPos - camPos).Magnitude
                    local fov = Camera.FieldOfView
                    local viewportSize = Camera.ViewportSize
                    
                    -- Calculate screen radius
                    local radiusRaw = (hitboxRadius / math.tan(math.rad(fov) / 2)) * (viewportSize.Y / 2) / dist
                    
                    Drawings.BallHitbox.Radius = math.max(radiusRaw, 5) -- Min 5px so it's visible
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
    
    -- Catch Assist (highlight best receiver)
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
                        Drawings.CatchAssist.Color = Color3.fromRGB(255, 200, 0) -- Gold highlight
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

end -- End of RunMainScript

-- Start Authentication
AutoLogin(RunMainScript)

