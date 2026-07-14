--!strict

local Packages = script.Parent.Packages
local Fusion = require(Packages.roblox_packages.fusion)
local Supercorner = require(Packages.supercorner_fusion03)

local Players = game:GetService("Players")

local Scoped = Fusion.scoped

local Scope = Scoped(Fusion)
local ForeignChildren = table.clone(Fusion.Children) :: any

local AlphaState = Scope:Value(0)

local ContentChild = Scope:New("Frame") {
	Name = "RegularChild",
	Size = UDim2.fromScale(1, 1),
	Transparency = 0.5,
}

local ForeignContentChild = Scope:New("Folder") {
	Name = "ForeignFusionRegularChild",
}

local RootChild = Scope:New("Folder") {
	Name = "RootChild",
}

local SupercornerRoot = Supercorner.atlas(Scope, {
	Start = { CornerRadius = 30, CornerSmoothing = 1 },
	End = { CornerRadius = 0, CornerSmoothing = 0 },
	Keypoints = 25,
	Alpha = AlphaState,
	Button = true,
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
	RootChildren = { RootChild },

	[Fusion.Children] = {
		ContentChild,
	},

	[ForeignChildren] = {
		ForeignContentChild,
	},
})

local function AssertHierarchy()
	local content = SupercornerRoot:FindFirstChild("Content")
	assert(SupercornerRoot:IsA("TextButton"), "Button atlas roots must be TextButtons")
	assert(content ~= nil and content:IsA("Frame"), "Supercorner atlas must contain a Content Frame")
	assert(ContentChild.Parent == content, "Atlas regular children must remain parented to the Content Frame")
	assert(ForeignContentChild.Parent == content, "Atlas children from another Fusion instance must be parented to Content")
	assert(RootChild.Parent == SupercornerRoot, "Atlas RootChildren must remain parented to the root")
end

AssertHierarchy()
task.defer(AssertHierarchy)

task.spawn(function()
	local alpha = 0

	while alpha < 1 do
		task.wait(0.1)

		alpha = math.min(alpha + 1 / 37, 1)
		AlphaState:set(alpha)
		task.defer(AssertHierarchy)
	end
end)

Scope:New("ScreenGui") {
	Parent = Players.LocalPlayer.PlayerGui,

	[Fusion.Children] = {
		MySupercorner = SupercornerRoot,
	},
}
