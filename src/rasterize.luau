--!strict

-- Edge layout: y_min(0) y_max(4) x_at_ymin(8) dx_per_dy(12) dir(16)
const EDGE_STRIDE = 20

const VERTEX_STRIDE = 8

local function fill_interior(
    pixel_buf: buffer,
    span_start: number,
    span: number,
    color_u32: number
)
    buffer.writeu32(pixel_buf, span_start, color_u32)

    local filled = 1
    while filled < span do
        const chunk = math.min(filled, span - filled)
        buffer.copy(pixel_buf, span_start + filled * 4, pixel_buf, span_start, chunk * 4)
        filled += chunk
    end
end

local function fill_span_solid(
    pixel_buf: buffer,
    row_offset: number,
    x_left: number,
    x_right: number,
    width: number,
    color_u32: number
)
    const px_left = math.max(0, math.ceil(x_left))
    const px_right = math.min(width - 1, math.floor(x_right))
    const span = px_right - px_left + 1

    if span <= 0 then
        return
    end

    fill_interior(pixel_buf, row_offset + px_left * 4, span, color_u32)
end

-- Compute signed area coverage for one edge within one scanline row.
-- Writes fractional area and fill (winding delta) into per-scanline buffers.
local function process_edge_aa(
    area_buf: buffer,
    fill_buf: buffer,
    y_min: number,
    y_max: number,
    x_at_ymin: number,
    dx_per_dy: number,
    dir: number,
    y_top: number,
    width: number
)
    local sy0 = math.max(y_top, y_min)
    local sy1 = math.min(y_top + 1, y_max)
    if sy1 <= sy0 then
        return
    end

    const x0 = x_at_ymin + (sy0 - y_min) * dx_per_dy
    const x1 = x_at_ymin + (sy1 - y_min) * dx_per_dy
    const h = sy1 - sy0

    const x_lo = math.min(x0, x1)
    const x_hi = math.max(x0, x1)
    const ix0 = math.clamp(math.floor(x_lo), 0, width - 1)
    const ix1 = math.clamp(math.floor(x_hi), 0, width - 1)

    -- Single pixel column (common case: near-vertical edges)
    if ix0 == ix1 then
        const avg_x = math.clamp(((x0 - ix0) + (x1 - ix0)) / 2, 0, 1)
        const covered = h * (1 - avg_x)

        const off = ix0 * 4
        buffer.writef32(area_buf, off, buffer.readf32(area_buf, off) + dir * covered)
        buffer.writef32(fill_buf, off, buffer.readf32(fill_buf, off) + dir * h)
        return
    end

    -- Multi-pixel: split edge at integer x boundaries
    const x_to_y = h / (x1 - x0)

    for ix = ix0, ix1 do
        const cx0 = math.max(ix, x_lo)
        const cx1 = math.min(ix + 1, x_hi)

        if cx1 <= cx0 then
            continue
        end

        const cy0 = sy0 + (cx0 - x0) * x_to_y
        const cy1 = sy0 + (cx1 - x0) * x_to_y
        const sub_h = math.abs(cy1 - cy0)
        const avg_x = math.clamp(((cx0 - ix) + (cx1 - ix)) / 2, 0, 1)
        const covered = sub_h * (1 - avg_x)

        const off = ix * 4
        buffer.writef32(area_buf, off, buffer.readf32(area_buf, off) + dir * covered)
        buffer.writef32(fill_buf, off, buffer.readf32(fill_buf, off) + dir * sub_h)
    end
end

local function find_intersections(
    edge_buf: buffer,
    edge_end: number,
    first_edge_offset: number,
    x_buf: buffer,
    scan_y: number
): (number, number)
    while first_edge_offset < edge_end and buffer.readf32(edge_buf, first_edge_offset + 4) <= scan_y do
        first_edge_offset += EDGE_STRIDE
    end

    local x_count = 0

    for e_offset = first_edge_offset, edge_end - EDGE_STRIDE, EDGE_STRIDE do
        const y_min = buffer.readf32(edge_buf, e_offset)

        if y_min > scan_y then
            break
        end

        const y_max = buffer.readf32(edge_buf, e_offset + 4)

        if y_max <= scan_y then
            continue
        end

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

    return first_edge_offset, x_count
end

