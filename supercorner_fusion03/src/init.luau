--!strict

local Fusion =
	require(script.Parent.Parent.Parent._Index["elttob_fusion@0.3.0"].fusion)
local Supercorner =
	require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.1.0"].supercorner)

local Shared = require(script.shared)
local AtlasFusion = require(script.atlas)

local Peek, Children = Fusion.peek, Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
type Child = Fusion.Child

const CREATE_ONLY_PROPS = { "MaxCornerRadius", "MaxTopLeftRadius", "MaxTopRightRadius", "MaxBottomRightRadius", "MaxBottomLeftRadius", "Redrawable" }

const SUPERCORNER_KEYS = {
	CornerRadius = true, CornerSmoothing = true,
	TopLeftRadius = true, TopRightRadius = true,
	BottomRightRadius = true, BottomLeftRadius = true,
	MaxCornerRadius = true, MaxTopLeftRadius = true,
	MaxTopRightRadius = true, MaxBottomRightRadius = true,
	MaxBottomLeftRadius = true, PreserveSmoothing = true,
	AntiAlias = true, Redrawable = true,
	StrokeThickness = true, StrokeColor = true,
	StrokeTransparency = true, StrokeGradient = true,
}

local function TryCreateSupercorner(props: { [any]: any }, stroke: number): Supercorner.Supercorner?
	local _ok, supercorner = pcall(Supercorner.new, {
		CornerRadius = Peek(props.CornerRadius),
		CornerSmoothing = Peek(props.CornerSmoothing),
		TopLeftRadius = Peek(props.TopLeftRadius),
		TopRightRadius = Peek(props.TopRightRadius),
		BottomRightRadius = Peek(props.BottomRightRadius),
		BottomLeftRadius = Peek(props.BottomLeftRadius),
		MaxCornerRadius = Peek(props.MaxCornerRadius),
		MaxTopLeftRadius = Peek(props.MaxTopLeftRadius),
		MaxTopRightRadius = Peek(props.MaxTopRightRadius),
		MaxBottomRightRadius = Peek(props.MaxBottomRightRadius),
		MaxBottomLeftRadius = Peek(props.MaxBottomLeftRadius),
		PreserveSmoothing = Peek(props.PreserveSmoothing),
		AntiAlias = Peek(props.AntiAlias),
		Redrawable = Peek(props.Redrawable),
		Stroke = stroke,
	})

	if not supercorner then
		warn("[Supercorner Fusion] Failed to create Supercorner, possibly due to the editable memory budget being reached. Falling back to UICorner.")
	end

	return supercorner
end

local function UpdateSupercornerValues(
	sc: Supercorner.Supercorner,
	contentState: Fusion.Value<Content?>,
	sliceCenterState: Fusion.Value<Rect?>,
	sliceScaleState: Fusion.Value<number?>
)
	contentState:set(sc:GetContent())
	sliceCenterState:set(sc:GetSliceCenter())
	sliceScaleState:set(sc:GetSliceScale())
end

