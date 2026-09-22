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

local gameOk, gameErr = pcall(function()
	require(script.Game).Init()
end)
if not gameOk then
	-- The whole server (Buy, Detonate, characters spawning — everything Game.luau wires up) depends on this succeeding.
	-- A bad edit to a Config/* file (a typo, an unquoted value) throws here and used to take the server down silently,
	-- with players left standing in a world that never responds to anything. Now it is at least a loud Output warning.
	warn("[Server] Game.Init failed, nothing will work until this is fixed: " .. tostring(gameErr))
end