local function rasterize_into(
    pixel_buf: buffer,
    vertices: buffer,
    vertex_count: number,
    width: number,
    height: number,
    r: number,
    g: number,
    b: number,
    a: number,
    anti_alias: boolean
)
    local edge_buf = buffer.create(vertex_count * EDGE_STRIDE)
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
            buffer.writef32(edge_buf, offset + 16, 1)
            if y0 < shape_y_min then shape_y_min = y0 end
            if y1 > shape_y_max then shape_y_max = y1 end
        else
            buffer.writef32(edge_buf, offset, y1)
            buffer.writef32(edge_buf, offset + 4, y0)
            buffer.writef32(edge_buf, offset + 8, x1)
            buffer.writef32(edge_buf, offset + 12, (x0 - x1) / (y0 - y1))
            buffer.writef32(edge_buf, offset + 16, -1)
            if y1 < shape_y_min then shape_y_min = y1 end
            if y0 > shape_y_max then shape_y_max = y0 end
        end

        edge_count += 1
    end

    -- Insertion sort edges by y_min
    for i = 1, edge_count - 1 do
        const i_offset = i * EDGE_STRIDE

        const key_y_min = buffer.readf32(edge_buf, i_offset)
        const key_y_max = buffer.readf32(edge_buf, i_offset + 4)
        const key_x = buffer.readf32(edge_buf, i_offset + 8)
        const key_dx = buffer.readf32(edge_buf, i_offset + 12)
        const key_dir = buffer.readf32(edge_buf, i_offset + 16)

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
        buffer.writef32(edge_buf, dst + 16, key_dir)
    end

    const rb = math.floor(r * 255 + 0.5)
    const gb = math.floor(g * 255 + 0.5)
    const bb = math.floor(b * 255 + 0.5)
    const ab = math.floor(a * 255 + 0.5)

    const color_u32 = rb + gb * 0x100 + bb * 0x10000 + ab * 0x1000000
    const color_rgb = rb + gb * 0x100 + bb * 0x10000

    const x_buf = buffer.create(math.max(1, edge_count) * 4)
    const row_stride = width * 4
    const edge_end = edge_count * EDGE_STRIDE

    const y_start = math.max(0, math.floor(shape_y_min))
    const y_end = math.min(height - 1, math.floor(shape_y_max))
    local row_offset = y_start * row_stride
    local first_edge_offset = 0

    if anti_alias then
        const area_buf = buffer.create(width * 4)
        const fill_buf = buffer.create(width * 4)
        local prev_x_min = 0
        local prev_x_max = -1

        for y = y_start, y_end do
            -- Clear only the previously dirty range
            if prev_x_min <= prev_x_max then
                const clear_off = prev_x_min * 4
                const clear_len = (prev_x_max - prev_x_min + 1) * 4
                buffer.fill(area_buf, clear_off, 0, clear_len)
                buffer.fill(fill_buf, clear_off, 0, clear_len)
            end

            local scan_x_min = width
            local scan_x_max = -1

            -- Advance past completed edges
            while first_edge_offset < edge_end and buffer.readf32(edge_buf, first_edge_offset + 4) <= y do
                first_edge_offset += EDGE_STRIDE
            end

            -- Process active edges
            for e_offset = first_edge_offset, edge_end - EDGE_STRIDE, EDGE_STRIDE do
                const e_y_min = buffer.readf32(edge_buf, e_offset)

                if e_y_min >= y + 1 then
                    break
                end

                const e_y_max = buffer.readf32(edge_buf, e_offset + 4)
                const e_x = buffer.readf32(edge_buf, e_offset + 8)
                const e_dx = buffer.readf32(edge_buf, e_offset + 12)
                const e_dir = buffer.readf32(edge_buf, e_offset + 16)

                -- Track x range for flush
                const ex0 = e_x + (math.max(y, e_y_min) - e_y_min) * e_dx
                const ex1 = e_x + (math.min(y + 1, e_y_max) - e_y_min) * e_dx
                const ixl = math.clamp(math.floor(math.min(ex0, ex1)), 0, width - 1)
                const ixr = math.clamp(math.floor(math.max(ex0, ex1)), 0, width - 1)

                if ixl < scan_x_min then scan_x_min = ixl end
                if ixr > scan_x_max then scan_x_max = ixr end

                process_edge_aa(area_buf, fill_buf, e_y_min, e_y_max, e_x, e_dx, e_dir, y, width)
            end

            -- Accumulate coverage and write pixels
            if scan_x_min <= scan_x_max then
                local sum = 0.0
                local solid_run_start = -1

                for px = scan_x_min, scan_x_max do
                    const off = px * 4
                    const coverage = math.min(math.abs(buffer.readf32(area_buf, off) + sum), 1)
                    sum += buffer.readf32(fill_buf, off)

                    if coverage >= 1 then
                        if solid_run_start < 0 then
                            solid_run_start = px
                        end
                        continue
                    end

                    -- Flush any solid run before this non-solid pixel
                    if solid_run_start >= 0 then
                        fill_interior(pixel_buf, row_offset + solid_run_start * 4, px - solid_run_start, color_u32)
                        solid_run_start = -1
                    end

                    if coverage > 0 then
                        const aa_alpha = math.floor(ab * coverage + 0.5)
                        buffer.writeu32(pixel_buf, row_offset + off, color_rgb + aa_alpha * 0x1000000)
                    end
                end

                -- Flush trailing solid run
                if solid_run_start >= 0 then
                    fill_interior(pixel_buf, row_offset + solid_run_start * 4, scan_x_max - solid_run_start + 1, color_u32)
                end
            end

            prev_x_min = scan_x_min
            prev_x_max = scan_x_max
            row_offset += row_stride
        end
    else
        for y = y_start, y_end do
            const scan_y = y + 0.5
            local x_count: number
            first_edge_offset, x_count = find_intersections(edge_buf, edge_end, first_edge_offset, x_buf, scan_y)

            local pair = 0
            while pair < x_count - 1 do
                const x_left = buffer.readf32(x_buf, pair * 4)
                const x_right = buffer.readf32(x_buf, (pair + 1) * 4)
                fill_span_solid(pixel_buf, row_offset, x_left, x_right, width, color_u32)
                pair += 2
            end

            row_offset += row_stride
        end
    end
end

return {
    rasterize_into = rasterize_into,
}
