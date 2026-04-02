--!strict
--!nolint LocalShadow

-- Edge buffer layout (f32 fields at byte offsets)
-- [0] yMin  [4] yMax  [8] xAtYmin  [12] dxPerDy  [16] dir (+1/-1)
const EDGE_STRIDE = 20

const VERTEX_STRIDE = 8

-- Fills a span of pixels with a u32 color by writing one pixel then exponentially
-- doubling via buffer.copy. This is needed as buffer.fill sets every byte to the same
-- 8-bit value, so it can't write a repeating 4-byte RGBA pattern.
const function fillInterior(
    pixelBuf: buffer,
    spanStart: number,
    span: number,
    colorU32: number
)
    buffer.writeu32(pixelBuf, spanStart, colorU32)

    local filled = 1
    while filled < span do
        const chunk = math.min(filled, span - filled)
        buffer.copy(pixelBuf, spanStart + filled * 4, pixelBuf, spanStart, chunk * 4)
        filled += chunk
    end
end

-- Clip an edge intersection pair to pixel bounds and fill the span
const function fillSpanSolid(
    pixelBuf: buffer,
    rowOffset: number,
    xLeft: number,
    xRight: number,
    width: number,
    colorU32: number
)
    const pxLeft = math.max(0, math.ceil(xLeft))
    const pxRight = math.min(width - 1, math.floor(xRight))
    const span = pxRight - pxLeft + 1

    if span <= 0 then
        return
    end

    fillInterior(pixelBuf, rowOffset + pxLeft * 4, span, colorU32)
end

-- Signed area coverage for one edge within a single scanline band [yTop, yTop+1].
-- areaBuf accumulates the pixel-local signed area (used for edge pixels).
-- fillBuf accumulates the winding delta (propagated across the scanline via prefix sum).
const function processEdgeAA(
    areaBuf: buffer,
    fillBuf: buffer,
    yMin: number,
    yMax: number,
    xAtYmin: number,
    dxPerDy: number,
    dir: number,
    yTop: number,
    width: number
)
    local sy0 = math.max(yTop, yMin)
    local sy1 = math.min(yTop + 1, yMax)
    if sy1 <= sy0 then
        return
    end

    const x0 = xAtYmin + (sy0 - yMin) * dxPerDy
    const x1 = xAtYmin + (sy1 - yMin) * dxPerDy
    const h = sy1 - sy0

    const xLo = math.min(x0, x1)
    const xHi = math.max(x0, x1)
    const ix0 = math.clamp(math.floor(xLo), 0, width - 1)
    const ix1 = math.clamp(math.floor(xHi), 0, width - 1)

    -- Near-vertical edges: single pixel column
    if ix0 == ix1 then
        const avgX = math.clamp(((x0 - ix0) + (x1 - ix0)) / 2, 0, 1)
        const covered = h * (1 - avgX)

        const off = ix0 * 4
        buffer.writef32(areaBuf, off, buffer.readf32(areaBuf, off) + dir * covered)
        buffer.writef32(fillBuf, off, buffer.readf32(fillBuf, off) + dir * h)
        return
    end

    -- Near-horizontal edges: split at integer x boundaries
    const xToY = h / (x1 - x0)

    for ix = ix0, ix1 do
        const cx0 = math.max(ix, xLo)
        const cx1 = math.min(ix + 1, xHi)

        if cx1 <= cx0 then
            continue
        end

        const cy0 = sy0 + (cx0 - x0) * xToY
        const cy1 = sy0 + (cx1 - x0) * xToY
        const subH = math.abs(cy1 - cy0)
        const avgX = math.clamp(((cx0 - ix) + (cx1 - ix)) / 2, 0, 1)
        const covered = subH * (1 - avgX)

        const off = ix * 4
        buffer.writef32(areaBuf, off, buffer.readf32(areaBuf, off) + dir * covered)
        buffer.writef32(fillBuf, off, buffer.readf32(fillBuf, off) + dir * subH)
    end
end

