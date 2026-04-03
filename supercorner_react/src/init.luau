--!strict

local React = require(script.Parent.Parent.Parent._Index["jsdotlua_react@17.2.1"].react)
local Supercorner =
    require(script.Parent.Parent.Parent._Index["cameronpcampbell_supercorner@0.0.8"].supercorner)

local CreateElement = React.createElement

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

local function TryCreateSupercorner(props: { [any]: any }, stroke: number): Supercorner.Supercorner?
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
        Stroke = stroke,
    })

    if not supercorner then
        warn("[Supercorner React] Failed to create Supercorner, possibly due to the editable memory budget being reached. Falling back to UICorner.")
    end

    return supercorner
end

local function GetPassthroughProps(props: { [any]: any }): { [any]: any }
    local result = {}

    for key, value in props do
        if not SUPERCORNER_KEYS[key]
            and key ~= "BackgroundColor3"
            and key ~= "BackgroundTransparency"
            and key ~= "children"
        then
            result[key] = value
        end
    end

    return result
end

local function RenderSupercorner(
    props: { [any]: any },
    fillSupercorner: Supercorner.Supercorner?,
    strokeSupercorner: Supercorner.Supercorner?
)
    local passthroughProps = GetPassthroughProps(props)
    local children = props.children

    if fillSupercorner and strokeSupercorner then
        local fillProps = {
            ImageContent = fillSupercorner:GetContent(),
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = fillSupercorner:GetSliceCenter(),
            SliceScale = fillSupercorner:GetSliceScale(),
            BackgroundTransparency = 1,
            ImageColor3 = props.BackgroundColor3,
            ImageTransparency = props.BackgroundTransparency,
        }

        for key, value in passthroughProps do
            fillProps[key] = value
        end

        local allChildren = {
            StrokeFolder = CreateElement("Folder", nil, {
                StrokeImage = CreateElement("ImageLabel", {
                    ImageContent = strokeSupercorner:GetContent(),
                    ScaleType = Enum.ScaleType.Slice,
                    SliceCenter = strokeSupercorner:GetSliceCenter(),
                    SliceScale = strokeSupercorner:GetSliceScale(),
                    BackgroundTransparency = 1,
                    ImageColor3 = props.StrokeColor,
                    ImageTransparency = props.StrokeTransparency,
                    Size = UDim2.new(1, 0, 1, 0),
                }, if props.StrokeGradient then { StrokeGradient = props.StrokeGradient } else nil)
            }),
        }

        if children then
            for key, child in children do
                allChildren[key] = child
            end
        end

        return CreateElement("ImageLabel", fillProps, allChildren)

    elseif fillSupercorner then
        local fillProps = {
            ImageContent = fillSupercorner:GetContent(),
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = fillSupercorner:GetSliceCenter(),
            SliceScale = fillSupercorner:GetSliceScale(),
            BackgroundTransparency = 1,
            ImageColor3 = props.BackgroundColor3,
            ImageTransparency = props.BackgroundTransparency,
        }

        for key, value in passthroughProps do
            fillProps[key] = value
        end

        return CreateElement("ImageLabel", fillProps, children)

    elseif strokeSupercorner then
        local strokeProps = {
            ImageContent = strokeSupercorner:GetContent(),
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = strokeSupercorner:GetSliceCenter(),
            SliceScale = strokeSupercorner:GetSliceScale(),
            BackgroundTransparency = 1,
            ImageColor3 = props.StrokeColor,
            ImageTransparency = props.StrokeTransparency,
        }

        for key, value in passthroughProps do
            strokeProps[key] = value
        end

        local allChildren = nil

        if props.StrokeGradient or children then
            allChildren = {}

            if props.StrokeGradient then
                allChildren.StrokeGradient = props.StrokeGradient
            end

            if children then
                for key, child in children do
                    allChildren[key] = child
                end
            end
        end

        return CreateElement("ImageLabel", strokeProps, allChildren)
    end

    return nil
end

