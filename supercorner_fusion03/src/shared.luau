--!strict

local Packages = script.Parent.Parent.roblox_packages

local Fusion = require(Packages.fusion)
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

local NON_PASSTHROUGH_KEYS = {
	BackgroundColor3 = true,
	BackgroundTransparency = true,
}

local function IsChildrenKey(key: any): boolean
	if key == Children then return true end
	if typeof(key) ~= "table" then return false end

	-- Consumers can provide Children from a different Fusion module instance.
	-- Match the public SpecialKey metadata instead of relying on table identity.
	return key.type == "SpecialKey" and key.kind == "Children"
end

local UICORNER_HAS_INDIVIDUAL_RADII = (function()
	local reflectionService = game:GetService("ReflectionService")
	local reflection: { [any]: any } = reflectionService:GetPropertiesOfClass("UICorner")

	return
		reflection.TopLeftRadius and reflection.TopRightRadius and
		reflection.BottomLeftRadius and reflection.BottomRightRadius
end)()

local function GetPassthroughProps(props: { [any]: any }, supercornerKeys: { [string]: boolean }): { [any]: any }
	local result = {}

	for key, value in props do
		if IsChildrenKey(key) then continue end
		if supercornerKeys[key] then continue end
		if NON_PASSTHROUGH_KEYS[key] then continue end

		result[key] = value
	end

	return result
end

local function GetChildren(props: { [any]: any }): Child?
	local children: { Child } = {}

	for key, value in props do
		if IsChildrenKey(key) then
			table.insert(children, value :: Child)
		end
	end

	if #children == 0 then return nil end
	if #children == 1 then return children[1] end

	return Fusion.Child(children)
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
				return UDim.new(0, use<<number>>(radius) :: number)
			end),
		},
	}

	local peekedStrokeThickness = Peek<<number>>(visual.strokeThickness or 0) :: number

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
	-- Solver V2 loses Fusion's constructors from the inferred inner-scope type.
	local graphicsScope: Scope = Fusion.innerScope(scope) :: any

	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,

		[Children] = {
			TopLeftClip = CreateCornerClip(
				graphicsScope, radii.topLeft,
				UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0),
				visual
			),

			TopRightClip = CreateCornerClip(
				graphicsScope, radii.topRight,
				UDim2.new(0.5, 0, 0, 0), UDim2.new(-1, 0, 0, 0),
				visual
			),

			BottomLeftClip = CreateCornerClip(
				graphicsScope, radii.bottomLeft,
				UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 0, -1, 0),
				visual
			),

			BottomRightClip = CreateCornerClip(
				graphicsScope, radii.bottomRight,
				UDim2.new(0.5, 0, 0.5, 0), UDim2.new(-1, 0, -1, 0),
				visual
			),

			Content = CreateContentFrame(scope, userChildren),

			rootChildren,
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
	if UICORNER_HAS_INDIVIDUAL_RADII then
		-- Solver V2 loses Fusion's constructors from the inferred inner-scope type.
		local graphicsScope: Scope = Fusion.innerScope(scope) :: any
		local needsStroke = graphicsScope:Computed(function(use: Fusion.Use): boolean
			return (use<<number>>(visual.strokeThickness or 0) :: number) > 0
		end)

		local allChildren: { [any]: any } = {
			UICorner = graphicsScope:New("UICorner") {
				TopLeftRadius = graphicsScope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.topLeft) :: number)
				end),

				TopRightRadius = graphicsScope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.topRight) :: number)
				end),

				BottomRightRadius = graphicsScope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.bottomRight) :: number)
				end),

				BottomLeftRadius = graphicsScope:Computed(function(use: Fusion.Use): UDim
					return UDim.new(0, use<<number>>(radii.bottomLeft) :: number)
				end),
			},

			UIStroke = graphicsScope:Computed(function(use: Fusion.Use, innerScope: Scope): Instance?
				if not (use<<boolean>>(needsStroke) :: boolean) then return nil end

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

			rootChildren,
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

local function RenderSquare(
	scope: Scope,
	passthroughProps: { [any]: any },
	userChildren: Child?,
	visual: VisualProps,
	button: boolean?,
	rootChildren: Child?
): Instance
	-- Solver V2 loses Fusion's constructors from the inferred inner-scope type.
	local graphicsScope: Scope = Fusion.innerScope(scope) :: any
	local needsStroke = graphicsScope:Computed(function(use: Fusion.Use): boolean
		return (use<<number>>(visual.strokeThickness or 0) :: number) > 0
	end)

	local squareFrame = graphicsScope:New("Frame") {
		Name = "Fill",
		BackgroundColor3 = visual.bgColor,
		BackgroundTransparency = visual.bgTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,

		[Children] = {
			Stroke = graphicsScope:Computed(function(use: Fusion.Use, innerScope: Scope): Instance?
				if not (use<<boolean>>(needsStroke) :: boolean) then return nil end

				local strokeChildren: { [any]: any }? = nil

				if visual.strokeGradient then
					strokeChildren = { StrokeGradient = visual.strokeGradient:Clone() }
				end

				local strokeColor = if visual.strokeGradient
					then Color3.new(1, 1, 1)
					else visual.strokeColor or Color3.new(1, 1, 1)

				return innerScope:New("UIStroke") {
					Name = "Stroke",
					Thickness = visual.strokeThickness,
					Color = strokeColor,
					Transparency = visual.strokeTransparency,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					LineJoinMode = Enum.LineJoinMode.Miter,
					ZIndex = 3,
					[Children] = strokeChildren,
				}
			end),
		},
	}

	local imageFolder = graphicsScope:New("Folder") {
		Name = "SupercornerImages",

		[Children] = {
			squareFrame,
		},
	}

	local allChildren: { [any]: any } = {
		imageFolder,
		CreateContentFrame(scope, userChildren),
		rootChildren,
	}

	local rootProps: { [any]: any } = {
		BackgroundTransparency = 1,
		[Children] = allChildren,
	}

	for key, value in passthroughProps do
		rootProps[key] = value
	end

	return RenderRoot(scope, button, "Frame", rootProps)
end

return {
	NON_PASSTHROUGH_KEYS = NON_PASSTHROUGH_KEYS,
	UICORNER_HAS_INDIVIDUAL_RADII = UICORNER_HAS_INDIVIDUAL_RADII,
	CreateContentFrame = CreateContentFrame,
	GetChildren = GetChildren,
	GetPassthroughProps = GetPassthroughProps,
	RenderRoot = RenderRoot,
	RenderFallback = RenderFallback,
	RenderSquare = RenderSquare,
}
