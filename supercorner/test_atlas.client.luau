--!strict

local RepStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Supercorner = require(RepStorage.supercorner)
local Atlas = Supercorner.atlas

local SIZE = 200
local SLIDER_HEIGHT = 40
local KEYPOINTS = 25

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = Players.LocalPlayer.PlayerGui

local Bg = Instance.new("Frame")
Bg.Size = UDim2.fromScale(1, 1)
Bg.BackgroundColor3 = Color3.fromRGB(255, 253, 240)
Bg.BorderSizePixel = 0
Bg.Parent = ScreenGui

local BgPadding = Instance.new("UIPadding")
BgPadding.PaddingTop = UDim.new(0, 80)
BgPadding.PaddingBottom = UDim.new(0, 80)
BgPadding.PaddingLeft = UDim.new(0, 80)
BgPadding.PaddingRight = UDim.new(0, 80)
BgPadding.Parent = Bg

-- Main column
local Column = Instance.new("Frame")
Column.Size = UDim2.new(0, 300, 1, 0)
Column.AnchorPoint = Vector2.new(0.5, 0)
Column.Position = UDim2.fromScale(0.5, 0)
Column.BackgroundTransparency = 1
Column.Parent = Bg

local Layout = Instance.new("UIListLayout")
Layout.FillDirection = Enum.FillDirection.Vertical
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 20)
Layout.Parent = Column

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(66, 61, 38)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBlack
Title.Text = "Atlas Test"
Title.LayoutOrder = 0
Title.Parent = Column

-- Preview image
local ImageLabel = Instance.new("ImageLabel")
ImageLabel.Size = UDim2.fromOffset(SIZE, SIZE)
ImageLabel.BackgroundTransparency = 1
ImageLabel.ImageColor3 = Color3.fromRGB(120, 108, 70)
ImageLabel.ScaleType = Enum.ScaleType.Slice
ImageLabel.LayoutOrder = 1
ImageLabel.Parent = Column

-- Info label
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 48)
InfoLabel.BackgroundTransparency = 1
InfoLabel.TextColor3 = Color3.fromRGB(100, 92, 60)
InfoLabel.TextSize = 14
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.TextWrapped = true
InfoLabel.LayoutOrder = 2
InfoLabel.Parent = Column

-- Keypoint strip (shows all keypoints side by side)
local StripLabel = Instance.new("TextLabel")
StripLabel.Size = UDim2.new(1, 0, 0, 18)
StripLabel.BackgroundTransparency = 1
StripLabel.TextColor3 = Color3.fromRGB(66, 61, 38)
StripLabel.TextSize = 14
StripLabel.Font = Enum.Font.GothamBold
StripLabel.Text = "All Keypoints"
StripLabel.LayoutOrder = 3
StripLabel.Parent = Column

local StripContainer = Instance.new("Frame")
StripContainer.Size = UDim2.new(1, 0, 0, 60)
StripContainer.BackgroundTransparency = 1
StripContainer.LayoutOrder = 4
StripContainer.Parent = Column

local StripLayout = Instance.new("UIListLayout")
StripLayout.FillDirection = Enum.FillDirection.Horizontal
StripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
StripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
StripLayout.SortOrder = Enum.SortOrder.LayoutOrder
StripLayout.Padding = UDim.new(0, 4)
StripLayout.Parent = StripContainer

-- State
local StartRadius = 0
local EndRadius = 40
local StartSmoothing = 1.0
local EndSmoothing = 1.0
local currentAlpha = 0

local atlas: Supercorner.SupercornerAtlas? = nil
local stripImages: { ImageLabel } = {}

