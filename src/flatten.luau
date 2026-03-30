--!strict

const squircle_types = require(script.Parent.figma_squircle_luau)

type SvgOp = squircle_types.SvgOp

const VERTEX_STRIDE = 8
const INITIAL_CAPACITY = 128

const function create_vertex_buf(capacity: number): buffer
	return buffer.create(capacity * VERTEX_STRIDE)
end

const function flatten(ops: { SvgOp }, tolerance: number): (buffer, number)
	local capacity = INITIAL_CAPACITY
	local buf = create_vertex_buf(capacity)
	local count = 0

	local cur_x = 0.0
	local cur_y = 0.0
	local start_x = 0.0
	local start_y = 0.0

	const function emit(x: number, y: number)
		if count >= capacity then
			const old_buf = buf
			capacity *= 2
			buf = create_vertex_buf(capacity)
			buffer.copy(buf, 0, old_buf, 0, count * VERTEX_STRIDE)
		end

		const offset = count * VERTEX_STRIDE
		buffer.writef32(buf, offset, x)
		buffer.writef32(buf, offset + 4, y)
		count += 1
		cur_x = x
		cur_y = y
	end

	const tol_sq = tolerance * tolerance
	const MAX_DEPTH = 16

	-- Iterative De Casteljau with explicit buffer stack
	-- Each stack entry: x0 y0 x1 y1 x2 y2 x3 y3 depth (9 floats = 36 bytes)
	const STACK_STRIDE = 36
	const stack_buf = buffer.create(MAX_DEPTH * 2 * STACK_STRIDE)

	const function flatten_cubic(
		sx0: number, sy0: number,
		sx1: number, sy1: number,
		sx2: number, sy2: number,
		sx3: number, sy3: number
	)
		local sp = 0
		-- Push initial curve
		buffer.writef32(stack_buf, 0, sx0)
		buffer.writef32(stack_buf, 4, sy0)
		buffer.writef32(stack_buf, 8, sx1)
		buffer.writef32(stack_buf, 12, sy1)
		buffer.writef32(stack_buf, 16, sx2)
		buffer.writef32(stack_buf, 20, sy2)
		buffer.writef32(stack_buf, 24, sx3)
		buffer.writef32(stack_buf, 28, sy3)
		buffer.writef32(stack_buf, 32, 0)
		sp = 1

		while sp > 0 do
			sp -= 1
			const base = sp * STACK_STRIDE
			const x0 = buffer.readf32(stack_buf, base)
			const y0 = buffer.readf32(stack_buf, base + 4)
			const x1 = buffer.readf32(stack_buf, base + 8)
			const y1 = buffer.readf32(stack_buf, base + 12)
			const x2 = buffer.readf32(stack_buf, base + 16)
			const y2 = buffer.readf32(stack_buf, base + 20)
			const x3 = buffer.readf32(stack_buf, base + 24)
			const y3 = buffer.readf32(stack_buf, base + 28)
			const depth = buffer.readf32(stack_buf, base + 32)

			const dx = x3 - x0
			const dy = y3 - y0
			const d_sq = dx * dx + dy * dy

			if d_sq < 1e-10 then
				emit(x3, y3)
				continue
			end

			const inv_d_sq = 1.0 / d_sq

			const t1 = ((x1 - x0) * dx + (y1 - y0) * dy) * inv_d_sq
			const px1 = x0 + t1 * dx - x1
			const py1 = y0 + t1 * dy - y1
			const d1_sq = px1 * px1 + py1 * py1

			const t2 = ((x2 - x0) * dx + (y2 - y0) * dy) * inv_d_sq
			const px2 = x0 + t2 * dx - x2
			const py2 = y0 + t2 * dy - y2
			const d2_sq = px2 * px2 + py2 * py2

			if (d1_sq <= tol_sq and d2_sq <= tol_sq) or depth >= MAX_DEPTH then
				emit(x3, y3)
				continue
			end

			const m01x = (x0 + x1) * 0.5
			const m01y = (y0 + y1) * 0.5
			const m12x = (x1 + x2) * 0.5
			const m12y = (y1 + y2) * 0.5
			const m23x = (x2 + x3) * 0.5
			const m23y = (y2 + y3) * 0.5

			const m012x = (m01x + m12x) * 0.5
			const m012y = (m01y + m12y) * 0.5
			const m123x = (m12x + m23x) * 0.5
			const m123y = (m12y + m23y) * 0.5

			const mx = (m012x + m123x) * 0.5
			const my = (m012y + m123y) * 0.5

			-- Push right half first (processed second = correct order)
			const r_base = sp * STACK_STRIDE
			buffer.writef32(stack_buf, r_base, mx)
			buffer.writef32(stack_buf, r_base + 4, my)
			buffer.writef32(stack_buf, r_base + 8, m123x)
			buffer.writef32(stack_buf, r_base + 12, m123y)
			buffer.writef32(stack_buf, r_base + 16, m23x)
			buffer.writef32(stack_buf, r_base + 20, m23y)
			buffer.writef32(stack_buf, r_base + 24, x3)
			buffer.writef32(stack_buf, r_base + 28, y3)
			buffer.writef32(stack_buf, r_base + 32, depth + 1)
			sp += 1

			-- Push left half second (processed first)
			const l_base = sp * STACK_STRIDE
			buffer.writef32(stack_buf, l_base, x0)
			buffer.writef32(stack_buf, l_base + 4, y0)
			buffer.writef32(stack_buf, l_base + 8, m01x)
			buffer.writef32(stack_buf, l_base + 12, m01y)
			buffer.writef32(stack_buf, l_base + 16, m012x)
			buffer.writef32(stack_buf, l_base + 20, m012y)
			buffer.writef32(stack_buf, l_base + 24, mx)
			buffer.writef32(stack_buf, l_base + 28, my)
			buffer.writef32(stack_buf, l_base + 32, depth + 1)
			sp += 1
		end
	end

	-- SVG endpoint-to-center arc conversion (per SVG spec F.6.5–F.6.6)
	const function flatten_arc(
		cx: number, cy: number,
		rx: number, ry: number,
		rotation: number,
		large_arc: number, sweep: number,
		dx: number, dy: number
	)
		const x1 = cx
		const y1 = cy
		const x2 = cx + dx
		const y2 = cy + dy

		if dx == 0 and dy == 0 then
			return
		end

		rx = math.abs(rx)
		ry = math.abs(ry)

		if rx < 1e-10 or ry < 1e-10 then
			emit(x2, y2)
			return
		end

		const cos_phi = math.cos(math.rad(rotation))
		const sin_phi = math.sin(math.rad(rotation))

		const hdx = (x1 - x2) * 0.5
		const hdy = (y1 - y2) * 0.5
		const x1p = cos_phi * hdx + sin_phi * hdy
		const y1p = -sin_phi * hdx + cos_phi * hdy

		const x1p_sq = x1p * x1p
		const y1p_sq = y1p * y1p
		local rx_sq = rx * rx
		local ry_sq = ry * ry

		const lambda = x1p_sq / rx_sq + y1p_sq / ry_sq
		if lambda > 1.0 then
			const scale = math.sqrt(lambda)
			rx *= scale
			ry *= scale
			rx_sq = rx * rx
			ry_sq = ry * ry
		end

		const num = math.max(0, rx_sq * ry_sq - rx_sq * y1p_sq - ry_sq * x1p_sq)
		const den = rx_sq * y1p_sq + ry_sq * x1p_sq

		local sq = 0.0
		if den > 1e-10 then
			sq = math.sqrt(num / den)
		end

		if large_arc == sweep then
			sq = -sq
		end

		const cxp = sq * rx * y1p / ry
		const cyp = -sq * ry * x1p / rx

		const center_x = cos_phi * cxp - sin_phi * cyp + (x1 + x2) * 0.5
		const center_y = sin_phi * cxp + cos_phi * cyp + (y1 + y2) * 0.5

		local theta1 = math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
		local dtheta = math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - theta1

		if sweep == 1 and dtheta < 0 then
			dtheta += 2 * math.pi
		elseif sweep == 0 and dtheta > 0 then
			dtheta -= 2 * math.pi
		end

		const max_r = math.max(rx, ry)
		const num_steps = math.max(4, math.ceil(math.abs(dtheta) * max_r / tolerance))
		const step = dtheta / num_steps

		const cos_step = math.cos(step)
		const sin_step = math.sin(step)

		const crx = cos_phi * rx
		const sry = sin_phi * ry
		const srx = sin_phi * rx
		const cry = cos_phi * ry

		local cos_a = math.cos(theta1)
		local sin_a = math.sin(theta1)

		for i = 1, num_steps do
			const next_cos = cos_a * cos_step - sin_a * sin_step
			const next_sin = sin_a * cos_step + cos_a * sin_step
			cos_a = next_cos
			sin_a = next_sin

			emit(crx * cos_a - sry * sin_a + center_x, srx * cos_a + cry * sin_a + center_y)
		end
	end

	for _, op in ops do
		if op.type == "M" then
			start_x = op.x
			start_y = op.y
			emit(op.x, op.y)
		elseif op.type == "L" then
			emit(op.x, op.y)
		elseif op.type == "c" then
			const x0 = cur_x
			const y0 = cur_y
			flatten_cubic(
				x0, y0,
				x0 + op.dx1, y0 + op.dy1,
				x0 + op.dx2, y0 + op.dy2,
				x0 + op.dx, y0 + op.dy
			)
		elseif op.type == "a" then
			flatten_arc(
				cur_x, cur_y,
				op.rx, op.ry,
				op.rotation,
				op.largeArc, op.sweep,
				op.dx, op.dy
			)
		elseif op.type == "Z" then
			if cur_x ~= start_x or cur_y ~= start_y then
				emit(start_x, start_y)
			end
		end
	end

	return buf, count
end

return {
	flatten = flatten,
}
