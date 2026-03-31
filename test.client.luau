--!strict

local RepStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local supercorner = require(RepStorage.supercorner)

local SIZE = 200
local SLIDER_HEIGHT = 40
local GAP = 80

local screen_gui = Instance.new("ScreenGui")
screen_gui.IgnoreGuiInset = true
screen_gui.Parent = Players.LocalPlayer.PlayerGui

const background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(255, 253, 240)
background.BorderSizePixel = 0
background.Parent = screen_gui

const background_padding = Instance.new("UIPadding")
background_padding.PaddingTop = UDim.new(0, 100)
background_padding.PaddingBottom = UDim.new(0, 100)
background_padding.PaddingLeft = UDim.new(0, 100)
background_padding.PaddingRight = UDim.new(0, 100)
background_padding.Parent = background

-- Column container helper: vertically stacks a title, the preview, and sliders
local function create_column(anchor_x: number, position_x_scale: number, position_x_offset: number): Frame
	const column = Instance.new("Frame")
	column.Size = UDim2.new(0, SIZE, 1, 0)
	column.AnchorPoint = Vector2.new(anchor_x, 0)
	column.Position = UDim2.new(position_x_scale, position_x_offset, 0, 0)
	column.BackgroundTransparency = 1
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = background

	const layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 25)
	layout.Parent = column

	return column
end

-- Squircle column (left)
const squircle_column = create_column(1, 0.5, -GAP / 2)

const squircle_title = Instance.new("TextLabel")
squircle_title.Size = UDim2.new(1, 0, 0, 28)
squircle_title.BackgroundTransparency = 1
squircle_title.TextColor3 = Color3.fromRGB(66, 61, 38)
squircle_title.TextSize = 20
squircle_title.Font = Enum.Font.GothamBlack
squircle_title.Text = "SuperCorner"
squircle_title.LayoutOrder = 0
squircle_title.Parent = squircle_column

local image_label = Instance.new("ImageLabel")
image_label.Size = UDim2.fromOffset(SIZE, SIZE)
image_label.BackgroundTransparency = 1
image_label.LayoutOrder = 1
image_label.Parent = squircle_column

-- Native column (right)
const native_column = create_column(0, 0.5, GAP / 2)

const native_title = Instance.new("TextLabel")
native_title.Size = UDim2.new(1, 0, 0, 28)
native_title.BackgroundTransparency = 1
native_title.TextColor3 = Color3.fromRGB(66, 61, 38)
native_title.TextSize = 20
native_title.Font = Enum.Font.GothamBlack
native_title.Text = "UICorner"
native_title.LayoutOrder = 0
native_title.Parent = native_column

const native_frame = Instance.new("Frame")
native_frame.Size = UDim2.fromOffset(SIZE, SIZE)
native_frame.BackgroundColor3 = Color3.fromRGB(120, 108, 70)
native_frame.BorderSizePixel = 0
native_frame.LayoutOrder = 1
native_frame.Parent = native_column

const native_corner = Instance.new("UICorner")
native_corner.CornerRadius = UDim.new(0, 45)
native_corner.Parent = native_frame

-- State
local corner_radius = 45
local corner_smoothing = 1
local top_left_radius: number? = nil
local top_right_radius: number? = nil
local bottom_right_radius: number? = nil
local bottom_left_radius: number? = nil

const squircle = supercorner.create({
	width = SIZE,
	height = SIZE,
	cornerRadius = corner_radius,
	cornerSmoothing = corner_smoothing
})

image_label.ImageColor3 = Color3.fromRGB(120, 108, 70)
image_label.ImageContent = squircle:get_content()

local function redraw()
	squircle:redraw({
		cornerRadius = corner_radius,
		cornerSmoothing = corner_smoothing,
		topLeftCornerRadius = top_left_radius,
		topRightCornerRadius = top_right_radius,
		bottomRightCornerRadius = bottom_right_radius,
		bottomLeftCornerRadius = bottom_left_radius
	})

	image_label.ImageContent = squircle:get_content()
end

-- Slider system
type SliderSetValue = (value: number) -> ()

local function create_slider(
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
local corner_setters: { SliderSetValue } = {}
local syncing = false

local function corner_changed(value: number, index: number)
	if index == 1 then top_left_radius = value

	elseif index == 2 then top_right_radius = value

	elseif index == 3 then bottom_right_radius = value

	elseif index == 4 then bottom_left_radius = value

	elseif index == 5 then native_corner.CornerRadius = UDim.new(0, value)
	end

	if not syncing and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		syncing = true
		for i, setter in corner_setters do
			if i ~= index then
				setter(value)
			end
		end
		syncing = false
	end

	if index ~= 5 then
		redraw()
	end
end

-- Squircle sliders
local squircle_slider_order = 2

table.insert(corner_setters, create_slider("Top Left Corner Radius", 0, SIZE, corner_radius, 1, squircle_slider_order, squircle_column, function(value)
	corner_changed(value, 1)
end))
squircle_slider_order += 1

table.insert(corner_setters, create_slider("Top Right Corner Radius", 0, SIZE, corner_radius, 1, squircle_slider_order, squircle_column, function(value)
	corner_changed(value, 2)
end))
squircle_slider_order += 1

table.insert(corner_setters, create_slider("Bottom Right Corner Radius", 0, SIZE, corner_radius, 1, squircle_slider_order, squircle_column, function(value)
	corner_changed(value, 3)
end))
squircle_slider_order += 1

table.insert(corner_setters, create_slider("Bottom Left Corner Radius", 0, SIZE, corner_radius, 1, squircle_slider_order, squircle_column, function(value)
	corner_changed(value, 4)
end))

create_slider("Corner Smoothing", 0, 1, corner_smoothing, 0.01, squircle_slider_order, squircle_column, function(value)
	corner_smoothing = value
	redraw()
end)
squircle_slider_order += 1

-- Native slider
table.insert(corner_setters, create_slider("Corner Radius", 0, SIZE, corner_radius, 1, 2, native_column, function(value)
	corner_changed(value, 5)
end))
