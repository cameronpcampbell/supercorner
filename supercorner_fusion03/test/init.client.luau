--!strict

local Fusion = require(script.Packages.fusion)
local Supercorner = require(script.Packages["supercorner-fusion03"])

local Players = game:GetService("Players")

local Scoped, Peek = Fusion.scoped, Fusion.peek

local Scope = Scoped(Fusion)

local CornerRadiusState = Scope:Value(75)
local CornerSmoothingState = Scope:Value(1)

task.spawn(function()
	local peekedCornerRadius = Peek(CornerRadiusState)
	local peekedCornerSmoothing = Peek(CornerSmoothingState)

	while peekedCornerRadius > 0 or peekedCornerSmoothing > 0 do
		task.wait(0.1)

		peekedCornerRadius = math.max(peekedCornerRadius - 2, 0)
		peekedCornerSmoothing = math.max(peekedCornerSmoothing - 2 / 35, 0)

		CornerRadiusState:set(peekedCornerRadius)
		CornerSmoothingState:set(peekedCornerSmoothing)
	end
end)

Scope:New("ScreenGui") {
	Parent = Players.LocalPlayer.PlayerGui,

	[Fusion.Children] = {
		MySupercorner = Supercorner(Scope, {
			CornerRadius = CornerRadiusState,
			CornerSmoothing = CornerSmoothingState,
			Redrawable = true,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = BrickColor.Yellow().Color,
			BackgroundTransparency = 0.5,
			StrokeThickness = 5,
			StrokeGradient = Scope:New("UIGradient") {
				Color = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
			},

			[Fusion.Children] = {
				Scope:New("Frame") {
					Size = UDim2.fromScale(1, 1),
					Transparency = 0.5,
				},
			},
		}),
	},
}
