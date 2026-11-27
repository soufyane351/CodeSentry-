--!strict
-- Client entry point. No remote events or game-state access are used.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packageFolder = ReplicatedStorage:WaitForChild("CodeSentry")
local sharedFolder = packageFolder:WaitForChild("Shared")
local clientFolder = script.Parent

local Config = require(sharedFolder:WaitForChild("Config"))
local UIController = require(clientFolder:WaitForChild("UIController"))

local previous = playerGui:FindFirstChild("CodeSentry")
if previous then
	previous:Destroy()
end

local controller = UIController.new(playerGui, Config.copy())
controller:Start()

script.Destroying:Connect(function()
	controller:Destroy()
end)
