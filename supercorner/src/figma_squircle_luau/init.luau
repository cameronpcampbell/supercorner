--!strict

const types = require("@self/types")
const distribute = require("@self/distribute")
const draw = require("@self/draw")

export type FigmaSquircleParams = types.FigmaSquircleParams
export type SvgOp = types.SvgOp
export type CornerParams = types.CornerParams

const function get_svg_path(params: FigmaSquircleParams): { SvgOp }
	const width = params.width
	const height = params.height
	const corner_smoothing = params.cornerSmoothing
	const preserve_smoothing = if params.preserveSmoothing then params.preserveSmoothing else false
	const default_radius = params.cornerRadius or 0

	const tl_radius = params.topLeftCornerRadius or default_radius
	const tr_radius = params.topRightCornerRadius or default_radius
	const br_radius = params.bottomRightCornerRadius or default_radius
	const bl_radius = params.bottomLeftCornerRadius or default_radius

	const all_equal = tl_radius == tr_radius and tr_radius == br_radius and br_radius == bl_radius

	if all_equal then
		const normalized = distribute.distribute_and_normalize(
			width, height, tl_radius, tr_radius, br_radius, bl_radius
		)

		const corner_params: CornerParams = {
			cornerRadius = normalized.topLeft.radius,
			cornerSmoothing = corner_smoothing,
			preserveSmoothing = preserve_smoothing,
			roundingAndSmoothingBudget = normalized.topLeft.roundingAndSmoothingBudget,
		}

		const path_params = draw.get_path_params_for_corner(corner_params)

		return draw.get_svg_ops({
			width = width,
			height = height,
			top_left_path_params = path_params,
			top_right_path_params = path_params,
			bottom_right_path_params = path_params,
			bottom_left_path_params = path_params,
		})
	end

	const normalized = distribute.distribute_and_normalize(
		width, height, tl_radius, tr_radius, br_radius, bl_radius
	)

	const tl_path_params = draw.get_path_params_for_corner({
		cornerRadius = normalized.topLeft.radius,
		cornerSmoothing = corner_smoothing,
		preserveSmoothing = preserve_smoothing,
		roundingAndSmoothingBudget = normalized.topLeft.roundingAndSmoothingBudget,
	})

	const tr_path_params = draw.get_path_params_for_corner({
		cornerRadius = normalized.topRight.radius,
		cornerSmoothing = corner_smoothing,
		preserveSmoothing = preserve_smoothing,
		roundingAndSmoothingBudget = normalized.topRight.roundingAndSmoothingBudget,
	})

	const br_path_params = draw.get_path_params_for_corner({
		cornerRadius = normalized.bottomRight.radius,
		cornerSmoothing = corner_smoothing,
		preserveSmoothing = preserve_smoothing,
		roundingAndSmoothingBudget = normalized.bottomRight.roundingAndSmoothingBudget,
	})

	const bl_path_params = draw.get_path_params_for_corner({
		cornerRadius = normalized.bottomLeft.radius,
		cornerSmoothing = corner_smoothing,
		preserveSmoothing = preserve_smoothing,
		roundingAndSmoothingBudget = normalized.bottomLeft.roundingAndSmoothingBudget,
	})

	return draw.get_svg_ops({
		width = width,
		height = height,
		top_left_path_params = tl_path_params,
		top_right_path_params = tr_path_params,
		bottom_right_path_params = br_path_params,
		bottom_left_path_params = bl_path_params,
	})
end

return {
	get_svg_path = get_svg_path,
}
