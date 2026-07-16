--!strict

local Packages = script.Parent.roblox_packages
local Supercorner = require(Packages.supercorner)
local Fusion = require(Packages.fusion)
local Peek, Children = Fusion.peek, Fusion.Children

local Shared = require(script.shared)
local AtlasFusion = require(script.atlas)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
type Child = Fusion.Child
type ShapeGeometry = {
	CornerRadius: number?,
	CornerSmoothing: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
}

local CREATE_ONLY_PROPS = { "MaxCornerRadius", "MaxTopLeftRadius", "MaxTopRightRadius", "MaxBottomRightRadius", "MaxBottomLeftRadius", "Redrawable" }
local REDRAW_PROPS = {
	"CornerRadius", "CornerSmoothing",
	"TopLeftRadius", "TopRightRadius", "BottomRightRadius", "BottomLeftRadius",
	"PreserveSmoothing", "AntiAlias", "StrokeThickness",
}

local SUPERCORNER_KEYS = {
	CornerRadius = true, CornerSmoothing = true,
	TopLeftRadius = true, TopRightRadius = true,
	BottomRightRadius = true, BottomLeftRadius = true,
	MaxCornerRadius = true, MaxTopLeftRadius = true,
	MaxTopRightRadius = true, MaxBottomRightRadius = true,
	MaxBottomLeftRadius = true, PreserveSmoothing = true,
	AntiAlias = true, Redrawable = true,
	ForceSupercorner = true,
	Button = true,
	RootChildren = true,
	StrokeThickness = true, StrokeColor = true,
	StrokeTransparency = true, StrokeGradient = true,
}

local function TryCreateSupercorner(props: { [any]: any }, stroke: number): Supercorner.Supercorner?
	local ok, result = (pcall :: any)(Supercorner.new, {
		CornerRadius = Peek<<number?>>(props.CornerRadius),
		CornerSmoothing = Peek<<number?>>(props.CornerSmoothing),
		TopLeftRadius = Peek<<number?>>(props.TopLeftRadius),
		TopRightRadius = Peek<<number?>>(props.TopRightRadius),
		BottomRightRadius = Peek<<number?>>(props.BottomRightRadius),
		BottomLeftRadius = Peek<<number?>>(props.BottomLeftRadius),
		MaxCornerRadius = Peek<<number?>>(props.MaxCornerRadius),
		MaxTopLeftRadius = Peek<<number?>>(props.MaxTopLeftRadius),
		MaxTopRightRadius = Peek<<number?>>(props.MaxTopRightRadius),
		MaxBottomRightRadius = Peek<<number?>>(props.MaxBottomRightRadius),
		MaxBottomLeftRadius = Peek<<number?>>(props.MaxBottomLeftRadius),
		PreserveSmoothing = Peek<<boolean?>>(props.PreserveSmoothing),
		AntiAlias = Peek<<boolean?>>(props.AntiAlias),
		Redrawable = Peek<<boolean?>>(props.Redrawable),
		Stroke = stroke,
	})

	if not ok then
		warn(`[Supercorner Fusion] Failed to create Supercorner. Falling back to UICorner. Error: {result}`)
		return nil
	end

	return result :: Supercorner.Supercorner
end

local function UpdateSupercornerValues(
	sc: Supercorner.Supercorner,
	contentState: Fusion.Value<Content>,
	sliceCenterState: Fusion.Value<Rect>,
	sliceScaleState: Fusion.Value<number>,
	hasContentState: Fusion.Value<boolean>
)
	sliceCenterState:set(sc:GetSliceCenter())
	sliceScaleState:set(sc:GetSliceScale())
	contentState:set(sc:GetContent())
	hasContentState:set(true)
end

local function ClearSupercornerValues(
	contentState: Fusion.Value<Content>,
	hasContentState: Fusion.Value<boolean>
)
	hasContentState:set(false)
	contentState:set(Content.none)
end

