--!strict

local Packages = script.Parent.Packages
local Fusion = require(Packages.roblox_packages.fusion)
local RasterSupercorner = require(Packages.roblox_packages.supercorner)
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
local SquareBackgroundTransparencyState = Scope:Value(0.25)
local SquareStrokeThicknessState = Scope:Value(4)

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

local SquareContentChild = Scope:New("Folder") {
	Name = "SquareRegularChild",
}

local SquareRootChild = Scope:New("Folder") {
	Name = "SquareRootChild",
}

local SquareStrokeGradient = Scope:New("UIGradient") {
	Color = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
}

local editableCacheBeforeSquares = RasterSupercorner.GetCacheSize()
local staticCacheBeforeSquares = RasterSupercorner.GetStaticCacheSize()

local SquareRoot = Supercorner.new(Scope, {
	CornerRadius = 0,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
	BackgroundColor3 = Color3.new(0.25, 0.5, 0.75),
	BackgroundTransparency = SquareBackgroundTransparencyState,
	StrokeThickness = SquareStrokeThicknessState,
	StrokeColor = Color3.new(0.75, 0.5, 0.25),
	StrokeTransparency = 0.125,
	StrokeGradient = SquareStrokeGradient,
	RootChildren = { SquareRootChild },

	[Fusion.Children] = {
		SquareContentChild,
	},
})

local HollowSquareRoot = Supercorner.new(Scope, {
	CornerRadius = 0,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
	BackgroundTransparency = 1,
	StrokeThickness = 2,
})

local EmptySquareRoot = Supercorner.new(Scope, {
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
	BackgroundTransparency = 1,
	StrokeThickness = 0,
})

local OverriddenSquareRoot = Supercorner.new(Scope, {
	CornerRadius = 12,
	TopLeftRadius = 0,
	TopRightRadius = 0,
	BottomRightRadius = 0,
	BottomLeftRadius = 0,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
	BackgroundTransparency = 1,
})

local SquareButtonRoot = Supercorner.new(Scope, {
	Button = true,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
})

assert(
	RasterSupercorner.GetCacheSize() == editableCacheBeforeSquares,
	"Static zero-radius supercorners must not allocate editable image cache entries"
)
assert(
	RasterSupercorner.GetStaticCacheSize() == staticCacheBeforeSquares,
	"Static zero-radius supercorners must not allocate static image cache entries"
)

local NonSquareCornerRoot = Supercorner.new(Scope, {
	CornerRadius = 0,
	TopLeftRadius = 1,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
})

local RedrawableSquareRoot = Supercorner.new(Scope, {
	CornerRadius = 0,
	Redrawable = true,
	Size = UDim2.fromOffset(100, 100),
	Visible = false,
})

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

local function GetSquareFill(root: Instance): Frame
	local graphics = root:FindFirstChild("SupercornerImages")
	assert(graphics ~= nil and graphics:IsA("Folder"), "Optimized square must retain the graphics container")

	local fill = graphics:FindFirstChild("Fill")
	assert(fill ~= nil and fill:IsA("Frame"), "Optimized square fill must use a Frame")
	assert(
		root:FindFirstChildWhichIsA("ImageLabel", true) == nil,
		"Optimized square must not contain image renderers"
	)

	return fill :: Frame
end

local function AssertNotOptimizedSquare(root: Instance)
	local graphics = root:FindFirstChild("SupercornerImages")
	if not graphics then return end

	local fill = graphics:FindFirstChild("Fill")
	assert(fill == nil or not fill:IsA("Frame"), "Nonzero or redrawable geometry must stay on the image path")
end

local function AssertSquareHierarchy()
	assert(SquareRoot:IsA("Frame"), "Optimized square roots must remain Frames")

	local fill = GetSquareFill(SquareRoot)
	assert(
		fill.BackgroundTransparency == (Peek<<number>>(SquareBackgroundTransparencyState) :: number),
		"Optimized square fill transparency must stay reactive"
	)

	local strokeThickness = Peek<<number>>(SquareStrokeThicknessState) :: number
	local stroke = fill:FindFirstChild("Stroke")

	if strokeThickness > 0 then
		assert(stroke ~= nil and stroke:IsA("UIStroke"), "Optimized square must use UIStroke for its stroke")
		assert(stroke.Thickness == strokeThickness, "Optimized square stroke thickness must stay reactive")
		assert(stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border, "Square stroke must render as a border")
		assert(
			stroke.BorderStrokePosition == Enum.BorderStrokePosition.Inner,
			"Square stroke must remain inside its bounds"
		)
		assert(stroke.LineJoinMode == Enum.LineJoinMode.Miter, "Square stroke must retain sharp corners")
		assert(stroke.ZIndex == 3, "Square stroke must render above content")
		assert(stroke:FindFirstChildWhichIsA("UIGradient") ~= nil, "Square stroke must preserve its gradient")
	else
		assert(stroke == nil, "Optimized square must remove UIStroke when stroke thickness is zero")
	end

	local content = SquareRoot:FindFirstChild("Content")
	assert(content ~= nil and content:IsA("Frame"), "Optimized square must contain a Content Frame")
	assert(SquareContentChild.Parent == content, "Optimized square children must remain under Content")
	assert(SquareRootChild.Parent == SquareRoot, "Optimized square RootChildren must remain under the root")

	local hollowFill = GetSquareFill(HollowSquareRoot)
	assert(hollowFill.BackgroundTransparency == 1, "A hollow optimized square must have a transparent Frame")
	assert(hollowFill:FindFirstChildWhichIsA("UIStroke") ~= nil, "A hollow optimized square may retain its stroke")

	local emptyFill = GetSquareFill(EmptySquareRoot)
	assert(emptyFill.BackgroundTransparency == 1, "An empty optimized square must have a transparent Frame")
	assert(emptyFill:FindFirstChildWhichIsA("UIStroke") == nil, "A zero-thickness stroke must not create UIStroke")

	GetSquareFill(OverriddenSquareRoot)
	assert(SquareButtonRoot:IsA("TextButton"), "Button optimized squares must remain TextButtons")
	GetSquareFill(SquareButtonRoot)
	AssertNotOptimizedSquare(NonSquareCornerRoot)
	AssertNotOptimizedSquare(RedrawableSquareRoot)
end

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
AssertSquareHierarchy()
task.defer(AssertHierarchy)
task.defer(AssertSquareHierarchy)

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
	SquareBackgroundTransparencyState:set(1)
	SquareStrokeThicknessState:set(0)
	task.defer(AssertHierarchy)
	task.defer(AssertSquareHierarchy)

	task.wait(0.1)
	BackgroundTransparencyState:set(0.5)
	StrokeThicknessState:set(5)
	SquareBackgroundTransparencyState:set(0.25)
	SquareStrokeThicknessState:set(4)
	task.defer(AssertHierarchy)
	task.defer(AssertSquareHierarchy)
end)

Scope:New("ScreenGui") {
	Parent = Players.LocalPlayer.PlayerGui,

	[Fusion.Children] = {
		MySupercorner = SupercornerRoot,
		Fallback = FallbackRoot,
		Square = SquareRoot,
		HollowSquare = HollowSquareRoot,
		EmptySquare = EmptySquareRoot,
		OverriddenSquare = OverriddenSquareRoot,
		SquareButton = SquareButtonRoot,
		NonSquareCorner = NonSquareCornerRoot,
		RedrawableSquare = RedrawableSquareRoot,
	},
}
