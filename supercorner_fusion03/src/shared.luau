--!strict

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages["elttob_fusion@0.3.0"].fusion)
local Peek, Children = Fusion.peek, Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
type Child = Fusion.Child

export type ResolvedRadii = {
	topLeft: UsedAs<number>,
	topRight: UsedAs<number>,
	bottomRight: UsedAs<number>,
	bottomLeft: UsedAs<number>,
}

export type VisualProps = {
	bgColor: UsedAs<Color3>?,
	bgTransparency: UsedAs<number>?,
	strokeThickness: UsedAs<number>?,
	strokeColor: UsedAs<Color3>?,
	strokeTransparency: UsedAs<number>?,
	strokeGradient: Instance?,
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

local function GetPassthroughProps(props: { [any]: any }, supercornerKeys: { [string]: boolean }): { [any]: any }
	local result = {}

	for key, value in props do
		if key == Children then continue end
		if supercornerKeys[key] then continue end
		if NON_PASSTHROUGH_KEYS[key] then continue end

		result[key] = value
	end

	return result
end

local function RenderRoot(
	scope: Scope,
	button: boolean?,
	defaultClass: "Frame" | "ImageLabel",
	rootProps: { [any]: any }
): Instance
	if button == true then
		rootProps.Text = ""
		return scope:New("TextButton")(rootProps)
	end

	if defaultClass == "Frame" then
		return scope:New("Frame")(rootProps)
	end

	return scope:New("ImageLabel")(rootProps)
end

local function CreateContentFrame(scope: Scope, userChildren: Child?): Instance
	return scope:New("Frame") {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,

		[Children] = userChildren,
	}
end

local function CreateCornerClip(
	scope: Scope,
	radius: UsedAs<number>,
	clipPosition: UDim2,
	fillPosition: UDim2,
	visual: VisualProps
): Instance
	local fillChildren: { [any]: any } = {
		UICorner = scope:New("UICorner") {
			CornerRadius = scope:Computed(function(use: Fusion.Use): UDim
				return UDim.new(0, use<<number>>(radius))
			end),
		},
	}

	local peekedStrokeThickness = Peek<<number>>(visual.strokeThickness or 0)

	if (peekedStrokeThickness or 0) > 0 then
		local strokeChildren: { [any]: any }? = nil

		if visual.strokeGradient then
			strokeChildren = { StrokeGradient = visual.strokeGradient:Clone() }
		end

		fillChildren.UIStroke = scope:New("UIStroke") {
			Thickness = visual.strokeThickness,
			Color = if visual.strokeGradient then Color3.new(1, 1, 1) else visual.strokeColor,
			Transparency = visual.strokeTransparency,
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
				BackgroundColor3 = visual.bgColor,
				BackgroundTransparency = visual.bgTransparency,
				ZIndex = 0,
				[Children] = fillChildren,
			},
		},
	}
end

local function RenderClippedCornersFallback(
	scope: Scope,
	radii: ResolvedRadii,
	passthroughProps: { [any]: any },
	userChildren: Child?,
	visual: VisualProps,
	button: boolean?,
	rootChildren: Child?
): Instance
	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,

		[Children] = {
			TopLeftClip = CreateCornerClip(
				scope, radii.topLeft,
				UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0),
				visual
			),

			TopRightClip = CreateCornerClip(
				scope, radii.topRight,
				UDim2.new(0.5, 0, 0, 0), UDim2.new(-1, 0, 0, 0),
				visual
			),

			BottomLeftClip = CreateCornerClip(
				scope, radii.bottomLeft,
				UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 0, -1, 0),
				visual
			),

			BottomRightClip = CreateCornerClip(
				scope, radii.bottomRight,
				UDim2.new(0.5, 0, 0.5, 0), UDim2.new(-1, 0, -1, 0),
				visual
			),

			Content = CreateContentFrame(scope, userChildren),

			[Children] = rootChildren,
		},
	}

	for key, value in passthroughProps do
		rootProps[key] = value
	end

	return RenderRoot(scope, button, "ImageLabel", rootProps)
end

local function RenderFallback(
	scope: Scope,
	radii: ResolvedRadii,
	passthroughProps: { [any]: any },
	userChildren: Child?,
	visual: VisualProps,
	button: boolean?,
	rootChildren: Child?
): Instance
	local needsStroke = scope:Computed(function(use: Fusion.Use): boolean
		return use<<number>>(visual.strokeThickness or 0) > 0
	end)

	if UICORNER_HAS_INDIVIDUAL_RADII then
		local allChildren: { [any]: any } = {
			UICorner = scope:New("UICorner") {
				TopLeftRadius = scope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.topLeft))
				end),

				TopRightRadius = scope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.topRight))
				end),

				BottomRightRadius = scope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.bottomRight))
				end),

				BottomLeftRadius = scope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.bottomLeft))
				end),
			},

			UIStroke = scope:Computed(function(use: Fusion.Use, innerScope: Fusion.Scope): Instance?
				if not use<<boolean>>(needsStroke) then return nil end

				local strokeChildren: { [any]: any }? = nil

				if visual.strokeGradient then
					strokeChildren = { StrokeGradient = visual.strokeGradient:Clone() }
				end

				return innerScope:New("UIStroke") {
					Thickness = visual.strokeThickness,
					Color = if visual.strokeGradient then Color3.new(1, 1, 1) else visual.strokeColor,
					Transparency = visual.strokeTransparency,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					[Children] = strokeChildren,
				}
			end),

			Content = CreateContentFrame(scope, userChildren),

			[Children] = rootChildren,
		}

		local rootProps: { [any]: any } = {
			BackgroundColor3 = visual.bgColor,
			BackgroundTransparency = visual.bgTransparency,
			[Children] = allChildren,
		}

		for key, value in passthroughProps do
			rootProps[key] = value
		end

		return RenderRoot(scope, button, "ImageLabel", rootProps)

	else
		return RenderClippedCornersFallback(scope, radii, passthroughProps, userChildren, visual, button, rootChildren)
	end
end

return {
	NON_PASSTHROUGH_KEYS = NON_PASSTHROUGH_KEYS,
	UICORNER_HAS_INDIVIDUAL_RADII = UICORNER_HAS_INDIVIDUAL_RADII,
	CreateContentFrame = CreateContentFrame,
	GetPassthroughProps = GetPassthroughProps,
	RenderRoot = RenderRoot,
	RenderFallback = RenderFallback,
}
