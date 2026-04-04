# v0.0.5
- Added support for strokes.
- The fallback to UICorner now uses the 4 clipped frame workaround.
- Supercorner's can now have children.

# v0.0.4
- Added automatic redraw when redrawable props change (`CornerRadius`, `CornerSmoothing`, `TopLeftRadius`, `TopRightRadius`, `BottomRightRadius`, `BottomLeftRadius`, `PreserveSmoothing`, `AntiAlias`).
- Added warnings when create-only props are changed after mount (`MaxCornerRadius`, `MaxTopLeftRadius`, `MaxTopRightRadius`, `MaxBottomRightRadius`, `MaxBottomLeftRadius`, `Redrawable`).
- `CornerRadius` and `CornerSmoothing` are now optional (defaults to `0` and `1` respectively via `supercorner@0.0.5`).

# v0.0.3
- Fixed Supercorner instance not being destroyed on component unmount.

# v0.0.2
- Removed erroneous print debugging.

# v0.0.1
- Initial release.