-- Find sorted edge-scanline intersections for the non-AA path.
-- Returns updated firstEdgeOffset (for active edge tracking) and intersection count.
const function findIntersections(
    edgeBuf: buffer,
    edgeEnd: number,
    firstEdgeOffset: number,
    xBuf: buffer,
    scanY: number
): (number, number)
    -- Skip edges that end before this scanline
    while firstEdgeOffset < edgeEnd and buffer.readf32(edgeBuf, firstEdgeOffset + 4) <= scanY do
        firstEdgeOffset += EDGE_STRIDE
    end

    local xCount = 0

    for eOffset = firstEdgeOffset, edgeEnd - EDGE_STRIDE, EDGE_STRIDE do
        const yMin = buffer.readf32(edgeBuf, eOffset)

        if yMin > scanY then
            break
        end

        const yMax = buffer.readf32(edgeBuf, eOffset + 4)

        if yMax <= scanY then
            continue
        end

        const xAtYmin = buffer.readf32(edgeBuf, eOffset + 8)
        const dxPerDy = buffer.readf32(edgeBuf, eOffset + 12)
        const xIntersect = xAtYmin + (scanY - yMin) * dxPerDy

        -- Insertion sort into xBuf
        local pos = xCount

        while pos > 0 and buffer.readf32(xBuf, (pos - 1) * 4) > xIntersect do
            buffer.writef32(xBuf, pos * 4, buffer.readf32(xBuf, (pos - 1) * 4))
            pos -= 1
        end

        buffer.writef32(xBuf, pos * 4, xIntersect)
        xCount += 1
    end

    return firstEdgeOffset, xCount
end

