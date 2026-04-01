--!strict
--!nolint LocalShadow

local React = require(script.Parent.Parent.Parent._Index["jsdotlua_react@17.2.1"].react)
local Supercorner =
    require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.0.4"].supercorner)
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
    supercorner: Supercorner.Supercorner
)
    local _, props = Extract(props, "CornerRadius")
    local _, props = Extract(props, "CornerSmoothing")
    local _, props = Extract(props, "TopLeftRadius")
    local _, props = Extract(props, "TopRightRadius")
    local _, props = Extract(props, "BottomRightRadius")
    local _, props = Extract(props, "BottomLeftRadius")
    local _, props = Extract(props, "MaxCornerRadius")
    local _, props = Extract(props, "MaxTopLeftRadius")
    local _, props = Extract(props, "MaxTopRightRadius")
    local _, props = Extract(props, "MaxBottomRightRadius")
    local _, props = Extract(props, "MaxBottomLeftRadius")
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
    local topLeftRadius, props = Extract(props, "TopLeftRadius")
    local topRightRadius, props = Extract(props, "TopRightRadius")
    local bottomRightRadius, props = Extract(props, "BottomRightRadius")
    local bottomLeftRadius, props = Extract(props, "BottomLeftRadius")
    local _, props = Extract(props, "MaxCornerRadius")
    local _, props = Extract(props, "MaxTopLeftRadius")
    local _, props = Extract(props, "MaxTopRightRadius")
    local _, props = Extract(props, "MaxBottomRightRadius")
    local _, props = Extract(props, "MaxBottomLeftRadius")
    local _, props = Extract(props, "PreserveSmoothing")
    local _, props = Extract(props, "AntiAlias")
    local _, props = Extract(props, "Redrawable")

    return
        if UICORNER_HAS_INDIVIDUAL_RADII then
            CreateElement("ImageLabel", props, {
                UICorner = CreateElement("UICorner", {
                    TopLeftRadius = UDim.new(0, topLeftRadius or cornerRadius or 0),
                    TopRightRadius = UDim.new(0, topRightRadius or cornerRadius or 0),
                    BottomRightRadius = UDim.new(0, bottomRightRadius or cornerRadius or 0),
                    BottomLeftRadius = UDim.new(0, bottomLeftRadius or cornerRadius or 0),
                })
            })

        else
            CreateElement("ImageLabel", props, {
                UICorner = CreateElement("UICorner", {
                    CornerRadius = UDim.new(
                        0,
                        cornerRadius or topLeftRadius or topRightRadius or
                        bottomRightRadius or bottomLeftRadius or 0
                    )
                })
            })
end

return function(props: T.Flatten<Supercorner.CreateParams & {
    BackgroundColor3: Color3?,
    BackgroundTransparency: number?,
    [any]: any
}>)
    local supercorner: Supercorner.Supercorner? = React.useState(function()
        local _ok, supercorner = pcall(Supercorner.new, {
            CornerRadius = props.CornerRadius or 0,
            CornerSmoothing = props.CornerSmoothing,
            TopLeftRadius = props.TopLeftRadius,
            TopRightRadius = props.TopRightRadius,
            BottomRightRadius = props.BottomRightRadius,
            BottomLeftRadius = props.BottomLeftRadius,
            MaxCornerRadius = props.MaxCornerRadius,
            MaxTopLeftRadius = props.MaxTopLeftRadius,
            MaxTopRightRadius = props.MaxTopRightRadius,
            MaxBottomRightRadius = props.MaxBottomRightRadius,
            MaxBottomLeftRadius = props.MaxBottomLeftRadius,
            PreserveSmoothing = props.PreserveSmoothing,
            AntiAlias = props.AntiAlias,
            Redrawable = props.Redrawable,
        })

        if not supercorner then
            warn("[Supercorner React] Failed to create Supercorner, possibly due to the editable memory budget being reached. Falling back to UICorner.")
        end

        return supercorner
    end) :: any

    return
        if supercorner then RenderSupercorner(props, supercorner)
        else RenderFallback(props)
end
