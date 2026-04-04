--!strict

local Fusion =
	require(script.Parent.Parent.Parent._Index["elttob_fusion@0.3.0"].fusion)
local Supercorner =
	require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.0.8"].supercorner)

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

const NON_PASSTHROUGH_KEYS = {
	BackgroundColor3 = true,
	BackgroundTransparency = true,
}

const UICORNER_HAS_INDIVIDUAL_RADII = (function()
	local reflectionService = game:GetService("ReflectionService")
	local reflection: { [any]: any } = reflectionService:GetPropertiesOfClass("UICorner")

	return
		reflection.TopLeftRadius and reflection.TopRightRadius and
		reflection.BottomLeftRadius and reflection.BottomRightRadius
end)()

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

local function GetPassthroughProps(props: { [any]: any }): { [any]: any }
	local result = {}

	for key, value in props do
		if key == Children then continue end
		if SUPERCORNER_KEYS[key] then continue end
		if NON_PASSTHROUGH_KEYS[key] then continue end

		result[key] = value
	end

	return result
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

local function CreateCornerClip(
	scope: Scope,
	radius: UsedAs<number>,
	clipPosition: UDim2,
	fillPosition: UDim2,
	backgroundColor: UsedAs<Color3>?,
	backgroundTransparency: UsedAs<number>?,
	strokeThickness: UsedAs<number>?,
	strokeColor: UsedAs<Color3>?,
	strokeTransparency: UsedAs<number>?,
	strokeGradient: Instance?
): Instance
	local fillChildren: { [any]: any } = {
		UICorner = scope:New("UICorner") {
			CornerRadius = scope:Computed(function(use)
				return UDim.new(0, use(radius))
			end),
		},
	}

	local peekedStrokeThickness = Peek(strokeThickness)

	if (peekedStrokeThickness or 0) > 0 then
		local strokeChildren: { [any]: any }? = nil

		if strokeGradient then
			strokeChildren = { StrokeGradient = strokeGradient:Clone() }
		end

		fillChildren.UIStroke = scope:New("UIStroke") {
			Thickness = strokeThickness,
			Color = if strokeGradient then Color3.new(1, 1, 1) else strokeColor,
			Transparency = strokeTransparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			[Children] = strokeChildren,
		}
	end

	return scope:New("Frame") {
		Size = UDim2.new(0.5, 0, 0.5, 0),
		Position = clipPosition,
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Children] = {
			Fill = scope:New("Frame") {
				Size = UDim2.new(2, 0, 2, 0),
				Position = fillPosition,
				BackgroundColor3 = backgroundColor,
				BackgroundTransparency = backgroundTransparency,
				ZIndex = 0,
				[Children] = fillChildren,
			},
		},
	}
end

local function RenderClippedCornersFallback(
	scope: Scope,
	props: { [any]: any },
	passthroughProps: { [any]: any },
	userChildren: Child?
): Instance
	local defaultRadius = scope:Computed(function(use)
		return use(props.CornerRadius) or 0
	end)

	local bgColor = props.BackgroundColor3
	local bgTransparency = props.BackgroundTransparency
	local strokeThickness = props.StrokeThickness
	local strokeColor = props.StrokeColor
	local strokeTransparency = props.StrokeTransparency
	local peekedStrokeGradient = Peek(props.StrokeGradient)

	local computeTopLeftRadius = scope:Computed(function(use)
		return use(props.TopLeftRadius) or use(defaultRadius)
	end)

	local computeTopRightRadius = scope:Computed(function(use)
		return use(props.TopRightRadius) or use(defaultRadius)
	end)

	local computeBottomLeftRadius = scope:Computed(function(use)
		return use(props.BottomLeftRadius) or use(defaultRadius)
	end)

	local computeBottomRightRadius = scope:Computed(function(use)
		return use(props.BottomRightRadius) or use(defaultRadius)
	end)

	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,

		[Children] = {
			TopLeftClip = CreateCornerClip(
				scope, computeTopLeftRadius,
				UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0),
				bgColor, bgTransparency,
				strokeThickness, strokeColor, strokeTransparency, peekedStrokeGradient
			),

			TopRightClip = CreateCornerClip(
				scope, computeTopRightRadius,
				UDim2.new(0.5, 0, 0, 0), UDim2.new(-1, 0, 0, 0),
				bgColor, bgTransparency,
				strokeThickness, strokeColor, strokeTransparency, peekedStrokeGradient
			),

			BottomLeftClip = CreateCornerClip(
				scope, computeBottomLeftRadius,
				UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 0, -1, 0),
				bgColor, bgTransparency,
				strokeThickness, strokeColor, strokeTransparency, peekedStrokeGradient
			),

			BottomRightClip = CreateCornerClip(
				scope, computeBottomRightRadius,
				UDim2.new(0.5, 0, 0.5, 0), UDim2.new(-1, 0, -1, 0),
				bgColor, bgTransparency,
				strokeThickness, strokeColor, strokeTransparency, peekedStrokeGradient
			),

			ChildrenFrame = if userChildren then scope:New("Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = userChildren,
			} else nil,
		},
	}

	for key, value in passthroughProps do
		rootProps[key] = value
	end

	return scope:New("ImageLabel")(rootProps)
end

local function RenderFallback(scope: Scope, props: { [any]: any }): Instance
	local passthroughProps = GetPassthroughProps(props)
	local userChildren: Child? = props[Children]

	local needsStroke = scope:Computed(function(use)
		return (use(props.StrokeThickness) or 0) > 0
	end)

	if UICORNER_HAS_INDIVIDUAL_RADII then
		local allChildren: { [any]: any } = {
			UICorner = scope:New("UICorner") {
				TopLeftRadius = scope:Computed(function(use)
					return UDim.new(0, use(props.TopLeftRadius) or use(props.CornerRadius) or 0)
				end),

				TopRightRadius = scope:Computed(function(use)
					return UDim.new(0, use(props.TopRightRadius) or use(props.CornerRadius) or 0)
				end),

				BottomRightRadius = scope:Computed(function(use)
					return UDim.new(0, use(props.BottomRightRadius) or use(props.CornerRadius) or 0)
				end),

				BottomLeftRadius = scope:Computed(function(use)
					return UDim.new(0, use(props.BottomLeftRadius) or use(props.CornerRadius) or 0)
				end),
			},

			UIStroke = scope:Computed(function(use, innerScope: Fusion.Scope): Instance?
				if not use(needsStroke) then return nil end

				local peekedStrokeGradient = Peek(props.StrokeGradient)
				local strokeChildren: { [any]: any }? = nil

				if peekedStrokeGradient then
					strokeChildren = { StrokeGradient = peekedStrokeGradient:Clone() }
				end

				return innerScope:New("UIStroke") {
					Thickness = props.StrokeThickness,
					Color = if peekedStrokeGradient then Color3.new(1, 1, 1) else props.StrokeColor,
					Transparency = props.StrokeTransparency,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					[Children] = strokeChildren,
				}
			end),

			ChildrenFrame = if userChildren then scope:New("Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = userChildren,
			} else nil,
		}

		local rootProps: { [any]: any } = {
			BackgroundColor3 = props.BackgroundColor3,
			BackgroundTransparency = props.BackgroundTransparency,
			[Children] = allChildren,
		}

		for key, value in passthroughProps do
			rootProps[key] = value
		end

		return scope:New("ImageLabel")(rootProps)

	else
		return RenderClippedCornersFallback(scope, props, passthroughProps, userChildren)
	end
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
	local passthroughProps = GetPassthroughProps(props)
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
		return RenderFallback(scope, props)
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

return SupercornerFusion
