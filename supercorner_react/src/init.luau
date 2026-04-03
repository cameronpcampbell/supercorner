--!strict

local React = require(script.Parent.Parent.Parent._Index["jsdotlua_react@17.2.1"].react)
local Supercorner =
    require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.0.6"].supercorner)

local CreateElement = React.createElement

const CREATE_ONLY_PROPS = {"MaxCornerRadius", "MaxTopLeftRadius", "MaxTopRightRadius", "MaxBottomRightRadius", "MaxBottomLeftRadius", "Redrawable"}

const SUPERCORNER_KEYS = {
    CornerRadius = true, CornerSmoothing = true,
    TopLeftRadius = true, TopRightRadius = true,
    BottomRightRadius = true, BottomLeftRadius = true,
    MaxCornerRadius = true, MaxTopLeftRadius = true,
    MaxTopRightRadius = true, MaxBottomRightRadius = true,
    MaxBottomLeftRadius = true, PreserveSmoothing = true,
    AntiAlias = true, Redrawable = true,
}

const UICORNER_HAS_INDIVIDUAL_RADII = (function()
    local reflectionService = game:GetService("ReflectionService")
    local reflection: { [any]: any } = reflectionService:GetPropertiesOfClass("UICorner")

    return
        reflection.TopLeftRadius and reflection.TopRightRadius and
        reflection.BottomLeftRadius and reflection.BottomRightRadius
end)()

local function RemoveNils(tble: { any }): { any }
    local idx = 1
    while idx <= #tble do
        if tble[idx] == nil then
            tble[idx] = tble[#tble]
            tble[#tble] = nil
        else
            idx += 1
        end
    end
    return tble
end

local function RenderSupercorner(
    props: Supercorner.CreateParams & {
        BackgroundColor3: Color3?,
        BackgroundTransparency: number?,
        [any]: any
    },
    supercorner: Supercorner.Supercorner
)
    local imageLabelProps = {
        ImageContent = supercorner:GetContent(),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = supercorner:GetSliceCenter(),
        SliceScale = supercorner:GetSliceScale(),
        BackgroundTransparency = 1,
        ImageColor3 = props.BackgroundColor3,
        ImageTransparency = props.BackgroundTransparency,
    }

    for key, value in props do
        if not SUPERCORNER_KEYS[key]
            and key ~= "BackgroundColor3"
            and key ~= "BackgroundTransparency"
        then
            imageLabelProps[key] = value
        end
    end

    return CreateElement("ImageLabel", imageLabelProps)
end

local function RenderFallback(
    props: Supercorner.CreateParams & {
        BackgroundColor3: Color3?,
        BackgroundTransparency: number?,
        [any]: any
    }
)
    local imageLabelProps = {}

    for key, value in props do
        if not SUPERCORNER_KEYS[key] then
            imageLabelProps[key] = value
        end
    end

    return
        if UICORNER_HAS_INDIVIDUAL_RADII then
            CreateElement("ImageLabel", imageLabelProps, {
                UICorner = CreateElement("UICorner", {
                    TopLeftRadius = UDim.new(0, props.TopLeftRadius or props.CornerRadius or 0),
                    TopRightRadius = UDim.new(0, props.TopRightRadius or props.CornerRadius or 0),
                    BottomRightRadius = UDim.new(0, props.BottomRightRadius or props.CornerRadius or 0),
                    BottomLeftRadius = UDim.new(0, props.BottomLeftRadius or props.CornerRadius or 0),
                })
            })

        else
            CreateElement("ImageLabel", imageLabelProps, {
                UICorner = CreateElement("UICorner", {
                    CornerRadius = UDim.new(
                        0,
                        props.CornerRadius or props.TopLeftRadius or props.TopRightRadius or
                        props.BottomRightRadius or props.BottomLeftRadius or 0
                    )
                })
            })
end

local function WarnOnCreateOnlyPropChange(props: { [any]: any })
    local createOnlyRef = React.useRef({
        MaxCornerRadius = props.MaxCornerRadius,
        MaxTopLeftRadius = props.MaxTopLeftRadius,
        MaxTopRightRadius = props.MaxTopRightRadius,
        MaxBottomRightRadius = props.MaxBottomRightRadius,
        MaxBottomLeftRadius = props.MaxBottomLeftRadius,
        Redrawable = props.Redrawable,
    })

    local prevProps = createOnlyRef.current

    for propName in CREATE_ONLY_PROPS do
        if props[propName] == prevProps[propName] then continue end

        warn(`[Supercorner React] '{propName}' cannot be updated after mount.`)
    end

    createOnlyRef.current = {
        MaxCornerRadius = props.MaxCornerRadius,
        MaxTopLeftRadius = props.MaxTopLeftRadius,
        MaxTopRightRadius = props.MaxTopRightRadius,
        MaxBottomRightRadius = props.MaxBottomRightRadius,
        MaxBottomLeftRadius = props.MaxBottomLeftRadius,
        Redrawable = props.Redrawable,
    }
end

local function Redraw(
    props: { [any]: any },
    supercorner: Supercorner.Supercorner?,
    setRedrawVersion: (updater: (v: number) -> number) -> ()
)
    local hasMounted = React.useRef(false)

    local redrawParams = React.useRef(nil :: Supercorner.RedrawParams?)
    redrawParams.current = {
        CornerRadius = props.CornerRadius,
        CornerSmoothing = props.CornerSmoothing,
        TopLeftRadius = props.TopLeftRadius,
        TopRightRadius = props.TopRightRadius,
        BottomRightRadius = props.BottomRightRadius,
        BottomLeftRadius = props.BottomLeftRadius,
        PreserveSmoothing = props.PreserveSmoothing,
        AntiAlias = props.AntiAlias,
    }

    React.useEffect(function()
        if not hasMounted.current then
            hasMounted.current = true
            return
        end

        if not supercorner then return end

        local ok, err = (pcall :: any)(supercorner.Redraw, supercorner, redrawParams.current)

        if not ok then
            warn(`[Supercorner React] Failed to redraw Supercorner. Make sure the component was created with \`Redrawable = true\`. Error: {err}`)
            return
        end

        setRedrawVersion(function(v: number) return v + 1 end)
    end, RemoveNils({
        props.CornerRadius,
        props.CornerSmoothing,
        props.TopLeftRadius,
        props.TopRightRadius,
        props.BottomRightRadius,
        props.BottomLeftRadius,
        props.PreserveSmoothing,
        props.AntiAlias,
    }) :: any)
end

return function(props: Supercorner.CreateParams & {
    BackgroundColor3: Color3?,
    BackgroundTransparency: number?,
    [any]: any
})
    local supercorner: Supercorner.Supercorner? = React.useState(function()
        local _ok, supercorner = pcall(Supercorner.new, {
            CornerRadius = props.CornerRadius,
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

    React.useEffect(function()
        return function()
            if supercorner then
                supercorner:Destroy()
            end
        end
    end, {})

    local _redrawVersion, setRedrawVersion = React.useState(0)

    WarnOnCreateOnlyPropChange(props)
    Redraw(props, supercorner, setRedrawVersion)

    return
        if supercorner then RenderSupercorner(props, supercorner)
        else RenderFallback(props)
end