local function RenderFallback(props: { [any]: any })
    local imageLabelProps = {}

    for key, value in props do
        if not SUPERCORNER_KEYS[key] and key ~= "children" then
            imageLabelProps[key] = value
        end
    end

    local needsStroke = (props.StrokeThickness or 0) > 0

    local uiStroke = if needsStroke
        then CreateElement("UIStroke", {
            Thickness = props.StrokeThickness,
            Color = props.StrokeColor,
            Transparency = props.StrokeTransparency,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, if props.StrokeGradient then { StrokeGradient = props.StrokeGradient } else nil)
        else nil

    local allChildren: { [any]: any } = {
        UIStroke = uiStroke,
    }

    if props.children then
        for key, child in props.children do
            allChildren[key] = child
        end
    end

    if UICORNER_HAS_INDIVIDUAL_RADII then
        allChildren.UICorner = CreateElement("UICorner", {
            TopLeftRadius = UDim.new(0, props.TopLeftRadius or props.CornerRadius or 0),
            TopRightRadius = UDim.new(0, props.TopRightRadius or props.CornerRadius or 0),
            BottomRightRadius = UDim.new(0, props.BottomRightRadius or props.CornerRadius or 0),
            BottomLeftRadius = UDim.new(0, props.BottomLeftRadius or props.CornerRadius or 0),
        })

    else
        allChildren.UICorner = CreateElement("UICorner", {
            CornerRadius = UDim.new(
                0,
                props.CornerRadius or props.TopLeftRadius or props.TopRightRadius or
                props.BottomRightRadius or props.BottomLeftRadius or 0
            )
        })
    end

    return CreateElement("ImageLabel", imageLabelProps, allChildren)
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

local function RedrawFill(
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

local function RedrawStroke(
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
        Stroke = props.StrokeThickness,
    }

    React.useEffect(function()
        if not hasMounted.current then
            hasMounted.current = true
            return
        end

        if not supercorner then return end

        local ok, err = (pcall :: any)(supercorner.Redraw, supercorner, redrawParams.current)

        if not ok then
            warn(`[Supercorner React] Failed to redraw stroke Supercorner. Make sure the component was created with \`Redrawable = true\`. Error: {err}`)
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
        props.StrokeThickness,
    }) :: any)
end

return function(props: Supercorner.CreateParams & {
    BackgroundColor3: Color3?,
    BackgroundTransparency: number?,
    StrokeThickness: number?,
    StrokeColor: Color3?,
    StrokeTransparency: number?,
    StrokeGradient: UIGradient?,
    [any]: any
})
    local needsFill = (props.BackgroundTransparency or 0) ~= 1
    local needsStroke = (props.StrokeThickness or 0) > 0

    local fillRef = React.useRef(nil :: Supercorner.Supercorner?)
    local strokeRef = React.useRef(nil :: Supercorner.Supercorner?)

    local _version, setVersion = React.useState(0)

    local bumpVersion = function()
        setVersion(function(v: number) return v + 1 end)
    end

    -- Initial creation (runs once, avoids blank first frame)
    React.useState(function()
        if needsFill then
            fillRef.current = TryCreateSupercorner(props, 0)
        end

        if needsStroke then
            strokeRef.current = TryCreateSupercorner(props, props.StrokeThickness :: number)
        end

        return nil
    end)

    -- Toggle fill on/off
    React.useEffect(function()
        if needsFill and not fillRef.current then
            fillRef.current = TryCreateSupercorner(props, 0)
            bumpVersion()

        elseif not needsFill and fillRef.current then
            fillRef.current:Destroy()
            fillRef.current = nil
            bumpVersion()
        end
    end, { needsFill })

    -- Toggle stroke on/off
    React.useEffect(function()
        if needsStroke and not strokeRef.current then
            strokeRef.current = TryCreateSupercorner(props, props.StrokeThickness :: number)
            bumpVersion()

        elseif not needsStroke and strokeRef.current then
            strokeRef.current:Destroy()
            strokeRef.current = nil
            bumpVersion()
        end
    end, { needsStroke })

    -- Unmount cleanup
    React.useEffect(function()
        return function()
            if fillRef.current then fillRef.current:Destroy() end
            if strokeRef.current then strokeRef.current:Destroy() end
        end
    end, {})

    local _fillRedrawVersion, setFillRedrawVersion = React.useState(0)
    local _strokeRedrawVersion, setStrokeRedrawVersion = React.useState(0)

    WarnOnCreateOnlyPropChange(props)
    RedrawFill(props, fillRef.current, setFillRedrawVersion)
    RedrawStroke(props, strokeRef.current, setStrokeRedrawVersion)

    local fill = fillRef.current
    local stroke = strokeRef.current

    return
        if fill or stroke then RenderSupercorner(props, fill, stroke)
        else RenderFallback(props)
end
