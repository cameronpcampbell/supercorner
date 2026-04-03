--!strict
--!nolint LocalShadow

const FigmaSquircle = require("@self/figma_squircle_luau")
const Flatten = require("@self/flatten")
const RasterizeModule = require("@self/rasterize")
const Rasterize = RasterizeModule.rasterize
const fillInterior = RasterizeModule.fillInterior

const AssetService = game:GetService("AssetService")

export type CreateParams = {
	CornerRadius: number?,
	CornerSmoothing: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
	MaxCornerRadius: number?,
	MaxTopLeftRadius: number?,
	MaxTopRightRadius: number?,
	MaxBottomRightRadius: number?,
	MaxBottomLeftRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
	Redrawable: boolean?,
	Stroke: number?,
}

export type RedrawParams = {
	CornerRadius: number?,
	CornerSmoothing: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
	Stroke: number?,
}

export type Supercorner = {
	Redraw: (self: Supercorner, params: RedrawParams) -> (),
	GetContent: (self: Supercorner) -> Content,
	GetSliceCenter: (self: Supercorner) -> Rect,
	GetSliceScale: (self: Supercorner) -> number,
	Destroy: (self: Supercorner) -> (),
}

type SupercornerState = {
	EImage: EditableImage,
	PixelBuf: buffer,
	Width: number,
	Height: number,
}

type CacheEntry = {
	state: SupercornerState,
	refCount: number,
	key: string,
}

type StaticCacheEntry = {
	content: Content,
	refCount: number,
	key: string,
}

type CreateDataModelContentAsync =
    (self: AssetService, content: Content, options: { [string]: any }?)
        -> (Enum.CreateContentResult, Content)

const CAN_CREATE_STATIC_CONTENT = (function()
    const ok, data = pcall(
        AssetService.CreateDataModelContentAsync, AssetService, Content.none, nil
    )

    return if ok then ok else data ~= "CreateDataModelContentAsync is not available yet"
end)()

const Cache: { [string]: CacheEntry } = {}
const StaticCache: { [string]: StaticCacheEntry } = {}
const CacheKeyBuf = buffer.create(74)

const function GetCacheKey(width: number, height: number, params: RedrawParams): string
	buffer.writef64(CacheKeyBuf, 0, width)
	buffer.writef64(CacheKeyBuf, 8, height)
	buffer.writef64(CacheKeyBuf, 16, params.CornerRadius or 0)
	buffer.writef64(CacheKeyBuf, 24, params.CornerSmoothing or 1)
	buffer.writef64(CacheKeyBuf, 32, if params.TopLeftRadius ~= nil then params.TopLeftRadius else -1)
	buffer.writef64(CacheKeyBuf, 40, if params.TopRightRadius ~= nil then params.TopRightRadius else -1)
	buffer.writef64(CacheKeyBuf, 48, if params.BottomRightRadius ~= nil then params.BottomRightRadius else -1)
	buffer.writef64(CacheKeyBuf, 56, if params.BottomLeftRadius ~= nil then params.BottomLeftRadius else -1)
	buffer.writeu8(CacheKeyBuf, 64, if params.PreserveSmoothing then 1 else 0)
	buffer.writeu8(CacheKeyBuf, 65, if params.AntiAlias == false then 0 else 1)
	buffer.writef64(CacheKeyBuf, 66, if params.Stroke ~= nil then params.Stroke else -1)
	return buffer.tostring(CacheKeyBuf)
end

const VERTEX_STRIDE = 8
const SingleSubPath = buffer.create(4)
buffer.writeu32(SingleSubPath, 0, 0)

