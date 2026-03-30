--!strict

-- Edge layout in buffer: y_min(0) y_max(4) x_at_ymin(8) dx_per_dy(12)
const EDGE_STRIDE = 16

const VERTEX_STRIDE = 8

const function rasterize(
	vertices: buffer,
	vertex_count: number,
	width: number,
	height: number,
	r: number,
	g: number,
	b: number,
	a: number
): buffer
	const max_edges = vertex_count
	local edge_buf = buffer.create(max_edges * EDGE_STRIDE)
	local edge_count = 0

	for i = 0, vertex_count - 1 do
		const j = (i + 1) % vertex_count

		const x0 = buffer.readf32(vertices, i * VERTEX_STRIDE)
		const y0 = buffer.readf32(vertices, i * VERTEX_STRIDE + 4)
		const x1 = buffer.readf32(vertices, j * VERTEX_STRIDE)
		const y1 = buffer.readf32(vertices, j * VERTEX_STRIDE + 4)

		if y0 == y1 then
			continue
		end

		const offset = edge_count * EDGE_STRIDE

		if y0 < y1 then
			buffer.writef32(edge_buf, offset, y0)
			buffer.writef32(edge_buf, offset + 4, y1)
			buffer.writef32(edge_buf, offset + 8, x0)
			buffer.writef32(edge_buf, offset + 12, (x1 - x0) / (y1 - y0))
		else
			buffer.writef32(edge_buf, offset, y1)
			buffer.writef32(edge_buf, offset + 4, y0)
			buffer.writef32(edge_buf, offset + 8, x1)
			buffer.writef32(edge_buf, offset + 12, (x0 - x1) / (y0 - y1))
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

	const pixel_buf = buffer.create(width * height * 4)

	const rb = math.floor(r * 255 + 0.5)
	const gb = math.floor(g * 255 + 0.5)
	const bb = math.floor(b * 255 + 0.5)
	const ab = math.floor(a * 255 + 0.5)

	const color_u32 = rb + gb * 0x100 + bb * 0x10000 + ab * 0x1000000

	const x_buf = buffer.create(math.max(1, edge_count) * 4)

	for y = 0, height - 1 do
		const scan_y = y + 0.5
		local x_count = 0

		for e = 0, edge_count - 1 do
			const e_offset = e * EDGE_STRIDE
			const y_min = buffer.readf32(edge_buf, e_offset)
			const y_max = buffer.readf32(edge_buf, e_offset + 4)

			if y_min > scan_y then
				break
			end

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

		const row_offset = y * width * 4
		local pair = 0

		while pair < x_count - 1 do
			const x_left = buffer.readf32(x_buf, pair * 4)
			const x_right = buffer.readf32(x_buf, (pair + 1) * 4)

			const px_left = math.max(0, math.ceil(x_left))
			const px_right = math.min(width - 1, math.floor(x_right))

			for px = px_left, px_right do
				buffer.writeu32(pixel_buf, row_offset + px * 4, color_u32)
			end

			pair += 2
		end
	end

	return pixel_buf
end

return {
	rasterize = rasterize,
}
