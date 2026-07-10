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
type Geometry = {
	CornerRadius: number?,
	CornerSmoothing: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
	StrokeThickness: number?,
}

local CREATE_ONLY_PROPS = { "MaxCornerRadius", "MaxTopLeftRadius", "MaxTopRightRadius", "MaxBottomRightRadius", "MaxBottomLeftRadius", "Redrawable" }

local SUPERCORNER_KEYS = {
	CornerRadius = true, CornerSmoothing = true,
	TopLeftRadius = true, TopRightRadius = true,
	BottomRightRadius = true, BottomLeftRadius = true,
	MaxCornerRadius = true, MaxTopLeftRadius = true,
	MaxTopRightRadius = true, MaxBottomRightRadius = true,
	MaxBottomLeftRadius = true, PreserveSmoothing = true,
	AntiAlias = true, Redrawable = true,
	Button = true,
	RootChildren = true,
	StrokeThickness = true, StrokeColor = true,
	StrokeTransparency = true, StrokeGradient = true,
}

local function TryCreateSupercorner(props: { [any]: any }, stroke: number): Supercorner.Supercorner?
	local _ok, supercorner = pcall(Supercorner.new, {
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
	sliceCenterState:set(sc:GetSliceCenter())
	sliceScaleState:set(sc:GetSliceScale())
	contentState:set(sc:GetContent())
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
	local userChildren: Child? = props[Children]
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

	-- Derived state
	local computeNeedsFill = scope:Computed(function(use: Fusion.Use): boolean
		return (use<<number>>(props.BackgroundTransparency or 0) :: number) ~= 1
	end)

	local computeNeedsStroke = scope:Computed(function(use: Fusion.Use): boolean
		return (use<<number>>(props.StrokeThickness or 0) :: number) > 0
	end)

	local computeGeometry = scope:Computed(function(use: Fusion.Use): Geometry
		return {
			CornerRadius = if props.CornerRadius == nil then nil else (use<<number>>(props.CornerRadius) :: number),
			CornerSmoothing = if props.CornerSmoothing == nil then nil else (use<<number>>(props.CornerSmoothing) :: number),
			TopLeftRadius = if props.TopLeftRadius == nil then nil else (use<<number>>(props.TopLeftRadius) :: number),
			TopRightRadius = if props.TopRightRadius == nil then nil else (use<<number>>(props.TopRightRadius) :: number),
			BottomRightRadius = if props.BottomRightRadius == nil then nil else (use<<number>>(props.BottomRightRadius) :: number),
			BottomLeftRadius = if props.BottomLeftRadius == nil then nil else (use<<number>>(props.BottomLeftRadius) :: number),
			PreserveSmoothing = if props.PreserveSmoothing == nil then nil else (use<<boolean>>(props.PreserveSmoothing) :: boolean),
			AntiAlias = if props.AntiAlias == nil then nil else (use<<boolean>>(props.AntiAlias) :: boolean),
			StrokeThickness = if props.StrokeThickness == nil then nil else (use<<number>>(props.StrokeThickness) :: number),
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

	if (Peek<<boolean>>(computeNeedsFill) :: boolean) then
		fillSC = TryCreateSupercorner(props, 0)

		if fillSC then
			UpdateSupercornerValues(fillSC, fillContentState, fillSliceCenterState, fillSliceScaleState)
		else
			useFallback = true
		end
	end

	if (Peek<<boolean>>(computeNeedsStroke) :: boolean) and not useFallback then
		local peekedStrokeThickness = Peek<<number>>(props.StrokeThickness or 0) :: number
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

	-- Geometry change observer — redraw on prop changes
	scope:Observer(computeGeometry):onChange(function()
		local geo = Peek<<Geometry>>(computeGeometry) :: Geometry

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
		local peekedNeedsFill = Peek<<boolean>>(computeNeedsFill) :: boolean

		if peekedNeedsFill and not fillSC then
			local newFillSC = TryCreateSupercorner(props, 0)
			fillSC = newFillSC

			if newFillSC then
				UpdateSupercornerValues(newFillSC, fillContentState, fillSliceCenterState, fillSliceScaleState)
			end

		elseif not peekedNeedsFill and fillSC then
			fillSC:Destroy()
			fillSC = nil
			fillContentState:set(nil)
		end
	end)

	-- Stroke toggle observer
	scope:Observer(computeNeedsStroke):onChange(function()
		local peekedNeedsStroke = Peek<<boolean>>(computeNeedsStroke) :: boolean

		if peekedNeedsStroke and not strokeSC then
			local peekedStrokeThickness = Peek<<number>>(props.StrokeThickness or 0) :: number
			local newStrokeSC = TryCreateSupercorner(props, peekedStrokeThickness)
			strokeSC = newStrokeSC

			if newStrokeSC then
				UpdateSupercornerValues(newStrokeSC, strokeContentState, strokeSliceCenterState, strokeSliceScaleState)
			end

		elseif not peekedNeedsStroke and strokeSC then
			strokeSC:Destroy()
			strokeSC = nil
			strokeContentState:set(nil)
		end
	end)

	-- Cleanup
	table.insert(scope, function()
		if fillSC then fillSC:Destroy(); fillSC = nil end
		if strokeSC then strokeSC:Destroy(); strokeSC = nil end
	end)

	-- Build instance tree
	local computeFillChild = scope:Computed(function(use, innerScope: Fusion.Scope): Instance?
		local usedContent = use<<Content?>>(fillContentState)
		if usedContent == nil then return nil end

		return innerScope:New("ImageLabel") {
			Name = "Fill",
			ImageContent = usedContent,
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

	local computeStrokeChild = scope:Computed(function(use, innerScope: Fusion.Scope): Instance?
		local usedContent = use<<Content?>>(strokeContentState)
		if usedContent == nil then return nil end

		local strokeChildren: { [any]: any }? = nil

		if props.StrokeGradient ~= nil then
			strokeChildren = { StrokeGradient = props.StrokeGradient }
		end

		return innerScope:New("ImageLabel") {
			Name = "Stroke",
			ImageContent = usedContent,
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

	local imageFolder = scope:New("Folder") {
		Name = "SupercornerImages",

		[Children] = {
			computeFillChild,
			computeStrokeChild,
		},
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

return {
	new = SupercornerFusion,
	atlas = AtlasFusion,
}