-- All geometry is rendered at 2x scale for HiDPI. Params use logical pixels;
-- the render function doubles radii to match the internal coordinate space.
const function Render(state: SupercornerState, params: RedrawParams)
	const width, height = state.Width, state.Height

	-- Smoothing of exactly 1 produces degenerate corners; clamp just below.
	local clampedSmoothing = math.min(params.CornerSmoothing or 1, 1 - 1e-6)

	local topLeftRadius, topRightRadius =
	    params.TopLeftRadius, params.TopRightRadius
	local bottomRightRadius, bottomLeftRadius =
		params.BottomRightRadius, params.BottomLeftRadius

	const defaultRadius2x = (params.CornerRadius or 0) * 2
	const tl2x = if topLeftRadius then topLeftRadius * 2 else nil
	const tr2x = if topRightRadius then topRightRadius * 2 else nil
	const br2x = if bottomRightRadius then bottomRightRadius * 2 else nil
	const bl2x = if bottomLeftRadius then bottomLeftRadius * 2 else nil

	const outerOps = FigmaSquircle.get_svg_path({
		width = width,
		height = height,
		cornerRadius = defaultRadius2x,
		cornerSmoothing = clampedSmoothing,
		topLeftCornerRadius = tl2x,
		topRightCornerRadius = tr2x,
		bottomRightCornerRadius = br2x,
		bottomLeftCornerRadius = bl2x,
		preserveSmoothing = params.PreserveSmoothing,
	})

	const antiAlias = if params.AntiAlias ~= nil then params.AntiAlias else true
	const tolerance = if antiAlias then 1/8 else 1/4
	const outerVertices, outerVertexCount = Flatten(outerOps, tolerance)

	local finalVertices = outerVertices
	local finalVertexCount = outerVertexCount
	local subPathStarts = SingleSubPath
	local subPathCount = 1

	local stroke = params.Stroke
	local strokePx = if stroke and stroke > 0 then stroke * 2 else 0
	local innerW = width - 2 * strokePx
	local innerH = height - 2 * strokePx

	if strokePx > 0 and innerW > 0 and innerH > 0 then
		const innerDefaultRadius = math.max(0, defaultRadius2x - strokePx)
		const innerOps = FigmaSquircle.get_svg_path({
			width = innerW,
			height = innerH,
			cornerRadius = innerDefaultRadius,
			cornerSmoothing = clampedSmoothing,
			topLeftCornerRadius =
				if tl2x then math.max(0, tl2x - strokePx) else nil,
			topRightCornerRadius =
				if tr2x then math.max(0, tr2x - strokePx) else nil,
			bottomRightCornerRadius =
				if br2x then math.max(0, br2x - strokePx) else nil,
			bottomLeftCornerRadius =
				if bl2x then math.max(0, bl2x - strokePx) else nil,
			preserveSmoothing = params.PreserveSmoothing,
		})

		const innerVertices, innerVertexCount = Flatten(innerOps, tolerance)

		-- Build combined vertex buffer: outer + reversed/offset inner
		local totalCount = outerVertexCount + innerVertexCount
		local combined = buffer.create(totalCount * VERTEX_STRIDE)
		buffer.copy(combined, 0, outerVertices, 0, outerVertexCount * VERTEX_STRIDE)

		for idx = 0, innerVertexCount - 1 do
			const srcIdx = (innerVertexCount - 1 - idx) * VERTEX_STRIDE
			const dstIdx = (outerVertexCount + idx) * VERTEX_STRIDE
			buffer.writef32(combined, dstIdx, buffer.readf32(innerVertices, srcIdx) + strokePx)
			buffer.writef32(combined, dstIdx + 4, buffer.readf32(innerVertices, srcIdx + 4) + strokePx)
		end

		finalVertices = combined
		finalVertexCount = totalCount
		subPathStarts = buffer.create(8)
		buffer.writeu32(subPathStarts, 0, 0)
		buffer.writeu32(subPathStarts, 4, outerVertexCount)
		subPathCount = 2
	end

	fillInterior(state.PixelBuf, 0, width * height, 0x00FFFFFF)

	Rasterize(
		state.PixelBuf,
		finalVertices,
		finalVertexCount,
		subPathStarts,
		subPathCount,
		width,
		height,
		1, 1, 1, 1,
		antiAlias
	)

	state.EImage:WritePixelsBuffer(
		Vector2.new(0, 0),
		Vector2.new(width, height),
		state.PixelBuf
	)
end

const function ToStaticContent(eImage: EditableImage): Content
	local result, content = (AssetService.CreateDataModelContentAsync :: CreateDataModelContentAsync)(AssetService, Content.fromObject(eImage))
	assert(result == Enum.CreateContentResult.Success, "Failed to create static content")
	return content
end

const function ClampToMaxRadii(
	params: RedrawParams,
	maxTopLeft: number,
	maxTopRight: number,
	maxBottomRight: number,
	maxBottomLeft: number
): RedrawParams
	local defaultRadius = params.CornerRadius or 0
	local topLeft = params.TopLeftRadius or defaultRadius
	local topRight = params.TopRightRadius or defaultRadius
	local bottomRight = params.BottomRightRadius or defaultRadius
	local bottomLeft = params.BottomLeftRadius or defaultRadius

	local clamped = false

	if topLeft > maxTopLeft then
		clamped = true
		warn(`[Supercorner] TopLeft corner radius {topLeft} exceeds max {maxTopLeft}. Clamping!`)
		topLeft = maxTopLeft
	end

	if topRight > maxTopRight then
		clamped = true
		warn(`[Supercorner] TopRight corner radius {topRight} exceeds max {maxTopRight}. Clamping!`)
		topRight = maxTopRight
	end

	if bottomRight > maxBottomRight then
		clamped = true
		warn(`[Supercorner] BottomRight corner radius {bottomRight} exceeds max {maxBottomRight}. Clamping!`)
		bottomRight = maxBottomRight
	end

	if bottomLeft > maxBottomLeft then
		clamped = true
		warn(`[Supercorner] BottomLeft corner radius {bottomLeft} exceeds max {maxBottomLeft}. Clamping!`)
		bottomLeft = maxBottomLeft
	end

	if not clamped then
		return params
	end

	return {
		CornerRadius = math.min(defaultRadius, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft),
		CornerSmoothing = params.CornerSmoothing,
		TopLeftRadius = topLeft,
		TopRightRadius = topRight,
		BottomRightRadius = bottomRight,
		BottomLeftRadius = bottomLeft,
		PreserveSmoothing = params.PreserveSmoothing,
		AntiAlias = params.AntiAlias,
		Stroke = params.Stroke,
	}
