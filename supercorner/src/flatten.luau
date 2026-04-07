--!strict

const squircleTypes = require(script.Parent.figma_squircle_luau)

type SvgOp = squircleTypes.SvgOp

const VERTEX_STRIDE = 8
const INITIAL_CAPACITY = 128

-- Module-level scratch buffer for De Casteljau subdivision stack, reused across calls.
const MAX_DEPTH = 16
const STACK_STRIDE = 36
const stackBuf = buffer.create(MAX_DEPTH * 2 * STACK_STRIDE)

const function createVertexBuf(capacity: number): buffer
	return buffer.create(capacity * VERTEX_STRIDE)
end

const function flatten(ops: { SvgOp }, tolerance: number): (buffer, number)
	-- Estimate vertex count from op types to avoid dynamic resizing.
	-- Conservative upper bounds: cubics subdivide to at most 2^MAX_DEPTH segments,
	-- but typical squircle cubics produce ~8-16 vertices; arcs produce ~4-12.
	local estimate = 0

	for _, op in ops do
		const t = op.type

		if t == "c" then
			estimate += 10

		elseif t == "a" then
			estimate += 8

		else
			estimate += 1
		end
	end

	local capacity = math.max(INITIAL_CAPACITY, estimate)
	local buf = createVertexBuf(capacity)
	local count = 0

	local curX = 0.0
	local curY = 0.0
	local startX = 0.0
	local startY = 0.0

	const function emit(x: number, y: number)
		if count >= capacity then
			const oldBuf = buf
			capacity *= 2
			buf = createVertexBuf(capacity)
			buffer.copy(buf, 0, oldBuf, 0, count * VERTEX_STRIDE)
		end

		const offset = count * VERTEX_STRIDE
		buffer.writef32(buf, offset, x)
		buffer.writef32(buf, offset + 4, y)
		count += 1
		curX = x
		curY = y
	end

	const tolSq = tolerance * tolerance

	const function flattenCubic(
		sx0: number, sy0: number,
		sx1: number, sy1: number,
		sx2: number, sy2: number,
		sx3: number, sy3: number
	)
		local sp = 0
		buffer.writef32(stackBuf, 0, sx0)
		buffer.writef32(stackBuf, 4, sy0)
		buffer.writef32(stackBuf, 8, sx1)
		buffer.writef32(stackBuf, 12, sy1)
		buffer.writef32(stackBuf, 16, sx2)
		buffer.writef32(stackBuf, 20, sy2)
		buffer.writef32(stackBuf, 24, sx3)
		buffer.writef32(stackBuf, 28, sy3)
		buffer.writef32(stackBuf, 32, 0)
		sp = 1

		while sp > 0 do
			sp -= 1
			const base = sp * STACK_STRIDE
			const x0 = buffer.readf32(stackBuf, base)
			const y0 = buffer.readf32(stackBuf, base + 4)
			const x1 = buffer.readf32(stackBuf, base + 8)
			const y1 = buffer.readf32(stackBuf, base + 12)
			const x2 = buffer.readf32(stackBuf, base + 16)
			const y2 = buffer.readf32(stackBuf, base + 20)
			const x3 = buffer.readf32(stackBuf, base + 24)
			const y3 = buffer.readf32(stackBuf, base + 28)
			const depth = buffer.readf32(stackBuf, base + 32)

			const dx = x3 - x0
			const dy = y3 - y0
			const dSq = dx * dx + dy * dy

			if dSq < 1e-10 then
				emit(x3, y3)
				continue
			end

			-- Flatness test: max distance from control points to the chord
			const invDSq = 1.0 / dSq

			const t1 = ((x1 - x0) * dx + (y1 - y0) * dy) * invDSq
			const px1 = x0 + t1 * dx - x1
			const py1 = y0 + t1 * dy - y1
			const d1Sq = px1 * px1 + py1 * py1

			const t2 = ((x2 - x0) * dx + (y2 - y0) * dy) * invDSq
			const px2 = x0 + t2 * dx - x2
			const py2 = y0 + t2 * dy - y2
			const d2Sq = px2 * px2 + py2 * py2

			if (d1Sq <= tolSq and d2Sq <= tolSq) or depth >= MAX_DEPTH then
				emit(x3, y3)
				continue
			end

			-- De Casteljau midpoint split
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

			-- Push right half first so left half is popped first (preserves vertex order)
			const rBase = sp * STACK_STRIDE
			buffer.writef32(stackBuf, rBase, mx)
			buffer.writef32(stackBuf, rBase + 4, my)
			buffer.writef32(stackBuf, rBase + 8, m123x)
			buffer.writef32(stackBuf, rBase + 12, m123y)
			buffer.writef32(stackBuf, rBase + 16, m23x)
			buffer.writef32(stackBuf, rBase + 20, m23y)
			buffer.writef32(stackBuf, rBase + 24, x3)
			buffer.writef32(stackBuf, rBase + 28, y3)
			buffer.writef32(stackBuf, rBase + 32, depth + 1)
			sp += 1

			const lBase = sp * STACK_STRIDE
			buffer.writef32(stackBuf, lBase, x0)
			buffer.writef32(stackBuf, lBase + 4, y0)
			buffer.writef32(stackBuf, lBase + 8, m01x)
			buffer.writef32(stackBuf, lBase + 12, m01y)
			buffer.writef32(stackBuf, lBase + 16, m012x)
			buffer.writef32(stackBuf, lBase + 20, m012y)
			buffer.writef32(stackBuf, lBase + 24, mx)
			buffer.writef32(stackBuf, lBase + 28, my)
			buffer.writef32(stackBuf, lBase + 32, depth + 1)
			sp += 1
		end
	end

	-- SVG arc: endpoint-to-center parameterization (SVG spec F.6.5–F.6.6),
	-- then incremental rotation to avoid per-step trig calls
	const function flattenArc(
		cx: number, cy: number,
		rx: number, ry: number,
		rotation: number,
		largeArc: number, sweep: number,
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

		const rotRad = math.rad(rotation)
		const cosPhi = math.cos(rotRad)
		const sinPhi = math.sin(rotRad)

		const hdx = (x1 - x2) * 0.5
		const hdy = (y1 - y2) * 0.5
		const x1p = cosPhi * hdx + sinPhi * hdy
		const y1p = -sinPhi * hdx + cosPhi * hdy

		const x1pSq = x1p * x1p
		const y1pSq = y1p * y1p
		local rxSq = rx * rx
		local rySq = ry * ry

		-- Scale radii if the ellipse is too small to reach both endpoints
		const lambda = x1pSq / rxSq + y1pSq / rySq
		if lambda > 1.0 then
			const scale = math.sqrt(lambda)
			rx *= scale
			ry *= scale
			rxSq = rx * rx
			rySq = ry * ry
		end

		const num = math.max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
		const den = rxSq * y1pSq + rySq * x1pSq

		local sq = if den > 1e-10 then math.sqrt(num / den) else 0.0
		sq = if largeArc == sweep then -sq else sq

		const cxp = sq * rx * y1p / ry
		const cyp = -sq * ry * x1p / rx

		const centerX = cosPhi * cxp - sinPhi * cyp + (x1 + x2) * 0.5
		const centerY = sinPhi * cxp + cosPhi * cyp + (y1 + y2) * 0.5

		local theta1 = math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
		local dtheta = math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - theta1

		if sweep == 1 and dtheta < 0 then
			dtheta += 2 * math.pi

		elseif sweep == 0 and dtheta > 0 then
			dtheta -= 2 * math.pi
		end

		-- Step count from chord deviation: r·θ²/8 ≤ tolerance → θ ≤ sqrt(8·tol/r)
		const maxR = math.max(rx, ry)
		const maxStep = math.sqrt(8 * tolerance / maxR)
		const numSteps = math.max(4, math.ceil(math.abs(dtheta) / maxStep))
		const step = dtheta / numSteps

		-- Incremental rotation via angle-addition identity (avoids per-step cos/sin)
		const cosStep = math.cos(step)
		const sinStep = math.sin(step)

		const crx = cosPhi * rx
		const sry = sinPhi * ry
		const srx = sinPhi * rx
		const cry = cosPhi * ry

		local cosA = math.cos(theta1)
		local sinA = math.sin(theta1)

		for i = 1, numSteps do
			const nextCos = cosA * cosStep - sinA * sinStep
			const nextSin = sinA * cosStep + cosA * sinStep
			cosA = nextCos
			sinA = nextSin

			emit(crx * cosA - sry * sinA + centerX, srx * cosA + cry * sinA + centerY)
		end
	end

	for _, op in ops do
		if op.type == "M" then
			startX = op.x
			startY = op.y
			emit(op.x, op.y)

		elseif op.type == "L" then
			emit(op.x, op.y)

		elseif op.type == "c" then
			const x0 = curX
			const y0 = curY
			flattenCubic(
				x0, y0,
				x0 + op.dx1, y0 + op.dy1,
				x0 + op.dx2, y0 + op.dy2,
				x0 + op.dx, y0 + op.dy
			)

		elseif op.type == "a" then
			flattenArc(
				curX, curY,
				op.rx, op.ry,
				op.rotation,
				op.largeArc, op.sweep,
				op.dx, op.dy
			)

		elseif op.type == "Z" then
			if curX ~= startX or curY ~= startY then
				emit(startX, startY)
			end
		end
	end

	return buf, count
end

return flatten
