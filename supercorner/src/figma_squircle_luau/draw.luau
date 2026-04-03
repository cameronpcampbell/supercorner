--!strict

const types = require("./types")

type CornerPathParams = types.CornerPathParams
type SvgOp = types.SvgOp

type SvgPathInput = {
	width: number,
	height: number,
	top_left_path_params: CornerPathParams,
	top_right_path_params: CornerPathParams,
	bottom_right_path_params: CornerPathParams,
	bottom_left_path_params: CornerPathParams,
}

const function get_path_params_for_corner(
	corner_radius: number,
	corner_smoothing: number,
	preserve_smoothing: boolean,
	rounding_and_smoothing_budget: number
): CornerPathParams
	local smoothing = corner_smoothing

	local p = (1.0 + smoothing) * corner_radius

	if not preserve_smoothing then
		const max_corner_smoothing = rounding_and_smoothing_budget / corner_radius - 1.0
		smoothing = math.min(smoothing, max_corner_smoothing)
		p = math.min(p, rounding_and_smoothing_budget)
	end

	const arc_measure = 90.0 * (1.0 - smoothing)
	const arcMeasureHalfRad = math.rad(arc_measure / 2.0)
	const arc_section_length = math.sin(arcMeasureHalfRad) * corner_radius * math.sqrt(2)

	const angle_alpha = (90.0 - arc_measure) / 2.0
	const angleAlphaHalfRad = math.rad(angle_alpha / 2.0)
	const p3_to_p4_distance = corner_radius * math.tan(angleAlphaHalfRad)
	const angleBetaRad = math.rad(45.0 * smoothing)
	const c = p3_to_p4_distance * math.cos(angleBetaRad)
	const d = c * math.tan(angleBetaRad)

	local b = (p - arc_section_length - c - d) / 3.0
	local a = 2.0 * b

	if preserve_smoothing and p > rounding_and_smoothing_budget then
		const p1_to_p3_max_distance = rounding_and_smoothing_budget - d - arc_section_length - c
		const min_a = p1_to_p3_max_distance / 6.0
		const max_b = p1_to_p3_max_distance - min_a
		b = math.min(b, max_b)
		a = p1_to_p3_max_distance - b
		p = math.min(p, rounding_and_smoothing_budget)
	end

	return {
		a = a,
		b = b,
		c = c,
		d = d,
		p = p,
		cornerRadius = corner_radius,
		arcSectionLength = arc_section_length,
	}
end

-- Inserts the 3 corner ops (cubic, arc, cubic) directly into the ops array.
-- Each corner has a unique sign pattern applied to (a, b, c, d, arcSectionLength).
local function insert_corner_ops(ops: { SvgOp }, pp: CornerPathParams, corner: number)
	if pp.cornerRadius == 0 then
		return
	end

	local a, b, c, d = pp.a, pp.b, pp.c, pp.d
	local arc = pp.arcSectionLength
	local r = pp.cornerRadius
	local ab = a + b
	local abc = ab + c
	local cb = c + b
	local cba = cb + a

	if corner == 1 then -- top right
		table.insert(ops, { type = "c" :: "c", dx1 = a, dy1 = 0, dx2 = ab, dy2 = 0, dx = abc, dy = d })
		table.insert(ops, { type = "a" :: "a", rx = r, ry = r, rotation = 0, largeArc = 0, sweep = 1, dx = arc, dy = arc } :: SvgOp)
		table.insert(ops, { type = "c" :: "c", dx1 = d, dy1 = c, dx2 = d, dy2 = cb, dx = d, dy = cba })

	elseif corner == 2 then -- bottom right
		table.insert(ops, { type = "c" :: "c", dx1 = 0, dy1 = a, dx2 = 0, dy2 = ab, dx = -d, dy = abc })
		table.insert(ops, { type = "a" :: "a", rx = r, ry = r, rotation = 0, largeArc = 0, sweep = 1, dx = -arc, dy = arc } :: SvgOp)
		table.insert(ops, { type = "c" :: "c", dx1 = -c, dy1 = d, dx2 = -cb, dy2 = d, dx = -cba, dy = d })

	elseif corner == 3 then -- bottom left
		table.insert(ops, { type = "c" :: "c", dx1 = -a, dy1 = 0, dx2 = -ab, dy2 = 0, dx = -abc, dy = -d })
		table.insert(ops, { type = "a" :: "a", rx = r, ry = r, rotation = 0, largeArc = 0, sweep = 1, dx = -arc, dy = -arc } :: SvgOp)
		table.insert(ops, { type = "c" :: "c", dx1 = -d, dy1 = -c, dx2 = -d, dy2 = -cb, dx = -d, dy = -cba })

	else -- top left
		table.insert(ops, { type = "c" :: "c", dx1 = 0, dy1 = -a, dx2 = 0, dy2 = -ab, dx = d, dy = -abc })
		table.insert(ops, { type = "a" :: "a", rx = r, ry = r, rotation = 0, largeArc = 0, sweep = 1, dx = arc, dy = -arc } :: SvgOp)
		table.insert(ops, { type = "c" :: "c", dx1 = c, dy1 = -d, dx2 = cb, dy2 = -d, dx = cba, dy = -d })
	end
end

const function get_svg_ops(input: SvgPathInput): { SvgOp }
	const width = input.width
	const height = input.height
	const tl = input.top_left_path_params
	const tr = input.top_right_path_params
	const br = input.bottom_right_path_params
	const bl = input.bottom_left_path_params

	local ops: { SvgOp } = table.create(21) :: { SvgOp }

	table.insert(ops, { type = "M" :: "M", x = tl.p, y = 0 })
	table.insert(ops, { type = "L" :: "L", x = width - tr.p, y = 0 })
	insert_corner_ops(ops, tr, 1)

	table.insert(ops, { type = "L" :: "L", x = width, y = height - br.p })
	insert_corner_ops(ops, br, 2)

	table.insert(ops, { type = "L" :: "L", x = bl.p, y = height })
	insert_corner_ops(ops, bl, 3)

	table.insert(ops, { type = "L" :: "L", x = 0, y = tl.p })
	insert_corner_ops(ops, tl, 4)

	table.insert(ops, { type = "Z" :: "Z" })

	return ops
end

return {
	get_path_params_for_corner = get_path_params_for_corner,
	get_svg_ops = get_svg_ops,
}
