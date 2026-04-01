--!strict
--!nolint LocalShadow

local React = require(script.Parent.Parent.Parent._Index["jsdotlua_react@17.2.1"].react)
local Supercorner =
    require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.0.1"].supercorner)
local T = require(script.Parent.Parent.Parent._Index["cameronpcampbell_typeforge@3.0.3"].typeforge)

local CreateElement = React.createElement

const UICORNER_HAS_INDIVIDUAL_RADII = (function()
    local reflectionService = game:GetService("ReflectionService")
    local reflection: { [any]: any } = reflectionService:GetPropertiesOfClass("UICorner")

    return
        reflection.TopLeftRadius and reflection.TopRightRadius and
        reflection.BottomLeftRadius and reflection.BottomRightRadius
end)()

local function Extract<T, V>(tble: T, propName: V & keyof<T>): (index<T, V>, T.Omit<T, V>)
    local value = (tble :: { [any]: any })[propName]

    if not value then return nil :: any, tble end

    (tble :: { [any]: any })[propName] = nil
    return value, tble
end

local function Merge<TA, TB>(tbleA: TA, tbleB: TB): T.Flatten<TB & TA>
    for key, value in tbleB :: { [any]: any } do
        (tbleA :: { [any]: any })[key] = value
    end

    return tbleA :: any
end

local function RenderSupercorner(
    props: T.Flatten<Supercorner.CreateParams & {
        BackgroundColor3: Color3?,
        BackgroundTransparency: number?,
        [any]: any
    }>,
    supercorner: Supercorner.Squircle
)
    local _, props = Extract(props, "CornerRadius")
    local _, props = Extract(props, "CornerSmoothing")
    local _, props = Extract(props, "TopLeftCornerRadius")
    local _, props = Extract(props, "TopRightCornerRadius")
    local _, props = Extract(props, "BottomRightCornerRadius")
    local _, props = Extract(props, "BottomLeftCornerRadius")
    local _, props = Extract(props, "MaxCornerRadius")
    local _, props = Extract(props, "MaxTopLeftCornerRadius")
    local _, props = Extract(props, "MaxTopRightCornerRadius")
    local _, props = Extract(props, "MaxBottomRightCornerRadius")
    local _, props = Extract(props, "MaxBottomLeftCornerRadius")
    local _, props = Extract(props, "PreserveSmoothing")
    local _, props = Extract(props, "AntiAlias")
    local _, props = Extract(props, "Redrawable")

    local backgroundColor3, props = Extract(props, "BackgroundColor3")
    local backgroundTransparency, props = Extract(props, "BackgroundTransparency")

    return CreateElement("ImageLabel", Merge({
       	ImageContent = supercorner:GetContent(),
       	ScaleType = Enum.ScaleType.Slice,
       	SliceCenter = supercorner:GetSliceCenter(),
       	SliceScale = supercorner:GetSliceScale(),
        BackgroundTransparency = 1,
        ImageColor3 = backgroundColor3,
        ImageTransparency = backgroundTransparency
    }, props))
end

local function RenderFallback(
    props: T.Flatten<Supercorner.CreateParams & {
        BackgroundColor3: Color3?,
        BackgroundTransparency: number?,
        [any]: any
    }>
)
    local cornerRadius, props = Extract(props, "CornerRadius")
    local _, props = Extract(props, "CornerSmoothing")
    local topLeftCornerRadius, props = Extract(props, "TopLeftCornerRadius")
    local topRightCornerRadius, props = Extract(props, "TopRightCornerRadius")
    local bottomRightCornerRadius, props = Extract(props, "BottomRightCornerRadius")
    local bottomLeftCornerRadius, props = Extract(props, "BottomLeftCornerRadius")
    local _, props = Extract(props, "MaxCornerRadius")
    local _, props = Extract(props, "MaxTopLeftCornerRadius")
    local _, props = Extract(props, "MaxTopRightCornerRadius")
    local _, props = Extract(props, "MaxBottomRightCornerRadius")
    local _, props = Extract(props, "MaxBottomLeftCornerRadius")
    local _, props = Extract(props, "PreserveSmoothing")
    local _, props = Extract(props, "AntiAlias")
    local _, props = Extract(props, "Redrawable")

    return
        if UICORNER_HAS_INDIVIDUAL_RADII then
            CreateElement("ImageLabel", props, {
                UICorner = CreateElement("UICorner", {
                    TopLeftRadius = UDim.new(0, topLeftCornerRadius or cornerRadius or 0),
                    TopRightRadius = UDim.new(0, topRightCornerRadius or cornerRadius or 0),
                    BottomRightRadius = UDim.new(0, bottomRightCornerRadius or cornerRadius or 0),
                    BottomLeftRadius = UDim.new(0, bottomLeftCornerRadius or cornerRadius or 0),
                })
            })

        else
            CreateElement("ImageLabel", props, {
                UICorner = CreateElement("UICorner", {
                    CornerRadius = UDim.new(
                        0,
                        cornerRadius or topLeftCornerRadius or topRightCornerRadius or
                        bottomRightCornerRadius or bottomLeftCornerRadius or 0
                    )
                })
            })
end

return function(props: T.Flatten<Supercorner.CreateParams & {
    BackgroundColor3: Color3?,
    BackgroundTransparency: number?,
    [any]: any
}>)
    local supercorner: Supercorner.Squircle? = React.useState(function()
        local _ok, supercorner = pcall(Supercorner.new, {
            CornerRadius = props.CornerRadius,
            CornerSmoothing = props.CornerSmoothing,
            TopLeftCornerRadius = props.TopLeftCornerRadius,
            TopRightCornerRadius = props.TopRightCornerRadius,
            BottomRightCornerRadius = props.BottomRightCornerRadius,
            BottomLeftCornerRadius = props.BottomLeftCornerRadius,
            MaxCornerRadius = props.MaxCornerRadius,
            MaxTopLeftCornerRadius = props.MaxTopLeftCornerRadius,
            MaxTopRightCornerRadius = props.MaxTopRightCornerRadius,
            MaxBottomRightCornerRadius = props.MaxBottomRightCornerRadius,
            MaxBottomLeftCornerRadius = props.MaxBottomLeftCornerRadius,
            PreserveSmoothing = props.PreserveSmoothing,
            AntiAlias = props.AntiAlias,
            Redrawable = props.Redrawable,
        })

        if not supercorner then
            warn("[Supercorner React] Failed to create Supercorner, possibly due to the editable memory budget being reached. Falling back to UICorner.")
        end

        print(Supercorner:GetCacheSize(), Supercorner:GetStaticCacheSize())

        return supercorner
    end) :: any

    return
        if supercorner then RenderSupercorner(props, supercorner)
        else RenderFallback(props)
end
