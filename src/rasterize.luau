--!strict

-- Edge layout in buffer: y_min(0) y_max(4) x_at_ymin(8) dx_per_dy(12)
const EDGE_STRIDE = 16

const VERTEX_STRIDE = 8

const function rasterize_into(
	pixel_buf: buffer,
	vertices: buffer,
	vertex_count: number,
	width: number,
	height: number,
	r: number,
	g: number,
	b: number,
	a: number
)
	const max_edges = vertex_count
	local edge_buf = buffer.create(max_edges * EDGE_STRIDE)
	local edge_count = 0
	local shape_y_min = math.huge
	local shape_y_max = -math.huge

	for i = 0, vertex_count - 1 do
		const j = if i < vertex_count - 1 then i + 1 else 0

		const i_off = i * VERTEX_STRIDE
		const x0 = buffer.readf32(vertices, i_off)
		const y0 = buffer.readf32(vertices, i_off + 4)
		const j_off = j * VERTEX_STRIDE
		const x1 = buffer.readf32(vertices, j_off)
		const y1 = buffer.readf32(vertices, j_off + 4)

		if y0 == y1 then
			continue
		end

		const offset = edge_count * EDGE_STRIDE

		if y0 < y1 then
			buffer.writef32(edge_buf, offset, y0)
			buffer.writef32(edge_buf, offset + 4, y1)
			buffer.writef32(edge_buf, offset + 8, x0)
			buffer.writef32(edge_buf, offset + 12, (x1 - x0) / (y1 - y0))
			if y0 < shape_y_min then shape_y_min = y0 end
			if y1 > shape_y_max then shape_y_max = y1 end
		else
			buffer.writef32(edge_buf, offset, y1)
			buffer.writef32(edge_buf, offset + 4, y0)
			buffer.writef32(edge_buf, offset + 8, x1)
			buffer.writef32(edge_buf, offset + 12, (x0 - x1) / (y0 - y1))
			if y1 < shape_y_min then shape_y_min = y1 end
			if y0 > shape_y_max then shape_y_max = y0 end
		end

		edge_count += 1
	end

	for i = 1, edge_count - 1 do
		const i_offset = i * EDGE_STRIDE

		const key_y_min = buffer.readf32(edge_buf, i_offset)
		const key_y_max = buffer.readf32(edge_buf, i_offset + 4)
		const key_x = buffer.readf32(edge_buf, i_offset + 8)
		const key_dx = buffer.readf32(edge_buf, i_offset + 12)

		local j = i - 1

		while j >= 0 and buffer.readf32(edge_buf, j * EDGE_STRIDE) > key_y_min do
			const src = j * EDGE_STRIDE
			const dst = (j + 1) * EDGE_STRIDE
			buffer.copy(edge_buf, dst, edge_buf, src, EDGE_STRIDE)
			j -= 1
		end

		const dst = (j + 1) * EDGE_STRIDE
		buffer.writef32(edge_buf, dst, key_y_min)
		buffer.writef32(edge_buf, dst + 4, key_y_max)
		buffer.writef32(edge_buf, dst + 8, key_x)
		buffer.writef32(edge_buf, dst + 12, key_dx)
	end

	const rb = math.floor(r * 255 + 0.5)
	const gb = math.floor(g * 255 + 0.5)
	const bb = math.floor(b * 255 + 0.5)
	const ab = math.floor(a * 255 + 0.5)

	const color_u32 = rb + gb * 0x100 + bb * 0x10000 + ab * 0x1000000

	const x_buf = buffer.create(math.max(1, edge_count) * 4)
	const row_stride = width * 4

	const edge_end = edge_count * EDGE_STRIDE
	local first_edge_offset = 0

	const y_start = math.max(0, math.floor(shape_y_min))
	const y_end = math.min(height - 1, math.floor(shape_y_max))
	local row_offset = y_start * row_stride

	for y = y_start, y_end do
		const scan_y = y + 0.5
		local x_count = 0

		-- Advance past edges whose y_max we've passed
		while first_edge_offset < edge_end and buffer.readf32(edge_buf, first_edge_offset + 4) <= scan_y do
			first_edge_offset += EDGE_STRIDE
		end

		for e_offset = first_edge_offset, edge_end - EDGE_STRIDE, EDGE_STRIDE do
			const y_min = buffer.readf32(edge_buf, e_offset)

			if y_min > scan_y then
				break
			end

			const y_max = buffer.readf32(edge_buf, e_offset + 4)

			if y_max > scan_y then
				const x_at_ymin = buffer.readf32(edge_buf, e_offset + 8)
				const dx_per_dy = buffer.readf32(edge_buf, e_offset + 12)
				const x_intersect = x_at_ymin + (scan_y - y_min) * dx_per_dy

				local pos = x_count

				while pos > 0 and buffer.readf32(x_buf, (pos - 1) * 4) > x_intersect do
					buffer.writef32(x_buf, pos * 4, buffer.readf32(x_buf, (pos - 1) * 4))
					pos -= 1
				end

				buffer.writef32(x_buf, pos * 4, x_intersect)
				x_count += 1
			end
		end

		local pair = 0

		while pair < x_count - 1 do
			const x_left = buffer.readf32(x_buf, pair * 4)
			const x_right = buffer.readf32(x_buf, (pair + 1) * 4)

			const px_left = math.max(0, math.ceil(x_left))
			const px_right = math.min(width - 1, math.floor(x_right))

			const span = px_right - px_left + 1
			if span > 0 then
				const span_start = row_offset + px_left * 4
				buffer.writeu32(pixel_buf, span_start, color_u32)

				local filled = 1
				while filled < span do
					const chunk = math.min(filled, span - filled)
					buffer.copy(pixel_buf, span_start + filled * 4, pixel_buf, span_start, chunk * 4)
					filled += chunk
				end
			end

			pair += 2
		end

		row_offset += row_stride
	end

end

return {
	rasterize_into = rasterize_into,
}