const function rasterize(
    pixelBuf: buffer,
    vertices: buffer,
    vertexCount: number,
    width: number,
    height: number,
    r: number,
    g: number,
    b: number,
    a: number,
    antiAlias: boolean
)
    -- Build edge table from polygon vertices
    local edgeBuf = buffer.create(vertexCount * EDGE_STRIDE)
    local edgeCount = 0
    local shapeYMin = math.huge
    local shapeYMax = -math.huge

    for i = 0, vertexCount - 1 do
        const j = if i < vertexCount - 1 then i + 1 else 0

        const iOff = i * VERTEX_STRIDE
        const x0 = buffer.readf32(vertices, iOff)
        const y0 = buffer.readf32(vertices, iOff + 4)
        const jOff = j * VERTEX_STRIDE
        const x1 = buffer.readf32(vertices, jOff)
        const y1 = buffer.readf32(vertices, jOff + 4)

        if y0 == y1 then
            continue
        end

        const offset = edgeCount * EDGE_STRIDE

        -- Orient edges so yMin < yMax; dir tracks original winding direction
        if y0 < y1 then
            buffer.writef32(edgeBuf, offset, y0)
            buffer.writef32(edgeBuf, offset + 4, y1)
            buffer.writef32(edgeBuf, offset + 8, x0)
            buffer.writef32(edgeBuf, offset + 12, (x1 - x0) / (y1 - y0))
            buffer.writef32(edgeBuf, offset + 16, 1)
            if y0 < shapeYMin then shapeYMin = y0 end
            if y1 > shapeYMax then shapeYMax = y1 end

        else
            buffer.writef32(edgeBuf, offset, y1)
            buffer.writef32(edgeBuf, offset + 4, y0)
            buffer.writef32(edgeBuf, offset + 8, x1)
            buffer.writef32(edgeBuf, offset + 12, (x0 - x1) / (y0 - y1))
            buffer.writef32(edgeBuf, offset + 16, -1)
            if y1 < shapeYMin then shapeYMin = y1 end
            if y0 > shapeYMax then shapeYMax = y0 end
        end

        edgeCount += 1
    end

    -- Sort edges by yMin for scanline traversal
    for i = 1, edgeCount - 1 do
        const iOffset = i * EDGE_STRIDE

        const keyYMin = buffer.readf32(edgeBuf, iOffset)
        const keyYMax = buffer.readf32(edgeBuf, iOffset + 4)
        const keyX = buffer.readf32(edgeBuf, iOffset + 8)
        const keyDx = buffer.readf32(edgeBuf, iOffset + 12)
        const keyDir = buffer.readf32(edgeBuf, iOffset + 16)

        local j = i - 1

        while j >= 0 and buffer.readf32(edgeBuf, j * EDGE_STRIDE) > keyYMin do
            const src = j * EDGE_STRIDE
            const dst = (j + 1) * EDGE_STRIDE
            buffer.copy(edgeBuf, dst, edgeBuf, src, EDGE_STRIDE)
            j -= 1
        end

        const dst = (j + 1) * EDGE_STRIDE
        buffer.writef32(edgeBuf, dst, keyYMin)
        buffer.writef32(edgeBuf, dst + 4, keyYMax)
        buffer.writef32(edgeBuf, dst + 8, keyX)
        buffer.writef32(edgeBuf, dst + 12, keyDx)
        buffer.writef32(edgeBuf, dst + 16, keyDir)
    end

    const rb = math.floor(r * 255 + 0.5)
    const gb = math.floor(g * 255 + 0.5)
    const bb = math.floor(b * 255 + 0.5)
    const ab = math.floor(a * 255 + 0.5)

    const colorU32 = rb + gb * 0x100 + bb * 0x10000 + ab * 0x1000000
    const colorRgb = rb + gb * 0x100 + bb * 0x10000

    const xBuf = buffer.create(math.max(1, edgeCount) * 4)
    const rowStride = width * 4
    const edgeEnd = edgeCount * EDGE_STRIDE

    const yStart = math.max(0, math.floor(shapeYMin))
    const yEnd = math.min(height - 1, math.floor(shapeYMax))
    local rowOffset = yStart * rowStride
    local firstEdgeOffset = 0

    if antiAlias then
        const areaBuf = buffer.create(width * 4)
        const fillBuf = buffer.create(width * 4)
        local prevXMin = 0
        local prevXMax = -1

        for y = yStart, yEnd do
            -- Only clear the pixel range dirtied by the previous scanline
            if prevXMin <= prevXMax then
                const clearOff = prevXMin * 4
                const clearLen = (prevXMax - prevXMin + 1) * 4
                buffer.fill(areaBuf, clearOff, 0, clearLen)
                buffer.fill(fillBuf, clearOff, 0, clearLen)
            end

            local scanXMin = width
            local scanXMax = -1

            -- Advance past edges whose yMax is behind this scanline
            while firstEdgeOffset < edgeEnd and buffer.readf32(edgeBuf, firstEdgeOffset + 4) <= y do
                firstEdgeOffset += EDGE_STRIDE
            end

            for eOffset = firstEdgeOffset, edgeEnd - EDGE_STRIDE, EDGE_STRIDE do
                const eYMin = buffer.readf32(edgeBuf, eOffset)

                if eYMin >= y + 1 then
                    break
                end

                const eYMax = buffer.readf32(edgeBuf, eOffset + 4)
                const eX = buffer.readf32(edgeBuf, eOffset + 8)
                const eDx = buffer.readf32(edgeBuf, eOffset + 12)
                const eDir = buffer.readf32(edgeBuf, eOffset + 16)

                const ex0 = eX + (math.max(y, eYMin) - eYMin) * eDx
                const ex1 = eX + (math.min(y + 1, eYMax) - eYMin) * eDx
                const ixl = math.clamp(math.floor(math.min(ex0, ex1)), 0, width - 1)
                const ixr = math.clamp(math.floor(math.max(ex0, ex1)), 0, width - 1)

                if ixl < scanXMin then scanXMin = ixl end
                if ixr > scanXMax then scanXMax = ixr end

                processEdgeAA(areaBuf, fillBuf, eYMin, eYMax, eX, eDx, eDir, y, width)
            end

            -- Prefix-sum accumulation: coverage = |area + running_sum|
            -- Consecutive solid pixels are batched into a single fillInterior call
            if scanXMin <= scanXMax then
                local sum = 0.0
                local solidRunStart = -1

                for px = scanXMin, scanXMax do
                    const off = px * 4
                    const coverage = math.min(math.abs(buffer.readf32(areaBuf, off) + sum), 1)
                    sum += buffer.readf32(fillBuf, off)

                    if coverage >= 1 then
                        if solidRunStart < 0 then
                            solidRunStart = px
                        end
                        continue
                    end

                    if solidRunStart >= 0 then
                        fillInterior(pixelBuf, rowOffset + solidRunStart * 4, px - solidRunStart, colorU32)
                        solidRunStart = -1
                    end

                    if coverage > 0 then
                        const aaAlpha = math.floor(ab * coverage + 0.5)
                        buffer.writeu32(pixelBuf, rowOffset + off, colorRgb + aaAlpha * 0x1000000)
                    end
                end

                if solidRunStart >= 0 then
                    fillInterior(pixelBuf, rowOffset + solidRunStart * 4, scanXMax - solidRunStart + 1, colorU32)
                end
            end

            prevXMin = scanXMin
            prevXMax = scanXMax
            rowOffset += rowStride
        end

    else
        -- Non-AA: even-odd scanline fill at pixel centers
        for y = yStart, yEnd do
            const scanY = y + 0.5
            local xCount: number
            firstEdgeOffset, xCount = findIntersections(edgeBuf, edgeEnd, firstEdgeOffset, xBuf, scanY)

            local pair = 0
            while pair < xCount - 1 do
                const xLeft = buffer.readf32(xBuf, pair * 4)
                const xRight = buffer.readf32(xBuf, (pair + 1) * 4)
                fillSpanSolid(pixelBuf, rowOffset, xLeft, xRight, width, colorU32)
                pair += 2
            end

            rowOffset += rowStride
        end
    end
end

return {
	rasterize = rasterize,
	fillInterior = fillInterior,
}