local function SupercornerFusion(
	scope: Scope,
	props: {
		CornerRadius: UsedAs<number>?,
		CornerSmoothing: UsedAs<number>?,
		TopLeftRadius: UsedAs<number>?,
		TopRightRadius: UsedAs<number>?,
		BottomRightRadius: UsedAs<number>?,
		BottomLeftRadius: UsedAs<number>?,
		MaxCornerRadius: UsedAs<number>?,
		MaxTopLeftRadius: UsedAs<number>?,
		MaxTopRightRadius: UsedAs<number>?,
		MaxBottomRightRadius: UsedAs<number>?,
		MaxBottomLeftRadius: UsedAs<number>?,
		PreserveSmoothing: UsedAs<boolean>?,
		AntiAlias: UsedAs<boolean>?,
		Redrawable: UsedAs<boolean>?,
		BackgroundColor3: UsedAs<Color3>?,
		BackgroundTransparency: UsedAs<number>?,
		StrokeThickness: UsedAs<number>?,
		StrokeColor: UsedAs<Color3>?,
		StrokeTransparency: UsedAs<number>?,
		StrokeGradient: UsedAs<Instance>?,
		[any]: any,
	}
): Instance
	local passthroughProps = Shared.GetPassthroughProps(props, SUPERCORNER_KEYS)
	local userChildren: Child? = props[Children]

	-- Warn if create-only props change
	for _, propName in CREATE_ONLY_PROPS do
		local propValue = props[propName]

		if propValue == nil then continue end
		if typeof(propValue) ~= "table" then continue end

		local initial = Peek(propValue)

		scope:Observer(propValue):onChange(function()
			if Peek(propValue) ~= initial then
				warn(`[Supercorner Fusion] '{propName}' cannot be updated after creation.`)
			end
		end)
	end

	-- Derived state
	local computeNeedsFill = scope:Computed(function(use)
		return (use(props.BackgroundTransparency) or 0) ~= 1
	end)

	local computeNeedsStroke = scope:Computed(function(use)
		return (use(props.StrokeThickness) or 0) > 0
	end)

	local computeGeometry = scope:Computed(function(use)
		return {
			CornerRadius = use(props.CornerRadius),
			CornerSmoothing = use(props.CornerSmoothing),
			TopLeftRadius = use(props.TopLeftRadius),
			TopRightRadius = use(props.TopRightRadius),
			BottomRightRadius = use(props.BottomRightRadius),
			BottomLeftRadius = use(props.BottomLeftRadius),
			PreserveSmoothing = use(props.PreserveSmoothing),
			AntiAlias = use(props.AntiAlias),
			StrokeThickness = use(props.StrokeThickness),
		}
	end)

	-- Supercorner instance state
	local fillContentState = scope:Value(nil :: Content?)
	local fillSliceCenterState = scope:Value(nil :: Rect?)
	local fillSliceScaleState = scope:Value(nil :: number?)

	local strokeContentState = scope:Value(nil :: Content?)
	local strokeSliceCenterState = scope:Value(nil :: Rect?)
	local strokeSliceScaleState = scope:Value(nil :: number?)

	local fillSC: Supercorner.Supercorner? = nil
	local strokeSC: Supercorner.Supercorner? = nil

	-- Initial creation
	local useFallback = false

	if Peek(computeNeedsFill) then
		fillSC = TryCreateSupercorner(props, 0)

		if fillSC then
			UpdateSupercornerValues(fillSC, fillContentState, fillSliceCenterState, fillSliceScaleState)
		else
			useFallback = true
		end
	end

	if Peek(computeNeedsStroke) and not useFallback then
		local peekedStrokeThickness = Peek(props.StrokeThickness) or 0
		strokeSC = TryCreateSupercorner(props, peekedStrokeThickness)

		if strokeSC then
			UpdateSupercornerValues(strokeSC, strokeContentState, strokeSliceCenterState, strokeSliceScaleState)
		else
			useFallback = true

			if fillSC then
				fillSC:Destroy()
				fillSC = nil
			end
		end
	end

	if useFallback then
		local defaultRadius = scope:Computed(function(use)
			return use(props.CornerRadius) or 0
		end)

		return Shared.RenderFallback(scope, {
			topLeft = scope:Computed(function(use)
				return use(props.TopLeftRadius) or use(defaultRadius)
			end),

			topRight = scope:Computed(function(use)
				return use(props.TopRightRadius) or use(defaultRadius)
			end),

			bottomRight = scope:Computed(function(use)
				return use(props.BottomRightRadius) or use(defaultRadius)
			end),

			bottomLeft = scope:Computed(function(use)
				return use(props.BottomLeftRadius) or use(defaultRadius)
			end),
		}, passthroughProps, userChildren, {
			bgColor = props.BackgroundColor3,
			bgTransparency = props.BackgroundTransparency,
			strokeThickness = props.StrokeThickness,
			strokeColor = props.StrokeColor,
			strokeTransparency = props.StrokeTransparency,
			strokeGradient = Peek(props.StrokeGradient),
		})
	end

	-- Geometry change observer — redraw on prop changes
	scope:Observer(computeGeometry):onChange(function()
		local geo = Peek(computeGeometry)

		if fillSC then
			local ok, err = (pcall :: any)(fillSC.Redraw, fillSC, {
				CornerRadius = geo.CornerRadius,
				CornerSmoothing = geo.CornerSmoothing,
				TopLeftRadius = geo.TopLeftRadius,
				TopRightRadius = geo.TopRightRadius,
				BottomRightRadius = geo.BottomRightRadius,
				BottomLeftRadius = geo.BottomLeftRadius,
				PreserveSmoothing = geo.PreserveSmoothing,
				AntiAlias = geo.AntiAlias,
			})

			if ok then
				UpdateSupercornerValues(fillSC, fillContentState, fillSliceCenterState, fillSliceScaleState)
			else
				warn(`[Supercorner Fusion] Failed to redraw Supercorner. Make sure the component was created with \`Redrawable = true\`. Error: {err}`)
			end
		end

		if strokeSC then
			local ok, err = (pcall :: any)(strokeSC.Redraw, strokeSC, {
				CornerRadius = geo.CornerRadius,
				CornerSmoothing = geo.CornerSmoothing,
				TopLeftRadius = geo.TopLeftRadius,
				TopRightRadius = geo.TopRightRadius,
				BottomRightRadius = geo.BottomRightRadius,
				BottomLeftRadius = geo.BottomLeftRadius,
				PreserveSmoothing = geo.PreserveSmoothing,
				AntiAlias = geo.AntiAlias,
				Stroke = geo.StrokeThickness,
			})

			if ok then
				UpdateSupercornerValues(strokeSC, strokeContentState, strokeSliceCenterState, strokeSliceScaleState)
			else
				warn(`[Supercorner Fusion] Failed to redraw stroke Supercorner. Make sure the component was created with \`Redrawable = true\`. Error: {err}`)
			end
		end
	end)

	-- Fill toggle observer
	scope:Observer(computeNeedsFill):onChange(function()
		local peekedNeedsFill = Peek(computeNeedsFill)

		if peekedNeedsFill and not fillSC then
			fillSC = TryCreateSupercorner(props, 0)

			if fillSC then
				UpdateSupercornerValues(fillSC, fillContentState, fillSliceCenterState, fillSliceScaleState)
			end

		elseif not peekedNeedsFill and fillSC then
			fillSC:Destroy()
			fillSC = nil
			fillContentState:set(nil)
			fillSliceCenterState:set(nil)
			fillSliceScaleState:set(nil)
		end
	end)

	-- Stroke toggle observer
	scope:Observer(computeNeedsStroke):onChange(function()
		local peekedNeedsStroke = Peek(computeNeedsStroke)

		if peekedNeedsStroke and not strokeSC then
			local peekedStrokeThickness = Peek(props.StrokeThickness) or 0
			strokeSC = TryCreateSupercorner(props, peekedStrokeThickness)

			if strokeSC then
				UpdateSupercornerValues(strokeSC, strokeContentState, strokeSliceCenterState, strokeSliceScaleState)
			end

		elseif not peekedNeedsStroke and strokeSC then
			strokeSC:Destroy()
			strokeSC = nil
			strokeContentState:set(nil)
			strokeSliceCenterState:set(nil)
			strokeSliceScaleState:set(nil)
		end
	end)

	-- Cleanup
	table.insert(scope, function()
		if fillSC then fillSC:Destroy(); fillSC = nil end
		if strokeSC then strokeSC:Destroy(); strokeSC = nil end
	end)

	-- Build instance tree
	local computeFillChild = scope:Computed(function(use, innerScope: Fusion.Scope): Instance?
		local usedContent = use(fillContentState)
		if usedContent == nil then return nil end

		return innerScope:New("ImageLabel") {
			ImageContent = fillContentState,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = fillSliceCenterState,
			SliceScale = fillSliceScaleState,
			BackgroundTransparency = 1,
			ImageColor3 = props.BackgroundColor3,
			ImageTransparency = props.BackgroundTransparency,
			Size = UDim2.new(1, 0, 1, 0),
		}
	end)

	local computeStrokeChild = scope:Computed(function(use, innerScope: Fusion.Scope): Instance?
		local usedContent = use(strokeContentState)
		if usedContent == nil then return nil end

		local strokeChildren: { [any]: any }? = nil

		if props.StrokeGradient ~= nil then
			strokeChildren = { StrokeGradient = props.StrokeGradient }
		end

		return innerScope:New("ImageLabel") {
			ImageContent = strokeContentState,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = strokeSliceCenterState,
			SliceScale = strokeSliceScaleState,
			BackgroundTransparency = 1,
			ImageColor3 = props.StrokeColor,
			ImageTransparency = props.StrokeTransparency,
			Size = UDim2.new(1, 0, 1, 0),
			[Children] = strokeChildren,
		}
	end)

	local rootChildren: { any } = {
		computeFillChild,
		computeStrokeChild,
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

return {
	new = SupercornerFusion,
	atlas = AtlasFusion,
}
