--!strict

local Fusion =
	require(script.Parent.Parent.Parent.Parent._Index["elttob_fusion@0.3.0"].fusion)
local Supercorner =
	require(script.Parent.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.1.0"].supercorner)

local Shared = require(script.Parent.shared)

local Peek, Children = Fusion.peek, Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
type Child = Fusion.Child

const ATLAS_KEYS = {
	Start = true, End = true, Keypoints = true, Alpha = true,
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

		return Shared.RenderFallback(scope, {
			topLeft = scope:Computed(function(use)
				return Lerp(startTL, endTL, use(props.Alpha) or 0)
			end),

			topRight = scope:Computed(function(use)
				return Lerp(startTR, endTR, use(props.Alpha) or 0)
			end),

			bottomRight = scope:Computed(function(use)
				return Lerp(startBR, endBR, use(props.Alpha) or 0)
			end),

			bottomLeft = scope:Computed(function(use)
				return Lerp(startBL, endBL, use(props.Alpha) or 0)
			end),
		}, passthroughProps, userChildren, {
			bgColor = props.BackgroundColor3,
			bgTransparency = props.BackgroundTransparency,
			strokeThickness = peekedStrokeThickness,
			strokeColor = props.StrokeColor,
			strokeTransparency = props.StrokeTransparency,
			strokeGradient = Peek(props.StrokeGradient),
		})
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
	UpdateFromAlpha(Peek(props.Alpha) or 0)

	-- Alpha observer (only if Alpha is a state object)
	if typeof(props.Alpha) == "table" then
		scope:Observer(props.Alpha):onChange(function()
			UpdateFromAlpha(Peek(props.Alpha) or 0)
		end)
	end

	-- Cleanup
	table.insert(scope, function()
		if fillAtlas then fillAtlas:Destroy(); fillAtlas = nil end
		if strokeAtlas then strokeAtlas:Destroy(); strokeAtlas = nil end
	end)

	-- Build instance tree
	local fillChild = scope:New("ImageLabel") {
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
	}

	local strokeChild: Instance? = nil

	if strokeAtlas then
		local strokeChildren: { [any]: any }? = nil

		if props.StrokeGradient ~= nil then
			strokeChildren = { StrokeGradient = props.StrokeGradient }
		end

		strokeChild = scope:New("ImageLabel") {
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
			[Children] = strokeChildren,
		}
	end

	local rootChildren: { any } = {
		fillChild,
		strokeChild,
	}

	if userChildren then
		table.insert(rootChildren, scope:New("Frame") {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
			[Children] = userChildren,
		})
	end

	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,
		[Children] = rootChildren,
	}

	for key, value in passthroughProps do
		rootProps[key] = value
	end

	return scope:New("Frame")(rootProps)
end

return AtlasFusion
