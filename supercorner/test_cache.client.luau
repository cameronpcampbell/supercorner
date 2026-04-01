--!strict

const RepStorage = game:GetService("ReplicatedStorage")
const Players = game:GetService("Players")

const Supercorner = require(RepStorage.supercorner)

const GRID_COLS = 4
const GRID_ROWS = 4
const CELL_SIZE = 100
const GAP = 10
const CORNER_RADIUS = 25
const CORNER_SMOOTHING = 1.

const ScreenGui = Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = Players.LocalPlayer.PlayerGui

const Bg = Instance.new("Frame")
Bg.Size = UDim2.fromScale(1, 1)
Bg.BackgroundColor3 = Color3.fromRGB(255, 253, 240)
Bg.BorderSizePixel = 0
Bg.Parent = ScreenGui

const StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 40)
StatusLabel.Position = UDim2.new(0, 0, 0, 20)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(66, 61, 38)
StatusLabel.TextSize = 18
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.Parent = ScreenGui

const GridContainer = Instance.new("Frame")
GridContainer.Size = UDim2.fromOffset(
	GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * GAP,
	GRID_ROWS * CELL_SIZE + (GRID_ROWS - 1) * GAP
)
GridContainer.AnchorPoint = Vector2.new(0.5, 0.5)
GridContainer.Position = UDim2.fromScale(0.5, 0.5)
GridContainer.BackgroundTransparency = 1
GridContainer.Parent = Bg

const GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE)
GridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
GridLayout.Parent = GridContainer

local squircles: { Supercorner.Squircle } = {}
local imageLabels: { ImageLabel } = {}
local contents: { Content } = {}

for i = 1, GRID_COLS * GRID_ROWS do
	local squircle = Supercorner.new({
		Width = CELL_SIZE,
		Height = CELL_SIZE,
		CornerRadius = CORNER_RADIUS,
		CornerSmoothing = CORNER_SMOOTHING,
		Redrawable = i == 1,
	})

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.BackgroundTransparency = 1
	imageLabel.ImageColor3 = Color3.fromRGB(120, 108, 70)
	imageLabel.ImageContent = squircle:GetContent()
	imageLabel.LayoutOrder = i
	imageLabel.Parent = GridContainer

	table.insert(squircles, squircle)
	table.insert(imageLabels, imageLabel)
	table.insert(contents, squircle:GetContent())
end

-- Verify static instances share the same Content (indices 2+)
local allStaticShared = true
local firstStaticContent = contents[2]

for i = 3, #contents do
	if contents[i] ~= firstStaticContent then
		allStaticShared = false
		break
	end
end

local count = GRID_COLS * GRID_ROWS
local allShared = allStaticShared

local cacheSize = Supercorner.GetCacheSize()
local staticCacheSize = Supercorner.GetStaticCacheSize()

if allShared then
	StatusLabel.Text = `PASS: {count} squircles sharing 1 entry (editable: {cacheSize}, static: {staticCacheSize})`
	StatusLabel.TextColor3 = Color3.fromRGB(46, 139, 87)

else
	StatusLabel.Text = `FAIL: squircles are NOT sharing the same entry (editable: {cacheSize}, static: {staticCacheSize})`
	StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
end

print(`[cache test] {count} squircles created, editable cache: {cacheSize}, static cache: {staticCacheSize}`)

-- Animate the first squircle's corner radius down to 0
local radius = CORNER_RADIUS

while radius > 0 do
	radius = math.max(0, radius - 1)

	squircles[1]:Redraw({
		CornerRadius = radius,
		CornerSmoothing = CORNER_SMOOTHING,
	})

	imageLabels[1].ImageContent = squircles[1]:GetContent()
	task.wait(0.05)
end

print(`[cache test] first squircle redraw complete, editable cache: {Supercorner.GetCacheSize()}, static cache: {Supercorner.GetStaticCacheSize()}`)
