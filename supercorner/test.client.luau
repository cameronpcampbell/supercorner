--!strict

const RepStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const Players = game:GetService("Players")

const Supercorner = require(RepStorage.supercorner)

const STROKE_RADIUS = 0
const SIZE = 200
const SLIDER_HEIGHT = 40
const GAP = 80

const ScreenGui = Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = Players.LocalPlayer.PlayerGui

const Bg = Instance.new("Frame")
Bg.Size = UDim2.fromScale(1, 1)
Bg.BackgroundColor3 = Color3.fromRGB(255, 253, 240)
Bg.BorderSizePixel = 0
Bg.Parent = ScreenGui

const BgPadding = Instance.new("UIPadding")
BgPadding.PaddingTop = UDim.new(0, 100)
BgPadding.PaddingBottom = UDim.new(0, 100)
BgPadding.PaddingLeft = UDim.new(0, 100)
BgPadding.PaddingRight = UDim.new(0, 100)
BgPadding.Parent = Bg

const function CreateColumn(
    anchorX: number,
    positionX: UDim
): Frame
	const column = Instance.new("Frame")
	column.Size = UDim2.new(0, SIZE, 1, 0)
	column.AnchorPoint = Vector2.new(anchorX, 0)
	column.Position = UDim2.new(positionX, UDim.new())
	column.BackgroundTransparency = 1
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = Bg

	const layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 25)
	layout.Parent = column

	return column
end

-- Supercorner column (left)
const SupercornerColumn = CreateColumn(1, UDim.new(0.5, -GAP / 2))

const SupercornerTitle = Instance.new("TextLabel")
SupercornerTitle.Size = UDim2.new(1, 0, 0, 28)
SupercornerTitle.BackgroundTransparency = 1
SupercornerTitle.TextColor3 = Color3.fromRGB(66, 61, 38)
SupercornerTitle.TextSize = 20
SupercornerTitle.Font = Enum.Font.GothamBlack
SupercornerTitle.Text = "SuperCorner"
SupercornerTitle.LayoutOrder = 0
SupercornerTitle.Parent = SupercornerColumn

local ImageLabel = Instance.new("ImageLabel")
ImageLabel.Size = UDim2.fromOffset(SIZE, SIZE)
ImageLabel.BackgroundTransparency = 1
ImageLabel.LayoutOrder = 1
ImageLabel.Parent = SupercornerColumn

-- Native column (right)
const NativeColumn = CreateColumn(0, UDim.new(0.5, GAP / 2))

const NativeTitle = Instance.new("TextLabel")
NativeTitle.Size = UDim2.new(1, 0, 0, 28)
NativeTitle.BackgroundTransparency = 1
NativeTitle.TextColor3 = Color3.fromRGB(66, 61, 38)
NativeTitle.TextSize = 20
NativeTitle.Font = Enum.Font.GothamBlack
NativeTitle.Text = "UICorner"
NativeTitle.LayoutOrder = 0
NativeTitle.Parent = NativeColumn

const NativeFrame = Instance.new("Frame")
NativeFrame.Size = UDim2.fromOffset(SIZE, SIZE)
NativeFrame.BackgroundColor3 = Color3.fromRGB(120, 108, 70)
NativeFrame.BorderSizePixel = 0
NativeFrame.LayoutOrder = 1
NativeFrame.Parent = NativeColumn

const NativeCorner = Instance.new("UICorner")
NativeCorner.CornerRadius = UDim.new(0, 45)
NativeCorner.Parent = NativeFrame

-- State
local CornerRadius = 45
local CornerSmoothing = 1
local TopLeftRadius: number? = nil
local TopRightRadius: number? = nil
local BottomRightRadius: number? = nil
local BottomLeftRadius: number? = nil

const squircle = Supercorner.new({
	CornerRadius = CornerRadius,
	CornerSmoothing = CornerSmoothing,
	MaxTopLeftRadius = SIZE / 2,
	MaxTopRightRadius = SIZE / 2,
	MaxBottomRightRadius = SIZE / 2,
	MaxBottomLeftRadius = SIZE / 2,
	Redrawable = true,
	Stroke = if STROKE_RADIUS > 0 then STROKE_RADIUS else nil,
})

ImageLabel.ImageColor3 = Color3.fromRGB(120, 108, 70)
ImageLabel.ImageContent = squircle:GetContent()
ImageLabel.SliceCenter = squircle:GetSliceCenter()
ImageLabel.SliceScale = squircle:GetSliceScale()
ImageLabel.ScaleType = Enum.ScaleType.Slice

