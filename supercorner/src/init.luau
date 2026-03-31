--!strict

const FigmaSquircle = require("@self/figma_squircle_luau")
const Flatten = require("@self/flatten")
const Rasterize = require("@self/rasterize")

const AssetService = game:GetService("AssetService")

export type CreateParams = {
	Width: number,
	Height: number,
	CornerRadius: number,
	CornerSmoothing: number,
	TopLeftCornerRadius: number?,
	TopRightCornerRadius: number?,
	BottomRightCornerRadius: number?,
	BottomLeftCornerRadius: number?,
	PreserveSmoothing: boolean?,
	AntiAlias: boolean?
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
	const tolerance = if antiAlias then 1/4 else 1/2
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

const function new(params: CreateParams): Squircle
	const width, height = params.Width * 2, params.Height * 2

	local state: SquircleState = {
		EImage = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) }),
		PixelBuf = buffer.create(width * height * 4),
		Width = width,
		Height = height,
	}

	render(state, params)

	const squircle: Squircle = {
		Redraw = function(self: Squircle, new_params: RedrawParams)
			render(state, new_params)
		end,

		GetContent = function(self: Squircle): Content
			return Content.fromObject(state.EImage)
		end,

		Destroy = function(self: Squircle)
			state.EImage:Destroy()
		end,
	}

	return squircle
end

return {
	new = new,
}
