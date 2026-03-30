local RepStorage = game:GetService("ReplicatedStorage")

local uicornerplus = require(RepStorage.uicornerplus)

local SIZE = 200

local screen_gui = Instance.new("ScreenGui")
screen_gui.Parent = game:GetService("StarterGui")

local image_label = Instance.new("ImageLabel")
image_label.Size = UDim2.fromOffset(SIZE, SIZE)
image_label.AnchorPoint = Vector2.new(0.5, 0.5)
image_label.Position = UDim2.fromScale(0.5, 0.5)
image_label.BackgroundTransparency = 1
image_label.Parent = screen_gui

local AssetService = game:GetService("AssetService")

local editable_image = AssetService:CreateEditableImage({
    Size = Vector2.new(SIZE * 2, SIZE * 2)
})

uicornerplus.draw_squircle({
	image = editable_image,
	-- We double the size so that
	-- high ddi screens look crisp.
	width = SIZE * 2,
	height = SIZE * 2,
	cornerRadius = 120,
	cornerSmoothing = 1,
	color = Color3.fromRGB(0, 0, 0),
})

image_label.ImageContent = Content.fromObject(editable_image)
