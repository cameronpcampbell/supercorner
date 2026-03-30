--!strict

const types = require("./types")

type CornerPathParams = types.CornerPathParams
type CornerParams = types.CornerParams
type SvgOp = types.SvgOp

type SvgPathInput = {
	width: number,
	height: number,
	top_left_path_params: CornerPathParams,
	top_right_path_params: CornerPathParams,
	bottom_right_path_params: CornerPathParams,
	bottom_left_path_params: CornerPathParams,
}

const function get_path_params_for_corner(params: CornerParams): CornerPathParams
	const corner_radius = params.cornerRadius
	local corner_smoothing = params.cornerSmoothing
	const preserve_smoothing = params.preserveSmoothing
	const rounding_and_smoothing_budget = params.roundingAndSmoothingBudget

	local p = (1.0 + corner_smoothing) * corner_radius

	if not preserve_smoothing then
		const max_corner_smoothing = rounding_and_smoothing_budget / corner_radius - 1.0
		corner_smoothing = math.min(corner_smoothing, max_corner_smoothing)
		p = math.min(p, rounding_and_smoothing_budget)
	end

	const arc_measure = 90.0 * (1.0 - corner_smoothing)
	const arc_section_length = math.sin(math.rad(arc_measure / 2.0)) * corner_radius * math.sqrt(2)

	const angle_alpha = (90.0 - arc_measure) / 2.0
	const p3_to_p4_distance = corner_radius * math.tan(math.rad(angle_alpha / 2.0))
	const angle_beta = 45.0 * corner_smoothing
	const c = p3_to_p4_distance * math.cos(math.rad(angle_beta))
	const d = c * math.tan(math.rad(angle_beta))

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

const function top_right_ops(pp: CornerPathParams): { SvgOp }
	if pp.cornerRadius == 0 then
		return {}
	end

	return {
		{
			type = "c" :: "c",
			dx1 = pp.a,
			dy1 = 0,
			dx2 = pp.a + pp.b,
			dy2 = 0,
			dx = pp.a + pp.b + pp.c,
			dy = pp.d,
		},

		{
			type = "a" :: "a",
			rx = pp.cornerRadius,
			ry = pp.cornerRadius,
			rotation = 0,
			largeArc = 0,
			sweep = 1,
			dx = pp.arcSectionLength,
			dy = pp.arcSectionLength,
		} :: SvgOp,

		{
			type = "c" :: "c",
			dx1 = pp.d,
			dy1 = pp.c,
			dx2 = pp.d,
			dy2 = pp.c + pp.b,
			dx = pp.d,
			dy = pp.c + pp.b + pp.a,
		},
	}
end

const function bottom_right_ops(pp: CornerPathParams): { SvgOp }
	if pp.cornerRadius == 0 then
		return {}
	end

	return {
		{
			type = "c" :: "c",
			dx1 = 0,
			dy1 = pp.a,
			dx2 = 0,
			dy2 = pp.a + pp.b,
			dx = -pp.d,
			dy = pp.a + pp.b + pp.c,
		},

		{
			type = "a" :: "a",
			rx = pp.cornerRadius,
			ry = pp.cornerRadius,
			rotation = 0,
			largeArc = 0,
			sweep = 1,
			dx = -pp.arcSectionLength,
			dy = pp.arcSectionLength,
		} :: SvgOp,

		{
			type = "c" :: "c",
			dx1 = -pp.c,
			dy1 = pp.d,
			dx2 = -(pp.c + pp.b),
			dy2 = pp.d,
			dx = -(pp.c + pp.b + pp.a),
			dy = pp.d,
		},
	}
end

const function bottom_left_ops(pp: CornerPathParams): { SvgOp }
	if pp.cornerRadius == 0 then
		return {}
	end

	return {
		{
			type = "c" :: "c",
			dx1 = -pp.a,
			dy1 = 0,
			dx2 = -(pp.a + pp.b),
			dy2 = 0,
			dx = -(pp.a + pp.b + pp.c),
			dy = -pp.d,
		},

		{
			type = "a" :: "a",
			rx = pp.cornerRadius,
			ry = pp.cornerRadius,
			rotation = 0,
			largeArc = 0,
			sweep = 1,
			dx = -pp.arcSectionLength,
			dy = -pp.arcSectionLength,
		} :: SvgOp,

		{
			type = "c" :: "c",
			dx1 = -pp.d,
			dy1 = -pp.c,
			dx2 = -pp.d,
			dy2 = -(pp.c + pp.b),
			dx = -pp.d,
			dy = -(pp.c + pp.b + pp.a),
		},
	}
end

const function top_left_ops(pp: CornerPathParams): { SvgOp }
	if pp.cornerRadius == 0 then
		return {}
	end

	return {
		{
			type = "c" :: "c",
			dx1 = 0,
			dy1 = -pp.a,
			dx2 = 0,
			dy2 = -(pp.a + pp.b),
			dx = pp.d,
			dy = -(pp.a + pp.b + pp.c),
		},

		{
			type = "a" :: "a",
			rx = pp.cornerRadius,
			ry = pp.cornerRadius,
			rotation = 0,
			largeArc = 0,
			sweep = 1,
			dx = pp.arcSectionLength,
			dy = -pp.arcSectionLength,
		} :: SvgOp,

		{
			type = "c" :: "c",
			dx1 = pp.c,
			dy1 = -pp.d,
			dx2 = pp.c + pp.b,
			dy2 = -pp.d,
			dx = pp.c + pp.b + pp.a,
			dy = -pp.d,
		},
	}
end

const function get_svg_ops(input: SvgPathInput): { SvgOp }
	const width = input.width
	const height = input.height
	const tl = input.top_left_path_params
	const tr = input.top_right_path_params
	const br = input.bottom_right_path_params
	const bl = input.bottom_left_path_params

	local ops: { SvgOp } = table.create(21)

	table.insert(ops, {
		type = "M" :: "M",
		x = tl.p,
		y = 0,
	})

	table.insert(ops, {
		type = "L" :: "L",
		x = width - tr.p,
		y = 0,
	})

	const tr_ops = top_right_ops(tr)
	table.move(tr_ops, 1, #tr_ops, #ops + 1, ops)

	table.insert(ops, {
		type = "L" :: "L",
		x = width,
		y = height - br.p,
	})

	const br_ops = bottom_right_ops(br)
	table.move(br_ops, 1, #br_ops, #ops + 1, ops)

	table.insert(ops, {
		type = "L" :: "L",
		x = bl.p,
		y = height,
	})

	const bl_ops = bottom_left_ops(bl)
	table.move(bl_ops, 1, #bl_ops, #ops + 1, ops)

	table.insert(ops, {
		type = "L" :: "L",
		x = 0,
		y = tl.p,
	})

	const tl_ops = top_left_ops(tl)
	table.move(tl_ops, 1, #tl_ops, #ops + 1, ops)

	table.insert(ops, { type = "Z" :: "Z" })

	return ops
end

return {
	get_path_params_for_corner = get_path_params_for_corner,
	get_svg_ops = get_svg_ops,
}
