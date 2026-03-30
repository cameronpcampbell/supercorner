--!strict

local RepStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local uicornerplus = require(RepStorage.uicornerplus)

local SIZE = 200

local screen_gui = Instance.new("ScreenGui")
screen_gui.Parent = Players.LocalPlayer.PlayerGui

local image_label = Instance.new("ImageLabel")
image_label.Size = UDim2.fromOffset(SIZE, SIZE)
image_label.AnchorPoint = Vector2.new(0.5, 0.5)
image_label.Position = UDim2.fromScale(0.5, 0.5)
image_label.BackgroundTransparency = 1
image_label.Parent = screen_gui

local corner_radius = 100
local corner_smoothing = 1

local squircle = uicornerplus.create({
	width = SIZE * 2,
	height = SIZE * 2,
	cornerRadius = corner_radius,
	cornerSmoothing = corner_smoothing,
	color = Color3.fromRGB(0, 0, 0),
})

image_label.ImageContent = squircle:get_content()

local function redraw()
	squircle:redraw({
		cornerRadius = corner_radius,
		cornerSmoothing = corner_smoothing,
		color = Color3.fromRGB(0, 0, 0),
	})

	image_label.ImageContent = squircle:get_content()
end

local function create_slider(
	name: string,
	min_val: number,
	max_val: number,
	initial: number,
	position: UDim2,
	on_changed: (number) -> ()
)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(300, 40)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = position
	container.BackgroundTransparency = 1
	container.Parent = screen_gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Font = Enum.Font.GothamMedium
	label.Text = string.format("%s: %.2f", name, initial)
	label.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	track.BorderSizePixel = 0
	track.Parent = container

	local track_corner = Instance.new("UICorner")
	track_corner.CornerRadius = UDim.new(0, 3)
	track_corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((initial - min_val) / (max_val - min_val), 1)
	fill.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fill_corner = Instance.new("UICorner")
	fill_corner.CornerRadius = UDim.new(0, 3)
	fill_corner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((initial - min_val) / (max_val - min_val), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track

	local knob_corner = Instance.new("UICorner")
	knob_corner.CornerRadius = UDim.new(1, 0)
	knob_corner.Parent = knob

	local dragging = false

	local function update_from_x(abs_x: number)
		local track_abs_pos = track.AbsolutePosition.X
		local track_abs_size = track.AbsoluteSize.X
		local t = math.clamp((abs_x - track_abs_pos) / track_abs_size, 0, 1)
		local value = min_val + t * (max_val - min_val)

		knob.Position = UDim2.new(t, 0, 0.5, 0)
		fill.Size = UDim2.fromScale(t, 1)
		label.Text = string.format("%s: %.2f", name, value)
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
end

create_slider("Corner Radius", 0, SIZE, corner_radius, UDim2.new(0.5, 0, 1, -50), function(value)
	corner_radius = value
	redraw()
end)

create_slider("Corner Smoothing", 0, 1, corner_smoothing, UDim2.new(0.5, 0, 1, -5), function(value)
	corner_smoothing = value
	redraw()
end)
