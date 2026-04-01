--!strict
--!nolint LocalShadow

const FigmaSquircle = require("@self/figma_squircle_luau")
const Flatten = require("@self/flatten")
const Rasterize = require("@self/rasterize")

const AssetService = game:GetService("AssetService")

export type CreateParams = {
	CornerRadius: number,
	CornerSmoothing: number,
	TopLeftCornerRadius: number?,
	TopRightCornerRadius: number?,
	BottomRightCornerRadius: number?,
	BottomLeftCornerRadius: number?,
	MaxTopLeftCornerRadius: number?,
	MaxTopRightCornerRadius: number?,
	MaxBottomRightCornerRadius: number?,
	MaxBottomLeftCornerRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
	Redrawable: boolean?,
}

export type RedrawParams = {
	CornerRadius: number,
	CornerSmoothing: number,
	TopLeftCornerRadius: number?,
	TopRightCornerRadius: number?,
	BottomRightCornerRadius: number?,
	BottomLeftCornerRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?
}

export type Squircle = {
	Redraw: (self: Squircle, params: RedrawParams) -> (),
	GetContent: (self: Squircle) -> Content,
	Destroy: (self: Squircle) -> (),
}

type SquircleState = {
	EImage: EditableImage,
	PixelBuf: buffer,
	Width: number,
	Height: number,
}

