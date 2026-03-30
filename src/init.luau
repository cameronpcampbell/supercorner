--!strict

const figma_squircle = require("@self/figma_squircle_luau")
const flatten_mod = require("@self/flatten")
const rasterize_mod = require("@self/rasterize")

export type SquircleParams = {
	image: EditableImage,
	width: number,
	height: number,
	cornerRadius: number,
	cornerSmoothing: number,
	color: Color3,
	transparency: number?,
	topLeftCornerRadius: number?,
	topRightCornerRadius: number?,
	bottomRightCornerRadius: number?,
	bottomLeftCornerRadius: number?,
	preserveSmoothing: boolean?,
}

const function draw_squircle(params: SquircleParams)
	const width = params.width
	const height = params.height
	const color = params.color
	const transparency = params.transparency or 0

	const ops = figma_squircle.get_svg_path({
		width = width,
		height = height,
		cornerRadius = params.cornerRadius,
		cornerSmoothing = params.cornerSmoothing,
		topLeftCornerRadius = params.topLeftCornerRadius,
		topRightCornerRadius = params.topRightCornerRadius,
		bottomRightCornerRadius = params.bottomRightCornerRadius,
		bottomLeftCornerRadius = params.bottomLeftCornerRadius,
		preserveSmoothing = params.preserveSmoothing,
	})

	const vertices, vertex_count = flatten_mod.flatten(ops)

	const pixel_buf = rasterize_mod.rasterize(
		vertices,
		vertex_count,
		width,
		height,
		color.R,
		color.G,
		color.B,
		1 - transparency
	)

	params.image:WritePixelsBuffer(
		Vector2.new(0, 0),
		Vector2.new(width, height),
		pixel_buf
	)
end

return {
	draw_squircle = draw_squircle,
}