end

-- Each corner extends (1 + smoothing) * radius along both adjacent edges.
-- The factor is doubled here because the image is in 2x internal pixel space.
-- Slice boundaries sit at the max extension of corners sharing an edge,
-- so that no corner is cut by the 9-slice.
-- For strokes, the slice must also contain the stroke's inner edge so that
-- the stretchable edge/center slices only contain uniform geometry.
const function CalcSliceCenter(width: number, height: number, params: RedrawParams): Rect
	local smoothing = math.min(params.CornerSmoothing or 1, 1 - 1e-6)
	local defaultRadius = params.CornerRadius or 0
	local factor = (1 + smoothing) * 2
	local strokeExtension = if params.Stroke then params.Stroke * 2 else 0

	local topLeftExtension = math.max((params.TopLeftRadius or defaultRadius) * factor, strokeExtension)
	local topRightExtension = math.max((params.TopRightRadius or defaultRadius) * factor, strokeExtension)
	local bottomRightExtension = math.max((params.BottomRightRadius or defaultRadius) * factor, strokeExtension)
	local bottomLeftExtension = math.max((params.BottomLeftRadius or defaultRadius) * factor, strokeExtension)

	return Rect.new(
		math.max(topLeftExtension, bottomLeftExtension),
		math.max(topLeftExtension, topRightExtension),
		width - math.max(topRightExtension, bottomRightExtension),
		height - math.max(bottomRightExtension, bottomLeftExtension)
	)
end

-- The max extension factor is 2 (smoothing at its peak), so each corner
-- occupies up to radius * 2 logical pixels along each edge.
-- The result is then doubled for 2x internal scale.
const function CalcSize(topLeft: number, topRight: number, bottomRight: number, bottomLeft: number): (number, number)
	local topLeftExtension = topLeft * 2
	local topRightExtension = topRight * 2
	local bottomRightExtension = bottomRight * 2
	local bottomLeftExtension = bottomLeft * 2

	local width = math.max(1, math.ceil(math.max(topLeftExtension + topRightExtension, bottomLeftExtension + bottomRightExtension))) * 2
	local height = math.max(1, math.ceil(math.max(topLeftExtension + bottomLeftExtension, topRightExtension + bottomRightExtension))) * 2

	return width, height
end

const function NewRedrawable(
	width: number,
	height: number,
	params: RedrawParams,
	maxTopLeft: number,
	maxTopRight: number,
	maxBottomRight: number,
	maxBottomLeft: number
): Supercorner
	local cacheKey = GetCacheKey(width, height, params)
	local entry: CacheEntry? = Cache[cacheKey]

	if entry == nil then
		local state: SupercornerState = {
			EImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) }),
			PixelBuf = buffer.create(width * height * 4),
			Width = width,
			Height = height,
		}

		Render(state, params)

		entry = {
			state = state,
			refCount = 0,
			key = cacheKey,
		}

		Cache[cacheKey] = entry
	end

	local state: SupercornerState = (entry :: CacheEntry).state
	local destroyed = false
	local sliceCenter = CalcSliceCenter(width, height, params);

	(entry :: CacheEntry).refCount += 1

	return {
		Redraw = function(self: Supercorner, newParams: RedrawParams)
			if destroyed then return end

			newParams.CornerRadius = newParams.CornerRadius or 0
			newParams.CornerSmoothing = newParams.CornerSmoothing or 1

			newParams = ClampToMaxRadii(newParams, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
			local newKey = GetCacheKey(width, height, newParams)

			if entry ~= nil and entry.key == newKey then return end

			sliceCenter = CalcSliceCenter(width, height, newParams)

			local newEntry = Cache[newKey]

			if newEntry ~= nil then
				local oldEImage = state.EImage
				local ownsOldState = entry == nil or entry.refCount == 1

				if entry ~= nil then
					entry.refCount -= 1

					if entry.refCount == 0 then
						Cache[entry.key] = nil
					end
				end

				local newEntry = newEntry :: CacheEntry
				newEntry.refCount += 1
				state = newEntry.state

				if ownsOldState and oldEImage ~= state.EImage then
					oldEImage:Destroy()
				end

				return
			end

			-- No cache hit — reuse our state if we're the sole owner, otherwise clone
			if entry ~= nil then
				entry.refCount -= 1

				if entry.refCount == 0 then
					Cache[entry.key] = nil

				else
					state = {
						EImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) }),
						PixelBuf = buffer.create(width * height * 4),
						Width = width,
						Height = height,
					}
				end
			end

			Render(state, newParams)
			entry = { state = state, refCount = 1, key = newKey }
			Cache[newKey] = entry
		end,

		GetContent = function(self: Supercorner): Content
			return Content.fromObject(state.EImage)
		end,

		GetSliceCenter = function(self: Supercorner): Rect
			return sliceCenter
		end,

		GetSliceScale = function(self: Supercorner): number
			return 0.5
		end,

		Destroy = function(self: Supercorner)
			if destroyed then return end
			destroyed = true

			if entry ~= nil then
				entry.refCount -= 1

				if entry.refCount == 0 then
					Cache[entry.key] = nil
					state.EImage:Destroy()
				end

				entry = nil

			else
				state.EImage:Destroy()
			end
		end,
	}