local function Redraw()
	squircle:Redraw({
		CornerRadius = CornerRadius,
		CornerSmoothing = CornerSmoothing,
		TopLeftRadius = TopLeftRadius,
		TopRightRadius = TopRightRadius,
		BottomRightRadius = BottomRightRadius,
		BottomLeftRadius = BottomLeftRadius,
		Stroke = if STROKE_RADIUS > 0 then STROKE_RADIUS else nil,
	})

	ImageLabel.ImageContent = squircle:GetContent()
	ImageLabel.SliceCenter = squircle:GetSliceCenter()
end

-- Slider system
type SliderSetValue = (value: number) -> ()

const function CreateSlider(
	name: string,
	min_val: number,
	max_val: number,
	initial: number,
	step: number,
	layout_order: number,
	parent: Frame,
	on_changed: (number) -> ()
): SliderSetValue
	const function round(v: number): number
		return math.round(v / step) * step
	end

	const container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, SLIDER_HEIGHT)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layout_order
	container.Parent = parent

	const label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(66, 61, 38)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s: %g", name, initial)
	label.Parent = container

	const track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = Color3.fromRGB(235, 230, 215)
	track.BorderSizePixel = 0
	track.Parent = container

	const track_corner = Instance.new("UICorner")
	track_corner.CornerRadius = UDim.new(0, 3)
	track_corner.Parent = track

	const fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((initial - min_val) / (max_val - min_val), 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 108, 70)
	fill.BorderSizePixel = 0
	fill.Parent = track

	const fill_corner = Instance.new("UICorner")
	fill_corner.CornerRadius = UDim.new(0, 3)
	fill_corner.Parent = fill

	const knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((initial - min_val) / (max_val - min_val), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(66, 61, 38)
	knob.BorderSizePixel = 0
	knob.Parent = track

	const knob_corner = Instance.new("UICorner")
	knob_corner.CornerRadius = UDim.new(1, 0)
	knob_corner.Parent = knob

	local dragging = false
	local last_value = round(initial)

	local function set_value(value: number)
		const rounded = round(value)
		const t = math.clamp((rounded - min_val) / (max_val - min_val), 0, 1)
		knob.Position = UDim2.new(t, 0, 0.5, 0)
		fill.Size = UDim2.fromScale(t, 1)
		label.Text = string.format("%s: %g", name, rounded)

		if rounded == last_value then
			return
		end

		last_value = rounded
		on_changed(rounded)
	end

	local function update_from_x(abs_x: number)
		const track_abs_pos = track.AbsolutePosition.X
		const track_abs_size = track.AbsoluteSize.X
		const t = math.clamp((abs_x - track_abs_pos) / track_abs_size, 0, 1)
		set_value(min_val + t * (max_val - min_val))
	end

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			update_from_x(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			update_from_x(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return set_value
end

-- Corner radius sync (shift-drag links all corner sliders)
const CornerSetters: { SliderSetValue } = {}
local Syncing = false

local function corner_changed(value: number, index: number)
	if index == 1 then TopLeftRadius = value

	elseif index == 2 then TopRightRadius = value

	elseif index == 3 then BottomRightRadius = value

	elseif index == 4 then BottomLeftRadius = value

	elseif index == 5 then NativeCorner.CornerRadius = UDim.new(0, value)
	end

	if not Syncing and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		Syncing = true

		for i, setter in CornerSetters do
			if i ~= index then
				setter(value)
			end
		end

		Syncing = false
	end

	if index ~= 5 then
		Redraw()
	end
end

-- Supercorner sliders
local SupercornerSliderOrder = 2

table.insert(CornerSetters, CreateSlider("Top Left Radius", 0, SIZE, CornerRadius, 1, SupercornerSliderOrder, SupercornerColumn, function(value)
	corner_changed(value, 1)
end))
SupercornerSliderOrder += 1

table.insert(CornerSetters, CreateSlider("Top Right Radius", 0, SIZE, CornerRadius, 1, SupercornerSliderOrder, SupercornerColumn, function(value)
	corner_changed(value, 2)
end))
SupercornerSliderOrder += 1

table.insert(CornerSetters, CreateSlider("Bottom Right Radius", 0, SIZE, CornerRadius, 1, SupercornerSliderOrder, SupercornerColumn, function(value)
	corner_changed(value, 3)
end))
SupercornerSliderOrder += 1

table.insert(CornerSetters, CreateSlider("Bottom Left Radius", 0, SIZE, CornerRadius, 1, SupercornerSliderOrder, SupercornerColumn, function(value)
	corner_changed(value, 4)
end))
SupercornerSliderOrder += 1

CreateSlider("Corner Smoothing", 0, 1, CornerSmoothing, 0.01, SupercornerSliderOrder, SupercornerColumn, function(value)
	CornerSmoothing = value
	Redraw()
end)

-- Native slider
table.insert(CornerSetters, CreateSlider("Corner Radius", 0, SIZE, CornerRadius, 1, 2, NativeColumn, function(value)
	corner_changed(value, 5)
end))
