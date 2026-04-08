--!strict

local Fusion = require(script.Packages.fusion)
local Supercorner = require(script.Packages["supercorner-fusion03"])

local Players = game:GetService("Players")

local Scoped, Peek = Fusion.scoped, Fusion.peek

local Scope = Scoped(Fusion)

local AlphaState = Scope:Value(0)

task.spawn(function()
	local alpha = 0

	while alpha < 1 do
		task.wait(0.1)

		alpha = math.min(alpha + 1 / 37, 1)
		AlphaState:set(alpha)
	end
end)

Scope:New("ScreenGui") {
	Parent = Players.LocalPlayer.PlayerGui,

	[Fusion.Children] = {
		MySupercorner = Supercorner.atlas(Scope, {
			Start = { CornerRadius = 30, CornerSmoothing = 1 },
			End = { CornerRadius = 0, CornerSmoothing = 0 },
			Keypoints = 25,
			Alpha = AlphaState,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = BrickColor.Yellow().Color,
			BackgroundTransparency = 0.5,
			StrokeThickness = 5,
			StrokeColor = Color3.new(1, 1, 1),
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