end

const function NewStatic(width: number, height: number, params: RedrawParams): Supercorner
	local cacheKey = GetCacheKey(width, height, params)
	local staticEntry: StaticCacheEntry? = StaticCache[cacheKey]
	local destroyed = false
	local staticContent: Content

	if staticEntry ~= nil then
		(staticEntry :: StaticCacheEntry).refCount += 1
		staticContent = (staticEntry :: StaticCacheEntry).content

	else
		local eImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })

		local tempState: SupercornerState = {
			EImage = eImage,
			PixelBuf = buffer.create(width * height * 4),
			Width = width,
			Height = height,
		}

		Render(tempState, params)
		staticContent = ToStaticContent(eImage)
		eImage:Destroy()

		staticEntry = {
			content = staticContent,
			refCount = 1,
			key = cacheKey,
		}

		StaticCache[cacheKey] = staticEntry :: StaticCacheEntry
	end

	local sliceCenter = CalcSliceCenter(width, height, params)

	return {
		Redraw = function(self: Supercorner, newParams: RedrawParams)
			error(
				"Cannot redraw a non-redrawable Supercorner. Pass `Redrawable = true` in the"
				.. " constructor params to enable redrawing. You can also call `:SetRedrawable(true)`"
				.. " on an existing instance, however the former is strongly preferred."
			)
		end,

		GetContent = function(self: Supercorner): Content
			return staticContent
		end,

		GetSliceCenter = function(self: Supercorner): Rect
			return sliceCenter
		end,

		GetSliceScale = function(self: Supercorner): number
			return 0.5
		end,

		Destroy = function(self: Supercorner)
			if destroyed then return end
			destroyed = true

			if staticEntry == nil then return end

			local staticEntry = staticEntry :: StaticCacheEntry
			staticEntry.refCount -= 1

			if staticEntry.refCount == 0 then
				StaticCache[staticEntry.key] = nil
			end
		end,
	}
end

const function New(params: CreateParams): Supercorner
	local params = table.clone(params)
	params.CornerRadius = params.CornerRadius or 0
	params.CornerSmoothing = params.CornerSmoothing or 1

	local defaultRadius: number = params.CornerRadius or 0
	local topLeft: number = params.TopLeftRadius or defaultRadius
	local topRight: number = params.TopRightRadius or defaultRadius
	local bottomRight: number = params.BottomRightRadius or defaultRadius
	local bottomLeft: number = params.BottomLeftRadius or defaultRadius

	if params.Redrawable or not CAN_CREATE_STATIC_CONTENT then
		local maxDefault: number = params.MaxCornerRadius or defaultRadius
		local maxTopLeft: number = params.MaxTopLeftRadius or math.max(maxDefault, topLeft)
		local maxTopRight: number = params.MaxTopRightRadius or math.max(maxDefault, topRight)
		local maxBottomRight: number = params.MaxBottomRightRadius or math.max(maxDefault, bottomRight)
		local maxBottomLeft: number = params.MaxBottomLeftRadius or math.max(maxDefault, bottomLeft)

		local width, height = CalcSize(maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
		local clampedParams = ClampToMaxRadii(params, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)

		return NewRedrawable(width, height, clampedParams, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
	end

	local width, height = CalcSize(topLeft, topRight, bottomRight, bottomLeft)

	return NewStatic(width, height, params)
end

local function GetCacheSize(): number
	local count = 0

	for _ in Cache do
		count += 1
	end

	return count
end

local function GetStaticCacheSize(): number
	local count = 0

	for _ in StaticCache do
		count += 1
	end

	return count
end

return {
	new = New,
	GetCacheSize = GetCacheSize,
	GetStaticCacheSize = GetStaticCacheSize,
}
