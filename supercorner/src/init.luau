--!strict
--!nolint LocalShadow

const Internal = require("@self/internal")
const Atlas = require("@self/atlas")

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

export type CreateAtlasParams = Atlas.CreateAtlasParams
export type AtlasParams = Atlas.AtlasParams
export type SupercornerAtlas = Atlas.SupercornerAtlas

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
local cacheCount = 0
local staticCacheCount = 0
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

const function Render(state: SupercornerState, params: RedrawParams)
	Internal.RenderToBuffer(state.PixelBuf, state.Width, state.Height, params)

	state.EImage:WritePixelsBuffer(
		Vector2.new(0, 0),
		Vector2.new(state.Width, state.Height),
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

const CalcSliceCenter = Internal.CalcSliceCenter
const CalcSize = Internal.CalcSize

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
		cacheCount += 1
	end

	local state: SupercornerState = (entry :: CacheEntry).state
	local destroyed = false
	local sliceCenter = CalcSliceCenter(width, height, params);

	(entry :: CacheEntry).refCount += 1

	return {
		Redraw = function(self: Supercorner, newParams: RedrawParams)
			if destroyed then return end

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
						cacheCount -= 1
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
					cacheCount -= 1

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
			cacheCount += 1
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
					cacheCount -= 1
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
		staticCacheCount += 1
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
				staticCacheCount -= 1
			end
		end,
	}
end

const function New(params: CreateParams): Supercorner
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
	return cacheCount
end

local function GetStaticCacheSize(): number
	return staticCacheCount
end

return {
	new = New,
	atlas = Atlas.atlas,
	GetCacheSize = GetCacheSize,
	GetStaticCacheSize = GetStaticCacheSize,
	GetAtlasCacheSize = Atlas.GetAtlasCacheSize,
}
