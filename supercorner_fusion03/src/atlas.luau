--!strict

local Packages = script.Parent.Parent.roblox_packages
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek, Children = Fusion.peek, Fusion.Children

local Shared = require(script.Parent.shared)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
type Child = Fusion.Child

local ATLAS_KEYS = {
	Start = true, End = true, Keypoints = true, Alpha = true,
	Button = true,
	RootChildren = true,
	PreserveSmoothing = true, AntiAlias = true,
	StrokeThickness = true, StrokeColor = true,
	StrokeTransparency = true, StrokeGradient = true,
}

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function TryCreateAtlas(params: Supercorner.AtlasParams): Supercorner.SupercornerAtlas?
	local _ok, atlas = pcall(Supercorner.atlas, params)

	if not atlas then
		warn("[Supercorner Fusion] Failed to create atlas, possibly due to the editable memory budget being reached. Falling back to UICorner.")
	end

	return atlas
end

local function AtlasFusion(
	scope: Scope,
	props: {
		Start: Supercorner.CreateAtlasParams,
		End: Supercorner.CreateAtlasParams,
		Keypoints: number,
		Alpha: UsedAs<number>,
		Button: boolean?,
		RootChildren: Child?,
		PreserveSmoothing: boolean?,
		AntiAlias: boolean?,
		BackgroundColor3: UsedAs<Color3>?,
		BackgroundTransparency: UsedAs<number>?,
		StrokeThickness: number?,
		StrokeColor: UsedAs<Color3>?,
		StrokeTransparency: UsedAs<number>?,
		StrokeGradient: UsedAs<Instance>?,
		[any]: any,
	}
): Instance
	local passthroughProps = Shared.GetPassthroughProps(props, ATLAS_KEYS)
	local userChildren: Child? = props[Children]
	local userRootChildren: Child? = props.RootChildren
	local peekedStrokeThickness = props.StrokeThickness or 0

	-- Create atlases
	local fillAtlas = TryCreateAtlas({
		Start = props.Start,
		End = props.End,
		Keypoints = props.Keypoints,
		PreserveSmoothing = props.PreserveSmoothing,
		AntiAlias = props.AntiAlias,
	})

	local strokeAtlas: Supercorner.SupercornerAtlas? = nil

	if peekedStrokeThickness > 0 then
		strokeAtlas = TryCreateAtlas({
			Start = props.Start,
			End = props.End,
			Keypoints = props.Keypoints,
			PreserveSmoothing = props.PreserveSmoothing,
			AntiAlias = props.AntiAlias,
			Stroke = peekedStrokeThickness,
		})

		if not strokeAtlas and fillAtlas then
			fillAtlas:Destroy()
			fillAtlas = nil
		end
	end

	-- Fallback: interpolate radii from Start/End based on alpha
	if not fillAtlas then
		local startDefault = props.Start.CornerRadius or 0
		local endDefault = props.End.CornerRadius or 0
		local startTL = props.Start.TopLeftRadius or startDefault
		local startTR = props.Start.TopRightRadius or startDefault
		local startBR = props.Start.BottomRightRadius or startDefault
		local startBL = props.Start.BottomLeftRadius or startDefault
		local endTL = props.End.TopLeftRadius or endDefault
		local endTR = props.End.TopRightRadius or endDefault
		local endBR = props.End.BottomRightRadius or endDefault
		local endBL = props.End.BottomLeftRadius or endDefault
		local strokeGradient: Instance? = nil

		if props.StrokeGradient ~= nil then
			strokeGradient = Peek<<Instance>>(props.StrokeGradient) :: Instance
		end

		return Shared.RenderFallback(scope, {
			topLeft = scope:Computed(function(use: Fusion.Use): number
				return Lerp(startTL, endTL, use<<number>>(props.Alpha) :: number)
			end),

			topRight = scope:Computed(function(use: Fusion.Use): number
				return Lerp(startTR, endTR, use<<number>>(props.Alpha) :: number)
			end),

			bottomRight = scope:Computed(function(use: Fusion.Use): number
				return Lerp(startBR, endBR, use<<number>>(props.Alpha) :: number)
			end),

			bottomLeft = scope:Computed(function(use: Fusion.Use): number
				return Lerp(startBL, endBL, use<<number>>(props.Alpha) :: number)
			end),
		}, passthroughProps, userChildren, {
			bgColor = props.BackgroundColor3,
			bgTransparency = props.BackgroundTransparency,
			strokeThickness = peekedStrokeThickness,
			strokeColor = props.StrokeColor,
			strokeTransparency = props.StrokeTransparency,
			strokeGradient = strokeGradient,
		}, props.Button, userRootChildren)
	end

	-- State values for fill keypoint
	local fillImageRectOffsetState = scope:Value(Vector2.zero)
	local fillImageRectSizeState = scope:Value(Vector2.zero)
	local fillSliceCenterState = scope:Value(Rect.new(0, 0, 0, 0))
	local fillSliceScaleState = scope:Value(0.5 :: number)

	-- State values for stroke keypoint
	local strokeImageRectOffsetState = scope:Value(Vector2.zero)
	local strokeImageRectSizeState = scope:Value(Vector2.zero)
	local strokeSliceCenterState = scope:Value(Rect.new(0, 0, 0, 0))
	local strokeSliceScaleState = scope:Value(0.5 :: number)

	-- Content is constant per atlas
	local fillContent = fillAtlas:GetContent()
	local strokeContent = if strokeAtlas then strokeAtlas:GetContent() else nil

	-- Update keypoint state from alpha
	local function UpdateFromAlpha(alpha: number)
		if fillAtlas then
			local kp = fillAtlas:GetKeypointFromAlpha(alpha)
			fillImageRectOffsetState:set(kp.ImageRectOffset)
			fillImageRectSizeState:set(kp.ImageRectSize)
			fillSliceCenterState:set(kp.SliceCenter)
			fillSliceScaleState:set(kp.SliceScale)
		end

		if strokeAtlas then
			local kp = strokeAtlas:GetKeypointFromAlpha(alpha)
			strokeImageRectOffsetState:set(kp.ImageRectOffset)
			strokeImageRectSizeState:set(kp.ImageRectSize)
			strokeSliceCenterState:set(kp.SliceCenter)
			strokeSliceScaleState:set(kp.SliceScale)
		end
	end

	-- Initial update
	UpdateFromAlpha(Peek<<number>>(props.Alpha) :: number)

	-- Alpha observer (only if Alpha is a state object)
	if typeof(props.Alpha) == "table" then
		scope:Observer(props.Alpha):onChange(function()
			UpdateFromAlpha(Peek<<number>>(props.Alpha) :: number)
		end)
	end

	-- Cleanup
	table.insert(scope, function()
		if fillAtlas then fillAtlas:Destroy(); fillAtlas = nil end
		if strokeAtlas then strokeAtlas:Destroy(); strokeAtlas = nil end
	end)

	-- Build instance tree
	local fillChild = scope:New("ImageLabel") {
		Name = "Fill",
		ImageContent = fillContent,
		ImageRectOffset = fillImageRectOffsetState,
		ImageRectSize = fillImageRectSizeState,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = fillSliceCenterState,
		SliceScale = fillSliceScaleState,
		BackgroundTransparency = 1,
		ImageColor3 = props.BackgroundColor3,
		ImageTransparency = props.BackgroundTransparency,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
	}

	local strokeChild: Instance? = nil

	if strokeAtlas then
		local strokeChildren: { [any]: any }? = nil

		if props.StrokeGradient ~= nil then
			strokeChildren = { StrokeGradient = props.StrokeGradient }
		end

		strokeChild = scope:New("ImageLabel") {
			Name = "Stroke",
			ImageContent = strokeContent,
			ImageRectOffset = strokeImageRectOffsetState,
			ImageRectSize = strokeImageRectSizeState,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = strokeSliceCenterState,
			SliceScale = strokeSliceScaleState,
			BackgroundTransparency = 1,
			ImageColor3 = props.StrokeColor,
			ImageTransparency = props.StrokeTransparency,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 3,
			[Children] = strokeChildren,
		}
	end

	local imageFolder = scope:New("Folder") {
		Name = "SupercornerImages",

		[Children] = ({
			fillChild,
			strokeChild,
		} :: { [any]: any }),
	}

	local contentFrame = Shared.CreateContentFrame(scope, userChildren)

	local rootChildren: { [any]: any } = {
		imageFolder,
		contentFrame,
		[Children] = userRootChildren,
	}

	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,
		[Children] = rootChildren,
	}

	for key, value in passthroughProps do
		rootProps[key] = value
	end

	return Shared.RenderRoot(scope, props.Button, "Frame", rootProps)
end

return AtlasFusion
