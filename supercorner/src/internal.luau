--!strict
--!nolint LocalShadow

local FigmaSquircle = require("./figma_squircle_luau")
local Flatten = require("./flatten")
local Rasterize = require("./rasterize").rasterize

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

local VERTEX_STRIDE = 8
local SingleSubPath = buffer.create(4)
buffer.writeu32(SingleSubPath, 0, 0)

-- All geometry is rendered at 2x scale for HiDPI. Params use logical pixels;
-- the render function doubles radii to match the internal coordinate space.
local function RenderToBuffer(pixelBuf: buffer, width: number, height: number, params: RedrawParams, dstXOffset: number?, dstYOffset: number?, dstRowStride: number?)
	-- Smoothing of exactly 1 produces degenerate corners; clamp just below.
	local clampedSmoothing = math.min(params.CornerSmoothing or 1, 1 - 1e-6)

	local topLeftRadius, topRightRadius =
		params.TopLeftRadius, params.TopRightRadius
	local bottomRightRadius, bottomLeftRadius =
		params.BottomRightRadius, params.BottomLeftRadius

	local defaultRadius2x = (params.CornerRadius or 0) * 2
	local tl2x = if topLeftRadius then topLeftRadius * 2 else nil
	local tr2x = if topRightRadius then topRightRadius * 2 else nil
	local br2x = if bottomRightRadius then bottomRightRadius * 2 else nil
	local bl2x = if bottomLeftRadius then bottomLeftRadius * 2 else nil

	local outerOps = FigmaSquircle.get_svg_path({
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

	local antiAlias = if params.AntiAlias ~= nil then params.AntiAlias else true
	local tolerance = if antiAlias then 1/8 else 1/4
	local outerVertices, outerVertexCount = Flatten(outerOps, tolerance)

	local finalVertices = outerVertices
	local finalVertexCount = outerVertexCount
	local subPathStarts = SingleSubPath
	local subPathCount = 1

	local stroke = params.Stroke
	local strokePx = if stroke and stroke > 0 then stroke * 2 else 0
	local innerW = width - 2 * strokePx
	local innerH = height - 2 * strokePx

	if strokePx > 0 and innerW > 0 and innerH > 0 then
		local innerDefaultRadius = math.max(0, defaultRadius2x - strokePx)
		local innerOps = FigmaSquircle.get_svg_path({
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

		local innerVertices, innerVertexCount = Flatten(innerOps, tolerance)

		-- Build combined vertex buffer: outer + reversed/offset inner
		local totalCount = outerVertexCount + innerVertexCount
		local combined = buffer.create(totalCount * VERTEX_STRIDE)
		buffer.copy(combined, 0, outerVertices, 0, outerVertexCount * VERTEX_STRIDE)

		for idx = 0, innerVertexCount - 1 do
			local srcIdx = (innerVertexCount - 1 - idx) * VERTEX_STRIDE
			local dstIdx = (outerVertexCount + idx) * VERTEX_STRIDE
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

	Rasterize(
		pixelBuf,
		finalVertices,
		finalVertexCount,
		subPathStarts,
		subPathCount,
		width,
		height,
		1, 1, 1, 1,
		antiAlias,
		dstXOffset,
		dstYOffset,
		dstRowStride
	)
end

-- Each corner extends (1 + smoothing) * radius along both adjacent edges.
-- The factor is doubled here because the image is in 2x internal pixel space.
-- Slice boundaries sit at the max extension of corners sharing an edge,
-- so that no corner is cut by the 9-slice.
-- For strokes, the slice must also contain the stroke's inner edge so that
-- the stretchable edge/center slices only contain uniform geometry.
local function CalcSliceCenter(width: number, height: number, params: RedrawParams): Rect
	local smoothing = math.min(params.CornerSmoothing or 1, 1 - 1e-6)
	local defaultRadius = params.CornerRadius or 0
	local factor = (1 + smoothing) * 2
	local strokeExtension = if params.Stroke then params.Stroke * 2 else 0

	local topLeftExtension = math.max((params.TopLeftRadius or defaultRadius) * factor, strokeExtension)
	local topRightExtension = math.max((params.TopRightRadius or defaultRadius) * factor, strokeExtension)
	local bottomRightExtension = math.max((params.BottomRightRadius or defaultRadius) * factor, strokeExtension)
	local bottomLeftExtension = math.max((params.BottomLeftRadius or defaultRadius) * factor, strokeExtension)

	local left = math.max(topLeftExtension, bottomLeftExtension)
	local top = math.max(topLeftExtension, topRightExtension)
	local right = math.max(topRightExtension, bottomRightExtension)
	local bottom = math.max(bottomRightExtension, bottomLeftExtension)

	return Rect.new(left, top, width - right, height - bottom)
end

-- The max extension factor is 2 (smoothing at its peak), so each corner
-- occupies up to radius * 2 logical pixels along each edge.
-- The result is then doubled for 2x internal scale.
local function CalcSize(topLeft: number, topRight: number, bottomRight: number, bottomLeft: number): (number, number)
	local topLeftExtension = topLeft * 2
	local topRightExtension = topRight * 2
	local bottomRightExtension = bottomRight * 2
	local bottomLeftExtension = bottomLeft * 2

	local width = math.max(1, math.ceil(math.max(topLeftExtension + topRightExtension, bottomLeftExtension + bottomRightExtension))) * 2
	local height = math.max(1, math.ceil(math.max(topLeftExtension + bottomLeftExtension, topRightExtension + bottomRightExtension))) * 2

	return width, height
end

return {
	RenderToBuffer = RenderToBuffer,
	CalcSliceCenter = CalcSliceCenter,
	CalcSize = CalcSize,
}
