--!strict

const figma_squircle = require("@self/figma_squircle_luau")
const flatten_mod = require("@self/flatten")
const rasterize_mod = require("@self/rasterize")

local AssetService = game:GetService("AssetService")

export type CreateParams = {
	width: number,
	height: number,
	cornerRadius: number,
	cornerSmoothing: number,
	topLeftCornerRadius: number?,
	topRightCornerRadius: number?,
	bottomRightCornerRadius: number?,
	bottomLeftCornerRadius: number?,
	preserveSmoothing: boolean?,
	antiAlias: boolean?,
}

export type RedrawParams = {
	cornerRadius: number,
	cornerSmoothing: number,
	topLeftCornerRadius: number?,
	topRightCornerRadius: number?,
	bottomRightCornerRadius: number?,
	bottomLeftCornerRadius: number?,
	preserveSmoothing: boolean?,
	antiAlias: boolean?,
}

export type Squircle = {
	redraw: (self: Squircle, params: RedrawParams) -> (),
	get_image: (self: Squircle) -> EditableImage,
	get_content: (self: Squircle) -> Content,
	destroy: (self: Squircle) -> (),
}

type SquircleState = {
	_image: EditableImage,
	_pixel_buf: buffer,
	_width: number,
	_height: number,
}

const function render(state: SquircleState, params: RedrawParams)
	const width = state._width
	const height = state._height

	-- Currently theres an issue with corners becoming degenerate under certain
	-- conditions. I've found that one of the variables in this issue occuring
	-- is the corner smoothing being `1`. So by clamping to some value just before
	-- that we can mitigate this issue whilst still perceptually allowing for a
	-- smoothing factor of `1`.
	local clamped_smoothing = math.min(params.cornerSmoothing, 1 - 1e-6)

	const ops = figma_squircle.get_svg_path({
		width = width,
		height = height,
		cornerRadius = params.cornerRadius * 2,
		cornerSmoothing = clamped_smoothing,
		topLeftCornerRadius = if params.topLeftCornerRadius then params.topLeftCornerRadius * 2 else nil,
		topRightCornerRadius = if params.topRightCornerRadius then params.topRightCornerRadius * 2 else nil,
		bottomRightCornerRadius = if params.bottomRightCornerRadius then params.bottomRightCornerRadius * 2 else nil,
		bottomLeftCornerRadius = if params.bottomLeftCornerRadius then params.bottomLeftCornerRadius * 2 else nil,
		preserveSmoothing = params.preserveSmoothing,
	})

	const anti_alias = if params.antiAlias ~= nil then params.antiAlias else true
	const tolerance = if anti_alias then 1/4 else 1/2
	const vertices, vertex_count = flatten_mod.flatten(ops, tolerance)

	buffer.fill(state._pixel_buf, 0, 0)

	rasterize_mod.rasterize_into(
		state._pixel_buf,
		vertices,
		vertex_count,
		width,
		height,
		1, 1, 1, 1,
		anti_alias
	)

	state._image:WritePixelsBuffer(
		Vector2.new(0, 0),
		Vector2.new(width, height),
		state._pixel_buf
	)
end

const function create(params: CreateParams): Squircle
	const width = params.width * 2
	const height = params.height * 2

	local state: SquircleState = {
		_image = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) }),
		_pixel_buf = buffer.create(width * height * 4),
		_width = width,
		_height = height,
	}

	render(state, params)

	const squircle: Squircle = {
		redraw = function(self: Squircle, new_params: RedrawParams)
			render(state, new_params)
		end,

		get_image = function(self: Squircle): EditableImage
			return state._image
		end,

		get_content = function(self: Squircle): Content
			return Content.fromObject(state._image)
		end,

		destroy = function(self: Squircle)
			state._image:Destroy()
		end,
	}

	return squircle
end

return {
	create = create,
}