type CacheEntry = {
	state: SquircleState,
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
const CacheKeyBuf = buffer.create(66)

const function GetCacheKey(width: number, height: number, params: RedrawParams): string
	buffer.writef64(CacheKeyBuf, 0, width)
	buffer.writef64(CacheKeyBuf, 8, height)
	buffer.writef64(CacheKeyBuf, 16, params.CornerRadius)
	buffer.writef64(CacheKeyBuf, 24, params.CornerSmoothing)
	buffer.writef64(CacheKeyBuf, 32, if params.TopLeftCornerRadius ~= nil then params.TopLeftCornerRadius else -1)
	buffer.writef64(CacheKeyBuf, 40, if params.TopRightCornerRadius ~= nil then params.TopRightCornerRadius else -1)
	buffer.writef64(CacheKeyBuf, 48, if params.BottomRightCornerRadius ~= nil then params.BottomRightCornerRadius else -1)
	buffer.writef64(CacheKeyBuf, 56, if params.BottomLeftCornerRadius ~= nil then params.BottomLeftCornerRadius else -1)
	buffer.writeu8(CacheKeyBuf, 64, if params.PreserveSmoothing then 1 else 0)
	buffer.writeu8(CacheKeyBuf, 65, if params.AntiAlias == false then 0 else 1)
	return buffer.tostring(CacheKeyBuf)
end

const function render(state: SquircleState, params: RedrawParams)
	const width, height = state.Width, state.Height

	-- Currently theres an issue with corners becoming degenerate under certain
	-- conditions. I've found that one of the variables in this issue occuring
	-- is the corner smoothing being `1`. So by clamping to some value just before
	-- that we can mitigate this issue whilst still perceptually allowing for a
	-- smoothing factor of `1`.
	local clamped_smoothing = math.min(params.CornerSmoothing, 1 - 1e-6)

	local topLeftCornerRadius, topRightCornerRadius =
	    params.TopLeftCornerRadius, params.TopRightCornerRadius
	local bottomRightCornerRadius, bottomLeftCornerRadius =
		params.BottomRightCornerRadius, params.BottomLeftCornerRadius

	const ops = FigmaSquircle.get_svg_path({
		width = width,
		height = height,
		cornerRadius = params.CornerRadius * 2,
		cornerSmoothing = clamped_smoothing,
		topLeftCornerRadius =
		    if topLeftCornerRadius then topLeftCornerRadius * 2 else nil,
		topRightCornerRadius =
		    if topRightCornerRadius then topRightCornerRadius * 2 else nil,
		bottomRightCornerRadius =
		    if bottomRightCornerRadius then bottomRightCornerRadius * 2 else nil,
		bottomLeftCornerRadius =
		    if bottomLeftCornerRadius then bottomLeftCornerRadius * 2 else nil,
		preserveSmoothing = params.PreserveSmoothing,
	})

	const antiAlias = if params.AntiAlias ~= nil then params.AntiAlias else true
	const tolerance = if antiAlias then 1/8 else 1/4
	const vertices, vertex_count = Flatten(ops, tolerance)

	buffer.fill(state.PixelBuf, 0, 0)

	Rasterize(
		state.PixelBuf,
		vertices,
		vertex_count,
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

local function CalcSizeFromCorners(params: RedrawParams): Vector2
	local smoothing = math.min(params.CornerSmoothing, 1 - 1e-6)
	local default_r = params.CornerRadius
	local tl_r = params.TopLeftCornerRadius or default_r
	local tr_r = params.TopRightCornerRadius or default_r
	local br_r = params.BottomRightCornerRadius or default_r
	local bl_r = params.BottomLeftCornerRadius or default_r

	local factor = 1 + smoothing
	local tl_p = tl_r * factor
	local tr_p = tr_r * factor
	local br_p = br_r * factor
	local bl_p = bl_r * factor

	return Vector2.new(
		math.max(1, math.ceil(math.max(tl_p + tr_p, bl_p + br_p))),
		math.max(1, math.ceil(math.max(tl_p + bl_p, tr_p + br_p)))
	)
end

const function ClampToMaxRadii(
	params: RedrawParams,
	maxTopLeft: number,
	maxTopRight: number,
	maxBottomRight: number,
	maxBottomLeft: number
): RedrawParams
	local defaultRadius = params.CornerRadius
	local topLeft = params.TopLeftCornerRadius or defaultRadius
	local topRight = params.TopRightCornerRadius or defaultRadius
	local bottomRight = params.BottomRightCornerRadius or defaultRadius
	local bottomLeft = params.BottomLeftCornerRadius or defaultRadius

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
		TopLeftCornerRadius = topLeft,
		TopRightCornerRadius = topRight,
		BottomRightCornerRadius = bottomRight,
		BottomLeftCornerRadius = bottomLeft,
		PreserveSmoothing = params.PreserveSmoothing,
		AntiAlias = params.AntiAlias,
	}
end

const function NewRedrawable(
	width: number,
	height: number,
	cacheKey: string,
	params: RedrawParams,
	maxTopLeft: number,
	maxTopRight: number,
	maxBottomRight: number,
	maxBottomLeft: number
): Squircle
	local entry: CacheEntry? = Cache[cacheKey]

	if entry == nil then
		local state: SquircleState = {
			EImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) }),
			PixelBuf = buffer.create(width * height * 4),
			Width = width,
			Height = height,
		}

		render(state, params)

		entry = {
			state = state,
			refCount = 0,
			key = cacheKey,
		}

		Cache[cacheKey] = entry
	end

	local state: SquircleState = (entry :: CacheEntry).state
	local destroyed = false

	(entry :: CacheEntry).refCount += 1

	return {
		Redraw = function(self: Squircle, new_params: RedrawParams)
			if destroyed then return end

			new_params = ClampToMaxRadii(new_params, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
			local newKey = GetCacheKey(width, height, new_params)

			if entry ~= nil and entry.key == newKey then return end

			local newEntry = Cache[newKey]

			if newEntry ~= nil then
				local oldEImage = state.EImage
				local ownsOldState = entry == nil or entry.refCount == 1

				-- Detach from current entry
				if entry ~= nil then
					entry.refCount -= 1
					if entry.refCount == 0 then
						Cache[entry.key] = nil
					end
				end

				-- Attach to existing entry
				local newEntry = newEntry :: CacheEntry
				newEntry.refCount += 1
				state = newEntry.state

				-- Clean up old EImage if we were the sole owner
				if ownsOldState and oldEImage ~= state.EImage then
					oldEImage:Destroy()
				end

			else
				-- Detach from current entry, clone if shared
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

				render(state, new_params)
				entry = { state = state, refCount = 1, key = newKey }
				Cache[newKey] = entry
			end
		end,

		GetContent = function(self: Squircle): Content
			return Content.fromObject(state.EImage)
		end,

		Destroy = function(self: Squircle)
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

const function NewStatic(width: number, height: number, cacheKey: string, params: RedrawParams): Squircle
	local staticEntry: StaticCacheEntry? = StaticCache[cacheKey]
	local destroyed = false
	local staticContent: Content

	if staticEntry ~= nil then
		(staticEntry :: StaticCacheEntry).refCount += 1
		staticContent = (staticEntry :: StaticCacheEntry).content

	else
		local eImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })

		local tempState: SquircleState = {
			EImage = eImage,
			PixelBuf = buffer.create(width * height * 4),
			Width = width,
			Height = height,
		}

		render(tempState, params)
		staticContent = ToStaticContent(eImage)
		eImage:Destroy()

		staticEntry = {
			content = staticContent,
			refCount = 1,
			key = cacheKey,
		}

		StaticCache[cacheKey] = staticEntry :: StaticCacheEntry
	end

	return {
		Redraw = function(self: Squircle, new_params: RedrawParams)
			error(
				"Cannot redraw a non-redrawable Supercorner. Pass `Redrawable = true` in the"
				.. " constructor params to enable redrawing. You can also call `:SetRedrawable(true)`"
				.. " on an existing instance, however the former is strongly preferred."
			)
		end,

		GetContent = function(self: Squircle): Content
			return staticContent
		end,

		Destroy = function(self: Squircle)
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

const function new(params: CreateParams): Squircle
	local defaultRadius = params.CornerRadius
	local maxTopLeft = params.MaxTopLeftCornerRadius or params.TopLeftCornerRadius or defaultRadius
	local maxTopRight = params.MaxTopRightCornerRadius or params.TopRightCornerRadius or defaultRadius
	local maxBottomRight = params.MaxBottomRightCornerRadius or params.BottomRightCornerRadius or defaultRadius
	local maxBottomLeft = params.MaxBottomLeftCornerRadius or params.BottomLeftCornerRadius or defaultRadius

	local topLeftExtension = maxTopLeft * 2
	local topRightExtension = maxTopRight * 2
	local bottomRightExtension = maxBottomRight * 2
	local bottomLeftExtension = maxBottomLeft * 2

	local width = math.max(1, math.ceil(math.max(topLeftExtension + topRightExtension, bottomLeftExtension + bottomRightExtension))) * 2
	local height = math.max(1, math.ceil(math.max(topLeftExtension + bottomLeftExtension, topRightExtension + bottomRightExtension))) * 2

	local clampedParams = ClampToMaxRadii(params, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
	local cacheKey = GetCacheKey(width, height, clampedParams)

	if params.Redrawable or not CAN_CREATE_STATIC_CONTENT then
		return NewRedrawable(width, height, cacheKey, clampedParams, maxTopLeft, maxTopRight, maxBottomRight, maxBottomLeft)
	end

	return NewStatic(width, height, cacheKey, clampedParams)
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
	new = new,
	CalcSizeFromCorners = CalcSizeFromCorners,
	GetCacheSize = GetCacheSize,
	GetStaticCacheSize = GetStaticCacheSize,
}
