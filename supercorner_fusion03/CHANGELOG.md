# v0.1.1
- Added `Button` support to `Supercorner.new` and `Supercorner.atlas`, allowing the generated root to be a `TextButton`.
- Added `RootChildren` for mounting children directly under the generated root; regular Fusion children now live in a named `Content` layer.
- Standardized the generated hierarchy with named `SupercornerImages`, `Fill`, `Stroke`, and `Content` instances and explicit Z-index ordering.
- Fixed reactive fill and stroke toggling so regenerated image content and slice metadata are applied correctly.
- Migrated distribution to Pesde under the package name `cameronpcampbell/supercorner_fusion03`, with native Pesde Supercorner resolution and Fusion pinned to its upstream 0.3 commit.
- Bundled the MIT license as a regular package file.

# v0.1.0
- Added `atlas` support via `Supercorner.atlas(scope, props)` for pre-baked keypoint animations driven by a reactive `Alpha` value.
- Extracted shared fallback rendering logic into `shared.luau`.
- **Breaking:** API changed from `Supercorner(scope, props)` to `Supercorner.new(scope, props)`.

# v0.0.1
- Initial release.
