--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SupercornerModule = ReplicatedStorage:WaitForChild("supercorner")
local Supercorner = require(SupercornerModule)
local Internal = require(SupercornerModule:WaitForChild("internal"))

local function render(params: Internal.RedrawParams): string
	local width, height = Internal.CalcSize(
		params.TopLeftRadius or params.CornerRadius or 0,
		params.TopRightRadius or params.CornerRadius or 0,
		params.BottomRightRadius or params.CornerRadius or 0,
		params.BottomLeftRadius or params.CornerRadius or 0,
		params.Stroke
	)
	local pixels = buffer.create(width * height * 4)
	Internal.RenderToBuffer(pixels, width, height, params)
	return buffer.tostring(pixels)
end

local filledParams: Internal.RedrawParams = {
	CornerRadius = 18,
	CornerSmoothing = 0.72,
	TopLeftRadius = 7,
	TopRightRadius = 23,
	BottomRightRadius = 12,
	BottomLeftRadius = 29,
}
local strokedParams: Internal.RedrawParams = {
	CornerRadius = 24,
	CornerSmoothing = 0.9,
	TopLeftRadius = 14,
	TopRightRadius = 31,
	BottomRightRadius = 19,
	BottomLeftRadius = 8,
	Stroke = 4,
}

local firstFilled = render(filledParams)
local firstStroke = render(strokedParams)
assert(render(filledParams) == firstFilled, "filled render changed after scratch-buffer reuse")
assert(render(strokedParams) == firstStroke, "stroke render changed after scratch-buffer reuse")

local initialCacheSize = Supercorner.GetCacheSize()
local first = Supercorner.new({
	CornerRadius = 12,
	CornerSmoothing = 0.65,
	MaxCornerRadius = 24,
	Redrawable = true,
})

assert(Supercorner.GetCacheSize() == initialCacheSize + 1)

first:Redraw({
	CornerRadius = 18,
	CornerSmoothing = 0.65,
})

assert(Supercorner.GetCacheSize() == initialCacheSize + 2, "redraw history was not retained")

first:Redraw({
	CornerRadius = 12,
	CornerSmoothing = 0.65,
})

assert(Supercorner.GetCacheSize() == initialCacheSize + 2, "redraw did not reuse the previous cache key")
first:Destroy()

task.wait(9.5)
assert(Supercorner.GetCacheSize() == initialCacheSize + 2, "cache entry expired before ten seconds")

task.wait(1)
assert(Supercorner.GetCacheSize() == initialCacheSize, "cache entry did not expire after ten seconds")

local retained = Supercorner.new({
	CornerRadius = 15,
	CornerSmoothing = 0.4,
	Redrawable = true,
})
retained:Destroy()
task.wait(5)

local reused = Supercorner.new({
	CornerRadius = 15,
	CornerSmoothing = 0.4,
	Redrawable = true,
})

task.wait(5.5)
assert(Supercorner.GetCacheSize() == initialCacheSize + 1, "cache re-entry did not cancel expiration")
reused:Destroy()

task.wait(10.5)
assert(Supercorner.GetCacheSize() == initialCacheSize, "reused cache entry did not receive a fresh grace period")

print("[optimization test] render parity and 10-second cache lifecycle passed")
return true