local function HasZeroCornerRadii(props: { [any]: any }): boolean
	local defaultRadius = Peek<<number>>(props.CornerRadius or 0) :: number

	return
		(Peek<<number>>(props.TopLeftRadius or defaultRadius) :: number) == 0
		and (Peek<<number>>(props.TopRightRadius or defaultRadius) :: number) == 0
		and (Peek<<number>>(props.BottomRightRadius or defaultRadius) :: number) == 0
		and (Peek<<number>>(props.BottomLeftRadius or defaultRadius) :: number) == 0
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
		ForceSupercorner: boolean?,
		Button: boolean?,
		RootChildren: Child?,
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
	local userChildren: Child? = Shared.GetChildren(props)
	local userRootChildren: Child? = props.RootChildren

	-- Warn if create-only props change
	for _, propName in CREATE_ONLY_PROPS do
		local propValue = props[propName]

		if propValue == nil then continue end
		if typeof(propValue) ~= "table" then continue end

		local initial = Peek<<number | boolean>>(propValue)

		scope:Observer(propValue):onChange(function()
			if Peek<<number | boolean>>(propValue) ~= initial then
				warn(`[Supercorner Fusion] '{propName}' cannot be updated after creation.`)
			end
		end)
	end

	local isRedrawable = Peek<<boolean>>(props.Redrawable or false) :: boolean
	local forceSupercorner = props.ForceSupercorner == true
	local useSquareFill =
		not forceSupercorner
		and not isRedrawable
		and HasZeroCornerRadii(props)
	local reactiveRedrawProp: string? = nil

	for _, propName in REDRAW_PROPS do
		if typeof(props[propName]) == "table" then
			reactiveRedrawProp = propName
			break
		end
	end

	if reactiveRedrawProp ~= nil and not isRedrawable then
		warn(
			`[Supercorner Fusion] '{reactiveRedrawProp}' is reactive, but this component is not redrawable. `
				.. "Pass `Redrawable = true` and configure the maximum corner radii to apply reactive geometry updates."
		)
	end

	-- Derived state
	local computeNeedsFill = scope:Computed(function(use: Fusion.Use): boolean
		return (use<<number>>(props.BackgroundTransparency or 0) :: number) ~= 1
	end)

	local computeStrokeThickness = scope:Computed(function(use: Fusion.Use): number
		return use<<number>>(props.StrokeThickness or 0) :: number
	end)

	local computeNeedsStroke = scope:Computed(function(use: Fusion.Use): boolean
		return (use<<number>>(computeStrokeThickness) :: number) > 0
	end)

	local computeShapeGeometry = scope:Computed(function(use: Fusion.Use): ShapeGeometry
		return {
			CornerRadius = if props.CornerRadius == nil then nil else (use<<number>>(props.CornerRadius) :: number),
			CornerSmoothing = if props.CornerSmoothing == nil then nil else (use<<number>>(props.CornerSmoothing) :: number),
			TopLeftRadius = if props.TopLeftRadius == nil then nil else (use<<number>>(props.TopLeftRadius) :: number),
			TopRightRadius = if props.TopRightRadius == nil then nil else (use<<number>>(props.TopRightRadius) :: number),
			BottomRightRadius = if props.BottomRightRadius == nil then nil else (use<<number>>(props.BottomRightRadius) :: number),
			BottomLeftRadius = if props.BottomLeftRadius == nil then nil else (use<<number>>(props.BottomLeftRadius) :: number),
			PreserveSmoothing = if props.PreserveSmoothing == nil then nil else (use<<boolean>>(props.PreserveSmoothing) :: boolean),
			AntiAlias = if props.AntiAlias == nil then nil else (use<<boolean>>(props.AntiAlias) :: boolean),
		}
	end)

	-- Supercorner instance state
	local fillContentState = scope:Value(Content.none)
	local fillSliceCenterState = scope:Value(Rect.new(0, 0, 0, 0))
	local fillSliceScaleState = scope:Value(0.5)
	local fillHasContentState = scope:Value(false)

	local strokeContentState = scope:Value(Content.none)
	local strokeSliceCenterState = scope:Value(Rect.new(0, 0, 0, 0))
	local strokeSliceScaleState = scope:Value(0.5)
	local strokeHasContentState = scope:Value(false)

	local fillSC: Supercorner.Supercorner? = nil
	local strokeSC: Supercorner.Supercorner? = nil

	-- Initial creation
	local useFallback = false

	if not useSquareFill and (Peek<<boolean>>(computeNeedsFill) :: boolean) then
		fillSC = TryCreateSupercorner(props, 0)

		if fillSC then
			UpdateSupercornerValues(fillSC, fillContentState, fillSliceCenterState, fillSliceScaleState, fillHasContentState)
		else
			useFallback = true
		end
	end

	if (Peek<<boolean>>(computeNeedsStroke) :: boolean) and not useFallback then
		local peekedStrokeThickness = Peek<<number>>(props.StrokeThickness or 0) :: number
		strokeSC = TryCreateSupercorner(props, peekedStrokeThickness)

		if strokeSC then
			UpdateSupercornerValues(strokeSC, strokeContentState, strokeSliceCenterState, strokeSliceScaleState, strokeHasContentState)
		else
			useFallback = true

			if fillSC then
				fillSC:Destroy()
				fillSC = nil
				ClearSupercornerValues(fillContentState, fillHasContentState)
			end
		end
	end

	if useFallback then
		local defaultRadius = scope:Computed(function(use: Fusion.Use): number
			return use<<number>>(props.CornerRadius or 0) :: number
		end)
		local strokeGradient: Instance? = nil

		if props.StrokeGradient ~= nil then
			strokeGradient = Peek<<Instance>>(props.StrokeGradient) :: Instance
		end

		return Shared.RenderFallback(scope, {
			topLeft = scope:Computed(function(use: Fusion.Use): number
				return use<<number>>(props.TopLeftRadius or defaultRadius) :: number
			end),

			topRight = scope:Computed(function(use: Fusion.Use): number
				return use<<number>>(props.TopRightRadius or defaultRadius) :: number
			end),

			bottomRight = scope:Computed(function(use: Fusion.Use): number
				return use<<number>>(props.BottomRightRadius or defaultRadius) :: number
			end),

			bottomLeft = scope:Computed(function(use: Fusion.Use): number
				return use<<number>>(props.BottomLeftRadius or defaultRadius) :: number
			end),
		}, passthroughProps, userChildren, {
			bgColor = props.BackgroundColor3,
			bgTransparency = props.BackgroundTransparency,
			strokeThickness = props.StrokeThickness,
			strokeColor = props.StrokeColor,
			strokeTransparency = props.StrokeTransparency,
			strokeGradient = strokeGradient,
		}, props.Button, userRootChildren)
	end

	-- Coalesce related prop updates so transient geometry combinations are not rasterized.
	local pendingRedrawThread: thread? = nil
	local pendingFillRedraw = false
	local pendingStrokeRedraw = false
	local isDestroyed = false

	local function ScheduleRedraw(redrawFill: boolean, redrawStroke: boolean)
		pendingFillRedraw = pendingFillRedraw or redrawFill
		pendingStrokeRedraw = pendingStrokeRedraw or redrawStroke

		if pendingRedrawThread ~= nil then return end

		local redrawThread: thread
		redrawThread = task.defer(function()
			if pendingRedrawThread ~= redrawThread then return end

			pendingRedrawThread = nil

			local shouldRedrawFill = pendingFillRedraw
			local shouldRedrawStroke = pendingStrokeRedraw
			pendingFillRedraw = false
			pendingStrokeRedraw = false

			if isDestroyed then return end

			local geo = Peek<<ShapeGeometry>>(computeShapeGeometry) :: ShapeGeometry

			if shouldRedrawFill and fillSC then
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
					UpdateSupercornerValues(
						fillSC,
						fillContentState,
						fillSliceCenterState,
						fillSliceScaleState,
						fillHasContentState
					)
				else
					warn(`[Supercorner Fusion] Failed to redraw Supercorner. Error: {err}`)
				end
			end

			if shouldRedrawStroke and strokeSC then
				local ok, err = (pcall :: any)(strokeSC.Redraw, strokeSC, {
					CornerRadius = geo.CornerRadius,
					CornerSmoothing = geo.CornerSmoothing,
					TopLeftRadius = geo.TopLeftRadius,
					TopRightRadius = geo.TopRightRadius,
					BottomRightRadius = geo.BottomRightRadius,
					BottomLeftRadius = geo.BottomLeftRadius,
					PreserveSmoothing = geo.PreserveSmoothing,
					AntiAlias = geo.AntiAlias,
					Stroke = Peek<<number>>(computeStrokeThickness) :: number,
				})

				if ok then
					UpdateSupercornerValues(
						strokeSC,
						strokeContentState,
						strokeSliceCenterState,
						strokeSliceScaleState,
						strokeHasContentState
					)
				else
					warn(`[Supercorner Fusion] Failed to redraw stroke Supercorner. Error: {err}`)
				end
			end
		end)

		pendingRedrawThread = redrawThread
	end

	if isRedrawable then
		scope:Observer(computeShapeGeometry):onChange(function()
			ScheduleRedraw(true, true)
		end)

		local previousStrokeThickness = Peek<<number>>(computeStrokeThickness) :: number

		scope:Observer(computeStrokeThickness):onChange(function()
			local strokeThickness = Peek<<number>>(computeStrokeThickness) :: number

			if previousStrokeThickness > 0 and strokeThickness > 0 then
				ScheduleRedraw(false, true)
			end

			previousStrokeThickness = strokeThickness
		end)
	end

	-- Fill toggle observer
	if not useSquareFill then
		scope:Observer(computeNeedsFill):onChange(function()
			local peekedNeedsFill = Peek<<boolean>>(computeNeedsFill) :: boolean

			if peekedNeedsFill and not fillSC then
				local newFillSC = TryCreateSupercorner(props, 0)
				fillSC = newFillSC
				pendingFillRedraw = false

				if newFillSC then
					UpdateSupercornerValues(
						newFillSC,
						fillContentState,
						fillSliceCenterState,
						fillSliceScaleState,
						fillHasContentState
					)
				end

			elseif not peekedNeedsFill and fillSC then
				fillSC:Destroy()
				fillSC = nil
				pendingFillRedraw = false
				ClearSupercornerValues(fillContentState, fillHasContentState)
			end
		end)
	end

	-- Stroke toggle observer
	scope:Observer(computeNeedsStroke):onChange(function()
		local peekedNeedsStroke = Peek<<boolean>>(computeNeedsStroke) :: boolean

		if peekedNeedsStroke and not strokeSC then
			local peekedStrokeThickness = Peek<<number>>(props.StrokeThickness or 0) :: number
			local newStrokeSC = TryCreateSupercorner(props, peekedStrokeThickness)
			strokeSC = newStrokeSC
			pendingStrokeRedraw = false

			if newStrokeSC then
				UpdateSupercornerValues(
					newStrokeSC,
					strokeContentState,
					strokeSliceCenterState,
					strokeSliceScaleState,
					strokeHasContentState
				)
			end

		elseif not peekedNeedsStroke and strokeSC then
			strokeSC:Destroy()
			strokeSC = nil
			pendingStrokeRedraw = false
			ClearSupercornerValues(strokeContentState, strokeHasContentState)
		end
	end)

	-- Cleanup
	table.insert(scope, function()
		isDestroyed = true
		pendingFillRedraw = false
		pendingStrokeRedraw = false

		if pendingRedrawThread then
			task.cancel(pendingRedrawThread)
			pendingRedrawThread = nil
		end

		if fillSC then fillSC:Destroy(); fillSC = nil end
		if strokeSC then strokeSC:Destroy(); strokeSC = nil end
	end)

	-- Build instance tree
	-- Solver V2 loses Fusion's constructors from the inferred inner-scope type.
	local imageScope: Scope = Fusion.innerScope(scope) :: any

	local fillChild: Child

	if useSquareFill then
		fillChild = imageScope:New("Frame") {
			Name = "Fill",
			BackgroundColor3 = props.BackgroundColor3,
			BackgroundTransparency = props.BackgroundTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 1,
		}
	else
		fillChild = imageScope:Computed(function(use, innerScope: Scope): Instance?
			if not (use<<boolean>>(fillHasContentState) :: boolean) then return nil end

			return innerScope:New("ImageLabel") {
				Name = "Fill",
				ImageContent = fillContentState,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = fillSliceCenterState,
				SliceScale = fillSliceScaleState,
				BackgroundTransparency = 1,
				ImageColor3 = props.BackgroundColor3,
				ImageTransparency = props.BackgroundTransparency,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 1,
			}
		end)
	end

	local computeStrokeChild = imageScope:Computed(function(use, innerScope: Scope): Instance?
		if not (use<<boolean>>(strokeHasContentState) :: boolean) then return nil end

		local strokeChildren: { [any]: any }? = nil

		if props.StrokeGradient ~= nil then
			strokeChildren = { StrokeGradient = props.StrokeGradient }
		end

		return innerScope:New("ImageLabel") {
			Name = "Stroke",
			ImageContent = strokeContentState,
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
	end)

	local imageFolder = imageScope:New("Folder") {
		Name = "SupercornerImages",

		[Children] = {
			fillChild,
			computeStrokeChild,
		},
	}

	local contentFrame = Shared.CreateContentFrame(scope, userChildren)

	local rootChildren: { [any]: any } = {
		imageFolder,
		contentFrame,
		userRootChildren,
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

return {
	new = SupercornerFusion,
	atlas = AtlasFusion,
}
