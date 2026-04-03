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
