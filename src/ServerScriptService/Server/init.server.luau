--!strict
-- Server bootstrap. Order matters: remotes, then the world, then data, then gameplay.
-- Characters are loaded manually (after data loads) so nobody spawns before the world exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes) -- creates the RemoteEvents

require(script.Data).Init()

local ok, err = pcall(function()
	require(script.World).Build()
end)
if not ok then
	warn("[Server] World build failed: " .. tostring(err))
end

require(script.Game).Init()
