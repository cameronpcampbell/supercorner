--!strict

local Internal = require("./internal")

local AssetService = game:GetService("AssetService")

local MAX_ATLAS_SIZE = 1024

export type CreateAtlasParams = {
	CornerRadius: number?,
	CornerSmoothing: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
}

export type AtlasParams = {
	Start: CreateAtlasParams,
	End: CreateAtlasParams,
	Keypoints: number,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?,
	Stroke: number?,
}

type KeypointData = {
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
	SliceCenter: Rect,
	SliceScale: number,
}

export type SupercornerAtlas = {
	GetContent: (self: SupercornerAtlas) -> Content,
	GetKeypoint: (self: SupercornerAtlas, index: number) -> KeypointData,
	GetKeypointFromAlpha: (self: SupercornerAtlas, alpha: number) -> KeypointData,
	GetKeypointCount: (self: SupercornerAtlas) -> number,
	Destroy: (self: SupercornerAtlas) -> (),
}

type AtlasCacheEntry = {
	eImage: EditableImage,
	keypointData: { KeypointData },
	refCount: number,
	key: string,
}

-- Cache key: Start (6 * f64) + End (6 * f64) + Keypoints (u32) + PreserveSmoothing (u8) + AntiAlias (u8) + Stroke (f64) = 110 bytes
local CACHE_KEY_SIZE = 110
local CacheKeyBuf = buffer.create(CACHE_KEY_SIZE)

local AtlasCache: { [string]: AtlasCacheEntry } = {}
local atlasCacheCount = 0

local function WriteAtlasParamsToKey(buf: buffer, offset: number, params: CreateAtlasParams)
	buffer.writef64(buf, offset, params.CornerRadius or 0)
	buffer.writef64(buf, offset + 8, params.CornerSmoothing or 1)
	buffer.writef64(buf, offset + 16, if params.TopLeftRadius ~= nil then params.TopLeftRadius else -1)
	buffer.writef64(buf, offset + 24, if params.TopRightRadius ~= nil then params.TopRightRadius else -1)
	buffer.writef64(buf, offset + 32, if params.BottomRightRadius ~= nil then params.BottomRightRadius else -1)
	buffer.writef64(buf, offset + 40, if params.BottomLeftRadius ~= nil then params.BottomLeftRadius else -1)
end

local function GetAtlasCacheKey(params: AtlasParams): string
	WriteAtlasParamsToKey(CacheKeyBuf, 0, params.Start)
	WriteAtlasParamsToKey(CacheKeyBuf, 48, params.End)
	buffer.writeu32(CacheKeyBuf, 96, params.Keypoints)
	buffer.writeu8(CacheKeyBuf, 100, if params.PreserveSmoothing then 1 else 0)
	buffer.writeu8(CacheKeyBuf, 101, if params.AntiAlias == false then 0 else 1)
	buffer.writef64(CacheKeyBuf, 102, if params.Stroke ~= nil then params.Stroke else -1)
	return buffer.tostring(CacheKeyBuf)
end

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function ResolveAtlasParams(params: CreateAtlasParams): (number, number, number, number, number, number)
	local cornerRadius = params.CornerRadius or 0
	local cornerSmoothing = params.CornerSmoothing or 1
	local tl = params.TopLeftRadius or cornerRadius
	local tr = params.TopRightRadius or cornerRadius
	local br = params.BottomRightRadius or cornerRadius
	local bl = params.BottomLeftRadius or cornerRadius
	return cornerSmoothing, cornerRadius, tl, tr, br, bl
end

local function InterpolateParams(
	startParams: CreateAtlasParams,
	endParams: CreateAtlasParams,
	alpha: number,
	atlasParams: AtlasParams
): Internal.RedrawParams
	local startSmoothing, startDefault, startTL, startTR, startBR, startBL = ResolveAtlasParams(startParams)
	local endSmoothing, endDefault, endTL, endTR, endBR, endBL = ResolveAtlasParams(endParams)

	return {
		CornerRadius = Lerp(startDefault, endDefault, alpha),
		CornerSmoothing = Lerp(startSmoothing, endSmoothing, alpha),
		TopLeftRadius = Lerp(startTL, endTL, alpha),
		TopRightRadius = Lerp(startTR, endTR, alpha),
		BottomRightRadius = Lerp(startBR, endBR, alpha),
		BottomLeftRadius = Lerp(startBL, endBL, alpha),
		PreserveSmoothing = atlasParams.PreserveSmoothing,
		AntiAlias = atlasParams.AntiAlias,
		Stroke = atlasParams.Stroke,
	}
