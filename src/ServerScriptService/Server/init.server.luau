--!strict
-- Server bootstrap. Order matters: remotes and world first, then data, then gameplay.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes) -- creates the RemoteEvents

require(script.World).Init()
require(script.Data).Init()
require(script.Game).Init()