local function RebuildAtlas()
	if atlas then
		atlas:Destroy()
	end

	atlas = Atlas({
		Start = { CornerRadius = StartRadius, CornerSmoothing = StartSmoothing },
		End = { CornerRadius = EndRadius, BottomLeftRadius = 65, CornerSmoothing = EndSmoothing },
		Keypoints = KEYPOINTS,
	})

	local a = atlas :: Supercorner.SupercornerAtlas
	local content = a:GetContent()

	-- Update main preview
	local kp = a:GetKeypointFromAlpha(currentAlpha)
	ImageLabel.ImageContent = content
	ImageLabel.ImageRectOffset = kp.ImageRectOffset
	ImageLabel.ImageRectSize = kp.ImageRectSize
	ImageLabel.SliceCenter = kp.SliceCenter
	ImageLabel.SliceScale = kp.SliceScale

	InfoLabel.Text = `Keypoints: {a:GetKeypointCount()} | Offset: {kp.ImageRectOffset} | Size: {kp.ImageRectSize}`

	-- Rebuild strip
	for _, img in stripImages do
		img:Destroy()
	end

	table.clear(stripImages)

	local thumbSize = math.floor(math.min(60, 280 / a:GetKeypointCount()))

	for idx = 1, a:GetKeypointCount() do
		local kpData = a:GetKeypoint(idx)

		local thumb = Instance.new("ImageLabel")
		thumb.Size = UDim2.fromOffset(thumbSize, thumbSize)
		thumb.BackgroundTransparency = 1
		thumb.ImageColor3 = Color3.fromRGB(120, 108, 70)
		thumb.ScaleType = Enum.ScaleType.Slice
		thumb.ImageContent = content
		thumb.ImageRectOffset = kpData.ImageRectOffset
		thumb.ImageRectSize = kpData.ImageRectSize
		thumb.SliceCenter = kpData.SliceCenter
		thumb.SliceScale = kpData.SliceScale
		thumb.LayoutOrder = idx
		thumb.Parent = StripContainer

		table.insert(stripImages, thumb)
	end
end

local function UpdatePreview()
	if not atlas then return end

	local a = atlas :: Supercorner.SupercornerAtlas
	local kp = a:GetKeypointFromAlpha(currentAlpha)

	ImageLabel.ImageContent = a:GetContent()
	ImageLabel.ImageRectOffset = kp.ImageRectOffset
	ImageLabel.ImageRectSize = kp.ImageRectSize
	ImageLabel.SliceCenter = kp.SliceCenter
	ImageLabel.SliceScale = kp.SliceScale

	local index = math.clamp(math.round(currentAlpha * (a:GetKeypointCount() - 1)) + 1, 1, a:GetKeypointCount())
	InfoLabel.Text = `Keypoint: {index}/{a:GetKeypointCount()} | Alpha: {string.format("%.2f", currentAlpha)} | Offset: {kp.ImageRectOffset} | Size: {kp.ImageRectSize}`
end

-- Slider helper
local function CreateSlider(
	name: string,
	min_val: number,
	max_val: number,
	initial: number,
	step: number,
	layout_order: number,
	on_changed: (number) -> ()
)
	local function round(v: number): number
		return math.round(v / step) * step
	end

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, SLIDER_HEIGHT)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layout_order
	container.Parent = Column

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(66, 61, 38)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s: %g", name, initial)
	label.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = Color3.fromRGB(235, 230, 215)
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 3)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((initial - min_val) / (max_val - min_val), 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 108, 70)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((initial - min_val) / (max_val - min_val), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(66, 61, 38)
	knob.BorderSizePixel = 0
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local dragging = false
	local lastValue = round(initial)

	local function updateFromX(absX: number)
		local trackPos = track.AbsolutePosition.X
		local trackSize = track.AbsoluteSize.X
		local t = math.clamp((absX - trackPos) / trackSize, 0, 1)
		local value = round(min_val + t * (max_val - min_val))
		t = math.clamp((value - min_val) / (max_val - min_val), 0, 1)
		knob.Position = UDim2.new(t, 0, 0.5, 0)
		fill.Size = UDim2.fromScale(t, 1)
		label.Text = string.format("%s: %g", name, value)

		if value == lastValue then return end

		lastValue = value
		on_changed(value)
	end

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- Sliders
CreateSlider("Alpha", 0, 1, 0, 0.01, 10, function(value)
	currentAlpha = value
	UpdatePreview()
end)

CreateSlider("Start Radius", 0, 100, StartRadius, 1, 11, function(value)
	StartRadius = value
	RebuildAtlas()
end)

CreateSlider("End Radius", 0, 100, EndRadius, 1, 12, function(value)
	EndRadius = value
	RebuildAtlas()
end)

CreateSlider("Start Smoothing", 0, 1, StartSmoothing, 0.01, 13, function(value)
	StartSmoothing = value
	RebuildAtlas()
end)

CreateSlider("End Smoothing", 0, 1, EndSmoothing, 0.01, 14, function(value)
	EndSmoothing = value
	RebuildAtlas()
end)

-- Initial render
RebuildAtlas()

print(`[atlas test] Atlas created with {KEYPOINTS} keypoints, cache size: {Supercorner.GetAtlasCacheSize()}`)
