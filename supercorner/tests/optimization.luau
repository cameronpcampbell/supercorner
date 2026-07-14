--!strict

local Rasterize = require("../src/rasterize").rasterize
local Fs = require("@lune/fs")
local Luau = require("@lune/luau")

-- The public Roblox module depends on services that are unavailable in Lune.
-- Load the pure flattener with its type-only Roblox require replaced, while Rojo
-- build validation covers the full Roblox-facing tree.
local flattenSource = Fs.readFile("src/flatten.luau")
flattenSource = flattenSource:gsub(
	"local squircleTypes = require%(script%.Parent%.figma_squircle_luau%)",
	"local squircleTypes = {}"
)

type Flatten = (ops: { any }, tolerance: number, reuseBuf: buffer?) -> (buffer, number)
local Flatten = Luau.load(flattenSource, { debugName = "@flatten" })() :: Flatten

local VERTEX_STRIDE = 8

type Point = { x: number, y: number }

local function writeVertices(paths: { { Point } }): (buffer, number, buffer, number)
	local vertexCount = 0

	for _, path in paths do
		vertexCount += #path
	end

	local vertices = buffer.create(vertexCount * VERTEX_STRIDE)
	local subPathStarts = buffer.create(#paths * 4)
	local index = 0

	for pathIndex, path in paths do
		buffer.writeu32(subPathStarts, (pathIndex - 1) * 4, index)

		for _, point in path do
			local offset = index * VERTEX_STRIDE
			buffer.writef32(vertices, offset, point.x)
			buffer.writef32(vertices, offset + 4, point.y)
			index += 1
		end
	end

	return vertices, vertexCount, subPathStarts, #paths
end

local function hashBuffer(value: buffer, length: number?): number
	local hash = 0xFFFFFFFF
	local byteLength = length or buffer.len(value)

	for offset = 0, byteLength - 1 do
		hash = bit32.bxor(hash, buffer.readu8(value, offset))

		for _ = 1, 8 do
			local polynomial = if bit32.band(hash, 1) == 1 then 0xEDB88320 else 0
			hash = bit32.bxor(bit32.rshift(hash, 1), polynomial)
		end
	end

	return bit32.bnot(hash)
end

local atlasSource = Fs.readFile("src/atlas.luau")
atlasSource = atlasSource:gsub('local Internal = require%("%./internal"%)', "local Internal = __env.Internal")
atlasSource = "local __env = ...\n"
	.. "local game, Vector2, Rect, Content = __env.game, __env.Vector2, __env.Rect, __env.Content\n"
	.. atlasSource

local atlasRenderCalls: { any } = {}
local editableImageDestroyCount = 0
local editableImageWriteCount = 0
local editableImageId = 0

local InternalMock = {
	CalcSize = function(topLeft: number, topRight: number, bottomRight: number, bottomLeft: number): (number, number)
		return math.floor(topLeft + topRight) + 2, math.floor(bottomRight + bottomLeft) + 2
	end,
	CalcSliceCenter = function(width: number, height: number): any
		return { Min = { X = 1, Y = 1 }, Max = { X = width - 1, Y = height - 1 } }
	end,
	RenderToBuffer = function(_: buffer, width: number, height: number, params: any, xOffset: number, yOffset: number)
		table.insert(atlasRenderCalls, {
			width = width,
			height = height,
			params = table.clone(params),
			xOffset = xOffset,
			yOffset = yOffset,
		})
	end,
}

local AssetServiceMock = {}

function AssetServiceMock:CreateEditableImage(options: any): any
	editableImageId += 1
	local image = { Id = editableImageId, Size = options.Size, Destroyed = false }

	function image:WritePixelsBuffer(_: any, _: any, _: buffer)
		editableImageWriteCount += 1
	end

	function image:Destroy()
		assert(not self.Destroyed, "EditableImage destroyed more than once")
		self.Destroyed = true
		editableImageDestroyCount += 1
	end

	return image
end

local AtlasModule = Luau.load(atlasSource, { debugName = "@atlas" })({
	Internal = InternalMock,
	game = {
		GetService = function(_: any, serviceName: string): any
			assert(serviceName == "AssetService")
			return AssetServiceMock
		end,
	},
	Vector2 = {
		new = function(x: number, y: number): any
			return { X = x, Y = y }
		end,
	},
	Rect = {
		new = function(...: any): any
			return { ... }
		end,
	},
	Content = {
		fromObject = function(value: any): any
			return value
		end,
	},
})

local atlasParams = {
	Start = { CornerRadius = 2, CornerSmoothing = 0.2, TopLeftRadius = 1 },
	End = { CornerRadius = 8, CornerSmoothing = 0.8, BottomRightRadius = 10 },
	Keypoints = 4,
}

local firstAtlas = AtlasModule.atlas(atlasParams)
assert(firstAtlas:GetKeypointCount() == 4)
assert(#atlasRenderCalls == 4)
assert(editableImageWriteCount == 1)

local expectedAtlasWidths = { 5, 9, 13, 18 }
local expectedAtlasHeights = { 6, 10, 15, 20 }
local expectedAtlasOffsets = { 0, 5, 14, 27 }

for index = 1, 4 do
	local keypoint = firstAtlas:GetKeypoint(index)
	local renderCall = atlasRenderCalls[index]
	local alpha = (index - 1) / 3

	assert(keypoint.ImageRectSize.X == expectedAtlasWidths[index])
	assert(keypoint.ImageRectSize.Y == expectedAtlasHeights[index])
	assert(keypoint.ImageRectOffset.X == expectedAtlasOffsets[index])
	assert(keypoint.ImageRectOffset.Y == 0)
	assert(renderCall.params.CornerRadius == 2 + (8 - 2) * alpha)
	assert(renderCall.params.CornerSmoothing == 0.2 + (0.8 - 0.2) * alpha)
	assert(renderCall.params.TopLeftRadius == 1 + (8 - 1) * alpha)
	assert(renderCall.params.TopRightRadius == 2 + (8 - 2) * alpha)
	assert(renderCall.params.BottomRightRadius == 2 + (10 - 2) * alpha)
	assert(renderCall.params.BottomLeftRadius == 2 + (8 - 2) * alpha)
end

assert(firstAtlas:GetKeypointFromAlpha(0.5) == firstAtlas:GetKeypoint(3))
local firstContent = firstAtlas:GetContent()
local secondAtlas = AtlasModule.atlas(atlasParams)
assert(AtlasModule.GetAtlasCacheSize() == 1)
assert(#atlasRenderCalls == 4, "atlas cache hit rerendered")
assert(secondAtlas:GetContent() == firstContent)

firstAtlas:Destroy()
assert(editableImageDestroyCount == 0, "shared atlas was destroyed early")
secondAtlas:Destroy()
assert(editableImageDestroyCount == 1)
assert(AtlasModule.GetAtlasCacheSize() == 0)

local flattenOps = {
	{ type = "M", x = 2.5, y = 1.25 },
	{ type = "c", dx1 = 8.25, dy1 = -1.5, dx2 = 12.5, dy2 = 9.75, dx = 17.25, dy = 11.5 },
	{ type = "a", rx = 7.5, ry = 5.25, rotation = 17, largeArc = 0, sweep = 1, dx = 8.5, dy = 9.25 },
	{ type = "L", x = 3.75, y = 27.5 },
	{ type = "Z" },
}

local baselineVertices, baselineVertexCount = Flatten(flattenOps, 1 / 8)
local reusedVertices, reusedVertexCount = Flatten(flattenOps, 1 / 8, buffer.create(4_096))
local baselineVertexHash = hashBuffer(baselineVertices, baselineVertexCount * VERTEX_STRIDE)
local reusedVertexHash = hashBuffer(reusedVertices, reusedVertexCount * VERTEX_STRIDE)

assert(baselineVertexCount == 19, `flatten vertex count changed: {baselineVertexCount}`)
assert(baselineVertexHash == 983325887, `flatten output changed: {baselineVertexHash}`)
assert(reusedVertexCount == baselineVertexCount, "flatten reuse changed the vertex count")
assert(reusedVertexHash == baselineVertexHash, "flatten reuse changed vertex output")

local drawSource = Fs.readFile("src/figma_squircle_luau/draw.luau")
drawSource = drawSource:gsub('local types = require%("%./types"%)', "local types = {}")
local Draw = Luau.load(drawSource, { debugName = "@draw" })()

local distributeSource = Fs.readFile("src/figma_squircle_luau/distribute.luau")
distributeSource = distributeSource:gsub('local types = require%("%./types"%)', "local types = {}")
local Distribute = Luau.load(distributeSource, { debugName = "@distribute" })()

local squircleSource = Fs.readFile("src/figma_squircle_luau/init.luau")
squircleSource = squircleSource:gsub('local types = require%("%./figma_squircle_luau/types"%)', "local types = {}")
squircleSource = squircleSource:gsub(
	'local distribute = require%("%./figma_squircle_luau/distribute"%)',
	"local distribute = __env.Distribute"
)
squircleSource = squircleSource:gsub('local draw = require%("%./figma_squircle_luau/draw"%)', "local draw = __env.Draw")
squircleSource = "local __env = ...\n" .. squircleSource

local Squircle = Luau.load(squircleSource, { debugName = "@squircle" })({
	Draw = Draw,
	Distribute = Distribute,
})

local function assertOpsEqual(expected: { any }, actual: { any })
	assert(#actual == #expected, `operation count changed: expected {#expected}, got {#actual}`)

	for index, expectedOp in expected do
		local actualOp = actual[index]

		for key, expectedValue in expectedOp do
			assert(actualOp[key] == expectedValue, `operation {index}.{key} changed`)
		end

		for key in actualOp do
			assert(expectedOp[key] ~= nil, `operation {index} gained field {key}`)
		end
	end
end

local squircleParams = {
	width = 96,
	height = 82,
	cornerRadius = 14,
	cornerSmoothing = 0.73,
	topLeftCornerRadius = 5,
	topRightCornerRadius = 21,
	bottomRightCornerRadius = 9,
	bottomLeftCornerRadius = 17,
	preserveSmoothing = true,
}

local baselineOps = Squircle.get_svg_path(squircleParams)
local reusedOps: { any } = {}
Squircle.get_svg_path({ width = 20, height = 20, cornerRadius = 0, cornerSmoothing = 0 }, reusedOps)
local optimizedOps = Squircle.get_svg_path(squircleParams, reusedOps)
assertOpsEqual(baselineOps, optimizedOps)

local flattenBenchmarkIterations = 5_000
local allocatingFlattenStart = os.clock()

for _ = 1, flattenBenchmarkIterations do
	Flatten(flattenOps, 1 / 8)
end

local allocatingFlattenMs = (os.clock() - allocatingFlattenStart) * 1_000
local flattenScratch = buffer.create(0)
local reusedFlattenStart = os.clock()

for _ = 1, flattenBenchmarkIterations do
	flattenScratch = Flatten(flattenOps, 1 / 8, flattenScratch)
end

local reusedFlattenMs = (os.clock() - reusedFlattenStart) * 1_000
print(
	`flatten benchmark: allocate={string.format("%.3f", allocatingFlattenMs)}ms reuse={string.format(
		"%.3f",
		reusedFlattenMs
	)}ms`
)

local function render(width: number, height: number, paths: { { Point } }, antiAlias: boolean): buffer
	local vertices, vertexCount, subPathStarts, subPathCount = writeVertices(paths)
	local pixels = buffer.create(width * height * 4)

	Rasterize(pixels, vertices, vertexCount, subPathStarts, subPathCount, width, height, 1, 1, 1, 1, antiAlias)

	return pixels
end

local fixtures = {
	{
		name = "aa_diamond",
		width = 32,
		height = 24,
		antiAlias = true,
		paths = {
			{
				{ x = 16, y = 1.25 },
				{ x = 30.5, y = 12 },
				{ x = 16, y = 22.75 },
				{ x = 1.5, y = 12 },
			},
		},
		expectedHash = 2149083181,
	},
	{
		name = "solid_asymmetric",
		width = 37,
		height = 29,
		antiAlias = false,
		paths = {
			{
				{ x = 2.25, y = 3.5 },
				{ x = 31.75, y = 1.25 },
				{ x = 35.5, y = 20.75 },
				{ x = 20.25, y = 27.5 },
				{ x = 1.5, y = 18.25 },
			},
		},
		expectedHash = 1059489459,
	},
	{
		name = "aa_two_subpaths",
		width = 40,
		height = 36,
		antiAlias = true,
		paths = {
			{
				{ x = 2.25, y = 2.25 },
				{ x = 37.75, y = 2.25 },
				{ x = 37.75, y = 33.75 },
				{ x = 2.25, y = 33.75 },
			},
			{
				{ x = 11.5, y = 10.5 },
				{ x = 11.5, y = 25.5 },
				{ x = 28.5, y = 25.5 },
				{ x = 28.5, y = 10.5 },
			},
		},
		expectedHash = 3522125040,
	},
}

for _, fixture in fixtures do
	local first = render(fixture.width, fixture.height, fixture.paths, fixture.antiAlias)
	local second = render(fixture.width, fixture.height, fixture.paths, fixture.antiAlias)
	local actualHash = hashBuffer(first)

	assert(buffer.tostring(first) == buffer.tostring(second), `{fixture.name} is not deterministic`)

	if fixture.expectedHash == 0 then
		print(`{fixture.name}: {actualHash}`)
	else
		assert(
			actualHash == fixture.expectedHash,
			`{fixture.name} changed: expected {fixture.expectedHash}, got {actualHash}`
		)
	end
end

local benchmarkFixture = fixtures[1]
local benchmarkVertices, benchmarkVertexCount, benchmarkSubPathStarts, benchmarkSubPathCount =
	writeVertices(benchmarkFixture.paths)
local benchmarkPixels = buffer.create(benchmarkFixture.width * benchmarkFixture.height * 4)
local benchmarkIterations = 2_000
local benchmarkStart = os.clock()

for _ = 1, benchmarkIterations do
	Rasterize(
		benchmarkPixels,
		benchmarkVertices,
		benchmarkVertexCount,
		benchmarkSubPathStarts,
		benchmarkSubPathCount,
		benchmarkFixture.width,
		benchmarkFixture.height,
		1,
		1,
		1,
		1,
		benchmarkFixture.antiAlias
	)
end

local benchmarkElapsedMs = (os.clock() - benchmarkStart) * 1_000
print(`raster benchmark: {benchmarkIterations} renders in {string.format("%.3f", benchmarkElapsedMs)}ms`)
