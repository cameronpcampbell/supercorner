# v0.1.0
- Image sizing now accounts for stroke width, preventing strokes from being clipped or rendered as solid fills at small corner radii.
- Slice center calculation now includes a 2px margin past the inner stroke edge to prevent anti-aliased pixels from being stretched by 9-slice.
- Image dimensions now guarantee at least 2 internal pixels of stretchable center for valid 9-slicing.
- Inner stroke path smoothing is capped at 0.99 to prevent a degenerate arc vertex that caused missing pixels at inner corners.

# v0.0.9
- Added a `supercorner.atlas` function that generates an atlas of supercorners that can be tweened.

# v0.0.8
- Rasterizer now clears only the shape's bounding-box rows instead of the full pixel buffer.
- AA scanline loop skips solid interior pixels by scanning forward to the next edge boundary, filling the gap in a single call.
- Reused module-level scratch buffers for edge, area, fill, and subdivision stack data to reduce per-render allocations and GC pressure.
- Vertex buffer is now pre-sized from op types to avoid dynamic resizing during path flattening.
- Replaced insertion sorts with `table.sort` in edge sorting and corner radius distribution.
- Cached repeated `math.rad()` calls in path generation and arc flattening.
- Removed unnecessary `table.clone()` and redundant parameter defaulting in the public API.
- Cache size queries are now O(1) via maintained counters instead of full table iteration.
- Cached intermediate `math.max` results in slice center calculation.

# v0.0.7
- Added stroke support. Pass `Stroke = <thickness>` to render an inset outline instead of a fill. If the stroke is thick enough to cover the entire shape, a fill is used instead.
- Rasterizer now supports multiple sub-paths, enabling composite polygon rendering (used internally for stroke).

# v0.0.6
- Transparent pixels now have white RGB values instead of black which prevents artifacting around the edges of supercorner instances.

# v0.0.5
- `CornerRadius` and `CornerSmoothing` are now optional, defaulting to `0` and `1` respectively.

# v0.0.4
- Fixed bug where individual corner radii were ignored in favor of `CornerRadius`.

# v0.0.3
- Renamed `Radius` to `CornerRadius`.

# v0.0.2
- Fixed bug where max corner radii defaulted to `CornerRadius` instead of their individual default.

# v0.0.1
- Initial release.
