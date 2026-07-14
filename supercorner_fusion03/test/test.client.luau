--!strict

local Packages = script.Parent.Packages
local Fusion = require(Packages.roblox_packages.fusion)
local Supercorner = require(Packages.supercorner_fusion03)
local Shared = require(Packages.supercorner_fusion03.shared)

local Players = game:GetService("Players")

local Scoped, Peek = Fusion.scoped, Fusion.peek

local Scope = Scoped(Fusion)
local ForeignChildren = table.clone(Fusion.Children) :: any

local CornerRadiusState = Scope:Value(75)
local CornerSmoothingState = Scope:Value(1)
local BackgroundTransparencyState = Scope:Value(0.5)
local StrokeThicknessState = Scope:Value(5)

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

local FallbackContentChild = Scope:New("Folder") {
	Name = "FallbackRegularChild",
}

local FallbackRootChild = Scope:New("Folder") {
	Name = "FallbackRootChild",
}

local SupercornerRoot = Supercorner.new(Scope, {
	CornerRadius = CornerRadiusState,
	CornerSmoothing = CornerSmoothingState,
	Redrawable = true,
	Size = UDim2.fromScale(0.8, 0.8),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = BrickColor.Yellow().Color,
	BackgroundTransparency = BackgroundTransparencyState,
	StrokeThickness = StrokeThicknessState,
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

local FallbackRoot = Shared.RenderFallback(
	Scope,
	{
		topLeft = 12,
		topRight = 12,
		bottomRight = 12,
		bottomLeft = 12,
	},
	{
		Name = "Fallback",
		Visible = false,
		Size = UDim2.fromOffset(100, 100),
	},
	{ FallbackContentChild },
	{
		bgColor = Color3.new(1, 1, 1),
		bgTransparency = 0,
		strokeThickness = 0,
		strokeColor = Color3.new(0, 0, 0),
		strokeTransparency = 0,
		strokeGradient = nil,
	},
	false,
	{ FallbackRootChild }
)

local function AssertHierarchy()
	local content = SupercornerRoot:FindFirstChild("Content")
	assert(content ~= nil and content:IsA("Frame"), "Supercorner must contain a Content Frame")
	assert(ContentChild.Parent == content, "Regular children must remain parented to the Content Frame")
	assert(ForeignContentChild.Parent == content, "Children from another Fusion instance must be parented to Content")
	assert(RootChild.Parent == SupercornerRoot, "RootChildren must remain parented to the Supercorner root")

	local fallbackContent = FallbackRoot:FindFirstChild("Content")
	assert(fallbackContent ~= nil and fallbackContent:IsA("Frame"), "Fallback must contain a Content Frame")
	assert(FallbackContentChild.Parent == fallbackContent, "Fallback regular children must remain under Content")
	assert(FallbackRootChild.Parent == FallbackRoot, "Fallback RootChildren must remain under the root")
end

AssertHierarchy()
task.defer(AssertHierarchy)

task.spawn(function()
	local peekedCornerRadius = Peek<<number>>(CornerRadiusState) :: number
	local peekedCornerSmoothing = Peek<<number>>(CornerSmoothingState) :: number

	while peekedCornerRadius > 0 or peekedCornerSmoothing > 0 do
		task.wait(0.1)

		peekedCornerRadius = math.max(peekedCornerRadius - 2, 0)
		peekedCornerSmoothing = math.max(peekedCornerSmoothing - 2 / 35, 0)

		CornerRadiusState:set(peekedCornerRadius)
		CornerSmoothingState:set(peekedCornerSmoothing)
		task.defer(AssertHierarchy)
	end
end)

task.spawn(function()
	task.wait(0.2)
	BackgroundTransparencyState:set(1)
	StrokeThicknessState:set(0)
	task.defer(AssertHierarchy)

	task.wait(0.1)
	BackgroundTransparencyState:set(0.5)
	StrokeThicknessState:set(5)
	task.defer(AssertHierarchy)
end)

Scope:New("ScreenGui") {
	Parent = Players.LocalPlayer.PlayerGui,

	[Fusion.Children] = {
		MySupercorner = SupercornerRoot,
		Fallback = FallbackRoot,
	},
}
