--!strict

local types = require("./figma_squircle_luau/types")
local distribute = require("./figma_squircle_luau/distribute")
local draw = require("./figma_squircle_luau/draw")

export type FigmaSquircleParams = types.FigmaSquircleParams
export type SvgOp = types.SvgOp

local CornerParamsScratch: { types.CornerPathParams } = {
	{ a = 0, b = 0, c = 0, d = 0, p = 0, cornerRadius = 0, arcSectionLength = 0 },
	{ a = 0, b = 0, c = 0, d = 0, p = 0, cornerRadius = 0, arcSectionLength = 0 },
	{ a = 0, b = 0, c = 0, d = 0, p = 0, cornerRadius = 0, arcSectionLength = 0 },
	{ a = 0, b = 0, c = 0, d = 0, p = 0, cornerRadius = 0, arcSectionLength = 0 },
}

local function get_svg_path(params: FigmaSquircleParams, reuse_ops: { SvgOp }?): { SvgOp }
	local width = params.width
	local height = params.height
	local corner_smoothing = params.cornerSmoothing
	local preserve_smoothing = if params.preserveSmoothing then params.preserveSmoothing else false
	local default_radius = params.cornerRadius or 0

	local tl_radius = params.topLeftCornerRadius or default_radius
	local tr_radius = params.topRightCornerRadius or default_radius
	local br_radius = params.bottomRightCornerRadius or default_radius
	local bl_radius = params.bottomLeftCornerRadius or default_radius

	local all_equal = tl_radius == tr_radius and tr_radius == br_radius and br_radius == bl_radius

	if all_equal then
		local budget = math.min(width, height) / 2
		local radius = math.min(tl_radius, budget)

		local path_params = draw.get_path_params_for_corner(
			radius, corner_smoothing, preserve_smoothing, budget, CornerParamsScratch[1]
		)

		return draw.get_svg_ops({
			width = width,
			height = height,
			top_left_path_params = path_params,
			top_right_path_params = path_params,
			bottom_right_path_params = path_params,
			bottom_left_path_params = path_params,
		}, reuse_ops)
	end

	local normalized = distribute.distribute_and_normalize(
		width, height, tl_radius, tr_radius, br_radius, bl_radius
	)

	local tl_path_params = draw.get_path_params_for_corner(
		normalized.topLeft.radius, corner_smoothing, preserve_smoothing,
		normalized.topLeft.roundingAndSmoothingBudget, CornerParamsScratch[1]
	)

	local tr_path_params = draw.get_path_params_for_corner(
		normalized.topRight.radius, corner_smoothing, preserve_smoothing,
		normalized.topRight.roundingAndSmoothingBudget, CornerParamsScratch[2]
	)

	local br_path_params = draw.get_path_params_for_corner(
		normalized.bottomRight.radius, corner_smoothing, preserve_smoothing,
		normalized.bottomRight.roundingAndSmoothingBudget, CornerParamsScratch[3]
	)

	local bl_path_params = draw.get_path_params_for_corner(
		normalized.bottomLeft.radius, corner_smoothing, preserve_smoothing,
		normalized.bottomLeft.roundingAndSmoothingBudget, CornerParamsScratch[4]
	)

	return draw.get_svg_ops({
		width = width,
		height = height,
		top_left_path_params = tl_path_params,
		top_right_path_params = tr_path_params,
		bottom_right_path_params = br_path_params,
		bottom_left_path_params = bl_path_params,
	}, reuse_ops)
end

return {
	get_svg_path = get_svg_path,
}
