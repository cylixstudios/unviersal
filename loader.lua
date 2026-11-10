--[[
    Savior Hub - Direct Loader (No Auth)
]]

local Services = {
    Players = game:GetService("Players"),
    CoreGui = game:GetService("CoreGui"),
    HttpService = game:GetService("HttpService")
}

local LocalPlayer = Services.Players.LocalPlayer
local guiParent = Services.CoreGui or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))

-- Clean up any existing loader or auth GUI
for _, name in ipairs({"SaviorAuthScreen", "SaviorLoaderScreen", "SaviorAuthGatewayScreen"}) do
    local existing = guiParent:FindFirstChild(name)
    if existing then
        pcall(function() existing:Destroy() end)
    end
end

-- Execute Universal Main Core directly
local executed = false
if readfile and isfile and isfile("universal.lua") then
    local ok, code = pcall(readfile, "universal.lua")
    if ok and code and #code > 0 then
        local fn = loadstring(code)
        if fn then
            pcall(fn)
            executed = true
        end
    end
end

if not executed then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/cylixstudios/unviersal/main/universal.lua", true))()
end