end

type KeypointLayout = {
	width: number,
	height: number,
	xOffset: number,
	yOffset: number,
	params: Internal.RedrawParams,
}

local function Atlas(params: AtlasParams): SupercornerAtlas
	assert(params.Keypoints >= 1, "[Supercorner] Atlas requires at least 1 keypoint")

	local cacheKey = GetAtlasCacheKey(params)
	local existing = AtlasCache[cacheKey]

	if existing then
		existing.refCount += 1

		local keypointData = existing.keypointData
		local keypointCount = #keypointData
		local destroyed = false

		return {
			GetContent = function(self: SupercornerAtlas): Content
				return Content.fromObject(existing.eImage)
			end,

			GetKeypoint = function(self: SupercornerAtlas, index: number): KeypointData
				assert(index >= 1 and index <= keypointCount, `[Supercorner] Keypoint index {index} out of range [1, {keypointCount}]`)
				return keypointData[index]
			end,

			GetKeypointFromAlpha = function(self: SupercornerAtlas, alpha: number): KeypointData
				local index = math.clamp(math.round(alpha * (keypointCount - 1)) + 1, 1, keypointCount)
				return keypointData[index]
			end,

			GetKeypointCount = function(self: SupercornerAtlas): number
				return keypointCount
			end,

			Destroy = function(self: SupercornerAtlas)
				if destroyed then return end
				destroyed = true

				existing.refCount -= 1

				if existing.refCount == 0 then
					AtlasCache[existing.key] = nil
					atlasCacheCount -= 1
					existing.eImage:Destroy()
				end
			end,
		}
	end

	-- Pass 1: compute layout
	local keypointCount = params.Keypoints

	local function computeLayouts(count: number): { KeypointLayout }
		local result = table.create(count) :: { KeypointLayout }

		for idx = 1, count do
			local alpha = if count > 1 then (idx - 1) / (count - 1) else 0
			local interpolated = InterpolateParams(params.Start, params.End, alpha, params)

			local width, height = Internal.CalcSize(
				interpolated.TopLeftRadius or interpolated.CornerRadius or 0,
				interpolated.TopRightRadius or interpolated.CornerRadius or 0,
				interpolated.BottomRightRadius or interpolated.CornerRadius or 0,
				interpolated.BottomLeftRadius or interpolated.CornerRadius or 0,
				params.Stroke
			)

			result[idx] = {
				width = width,
				height = height,
				xOffset = 0,
				yOffset = 0,
				params = interpolated,
			}
		end

		return result
	end

	local function packLayouts(layouts: { KeypointLayout }, count: number): (number, number, number)
		local atlasW = 0
		local rowX = 0
		local rowY = 0
		local rowH = 0

		for idx = 1, count do
			local layout = layouts[idx]

			if rowX > 0 and rowX + layout.width > MAX_ATLAS_SIZE then
				rowY += rowH

				if rowY + layout.height > MAX_ATLAS_SIZE then
					return atlasW, rowY, idx - 1
				end

				atlasW = math.max(atlasW, rowX)
				rowX = 0
				rowH = 0
			end

			if rowY + layout.height > MAX_ATLAS_SIZE then
				return atlasW, rowY, idx - 1
			end

			layout.xOffset = rowX
			layout.yOffset = rowY
			rowX += layout.width
			rowH = math.max(rowH, layout.height)
		end

		atlasW = math.max(atlasW, rowX)
		return atlasW, rowY + rowH, count
	end

	local layouts = computeLayouts(keypointCount)
	local atlasWidth, atlasHeight, fitCount = packLayouts(layouts, keypointCount)

	while fitCount < keypointCount do
		keypointCount = fitCount
		layouts = computeLayouts(keypointCount)
		atlasWidth, atlasHeight, fitCount = packLayouts(layouts, keypointCount)
	end

	if keypointCount < params.Keypoints then
		warn(`[Supercorner] Atlas keypoints clamped from {params.Keypoints} to {keypointCount} to fit within {MAX_ATLAS_SIZE}x{MAX_ATLAS_SIZE} limit.`)
	end

	-- Pass 2: render directly into atlas buffer
	local atlasRowStride = atlasWidth * 4
	local atlasBuf = buffer.create(atlasWidth * atlasHeight * 4)
	local eImage = AssetService:CreateEditableImage({ Size = Vector2.new(atlasWidth, atlasHeight) })

	local keypointData = table.create(keypointCount) :: { KeypointData }
	local prevLayout: KeypointLayout? = nil

	for idx = 1, keypointCount do
		local layout = layouts[idx]
		local w, h = layout.width, layout.height
		local xOff = layout.xOffset
		local yOff = layout.yOffset

		-- Deduplicate: if this keypoint has identical params and size to the
		-- previous one, copy from the already-rendered region instead of
		-- re-running the full render pipeline.
		local duplicated = false

		if prevLayout and w == prevLayout.width and h == prevLayout.height then
			local prev = prevLayout.params
			local cur = layout.params

			if prev.CornerRadius == cur.CornerRadius
				and prev.CornerSmoothing == cur.CornerSmoothing
				and prev.TopLeftRadius == cur.TopLeftRadius
				and prev.TopRightRadius == cur.TopRightRadius
				and prev.BottomRightRadius == cur.BottomRightRadius
				and prev.BottomLeftRadius == cur.BottomLeftRadius
				and prev.Stroke == cur.Stroke
			then
				for row = 0, h - 1 do
					local srcOffset = (prevLayout.yOffset + row) * atlasRowStride + prevLayout.xOffset * 4
					local dstOffset = (yOff + row) * atlasRowStride + xOff * 4
					buffer.copy(atlasBuf, dstOffset, atlasBuf, srcOffset, w * 4)
				end

				duplicated = true
			end
		end

		if not duplicated then
			Internal.RenderToBuffer(atlasBuf, w, h, layout.params, xOff, yOff, atlasRowStride)
		end

		keypointData[idx] = {
			ImageRectOffset = Vector2.new(xOff, yOff),
			ImageRectSize = Vector2.new(w, h),
			SliceCenter = if w <= 2 or h <= 2 then Rect.new(0, 0, 0, 0) else Internal.CalcSliceCenter(w, h, layout.params),
			SliceScale = 0.5,
		}

		prevLayout = layout
	end

	eImage:WritePixelsBuffer(
		Vector2.new(0, 0),
		Vector2.new(atlasWidth, atlasHeight),
		atlasBuf
	)

	-- Cache the result
	local entry: AtlasCacheEntry = {
		eImage = eImage,
		keypointData = keypointData,
		refCount = 1,
		key = cacheKey,
	}

	AtlasCache[cacheKey] = entry
	atlasCacheCount += 1

	local destroyed = false

	return {
		GetContent = function(self: SupercornerAtlas): Content
			return Content.fromObject(eImage)
		end,

		GetKeypoint = function(self: SupercornerAtlas, index: number): KeypointData
			assert(index >= 1 and index <= keypointCount, `[Supercorner] Keypoint index {index} out of range [1, {keypointCount}]`)
			return keypointData[index]
		end,

		GetKeypointFromAlpha = function(self: SupercornerAtlas, alpha: number): KeypointData
			local index = math.clamp(math.round(alpha * (keypointCount - 1)) + 1, 1, keypointCount)
			return keypointData[index]
		end,

		GetKeypointCount = function(self: SupercornerAtlas): number
			return keypointCount
		end,

		Destroy = function(self: SupercornerAtlas)
			if destroyed then return end
			destroyed = true

			entry.refCount -= 1

			if entry.refCount == 0 then
				AtlasCache[entry.key] = nil
				atlasCacheCount -= 1
				eImage:Destroy()
			end
		end,
	}
end

local function GetAtlasCacheSize(): number
	return atlasCacheCount
end

return {
	atlas = Atlas,
	GetAtlasCacheSize = GetAtlasCacheSize,
}
