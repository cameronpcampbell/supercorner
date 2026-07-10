# Supercorner Fusion 0.3: Wally-to-Pesde Migration Plan

## Objective

Migrate only the `supercorner_fusion03` package from Wally to Pesde and make its dedicated release workflow publish to Pesde. After the migration, this package must not use the Wally CLI, Wally registry, `WALLY_TOKEN`, `wally.toml`, or `wally.lock`.

The package's public Pesde identity will be:

```text
cameronpcampbell/supercorner_fusion03
```

This deliberately uses an underscore. Pesde package names may contain only lowercase letters, numbers, and underscores, so the existing Wally name `cameronpcampbell/supercorner-fusion03` is invalid on Pesde.

## Hard scope

The implementation may change:

- Files within `supercorner_fusion03/`.
- Only the dedicated workflow `.github/workflows/supercorner_fusion03_release.yml`.

Do not change:

- `supercorner/` or its release workflow.
- `supercorner_react/` or its release workflow.
- Root `rokit.toml`. Pesde is already pinned there, while the remaining Wally entry may still be needed by other subpackages.
- Any unrelated source, workflow, tag, or release.

The existing release tag prefix stays `supercorner-fusion03-v*`; only the registry package name changes to use an underscore.

## Current state and important constraints

- `supercorner_fusion03/wally.toml` declares package version `0.1.1` and depends on Supercorner `0.1.0` and Fusion `0.3.0`.
- No remote `supercorner-fusion03-v0.1.1` tag currently exists, so `0.1.1` can be the first Pesde release after this migration.
- Core Supercorner `0.1.1` is now on Pesde and should be the native Pesde dependency.
- Fusion 0.3 does not currently have a native `elttob/fusion` Pesde package. Do not use Pesde's Wally-registry compatibility dependency because this migration is intended to stop this subpackage from using the Wally registry.
- Instead, declare Fusion as a Git dependency pinned to upstream commit `77e603534ff4013f4049611826ff0309d6000b15`. This is the immutable commit behind Fusion's `v0.3-beta` release, whose upstream manifest identifies it as version `0.3.0`.
- The source currently hard-codes Wally `_Index` paths and uses versioned package folder names. These paths must be changed to Pesde's generated `roblox_packages` aliases.
- Pesde 0.7.3 syntax validation rejects the nonstandard `const` declarations currently present in the package source. Replace those declarations with `local` without changing their values or behavior.
- A recent core-package release showed that Pesde 0.7.3 can print `error occurred publishing ...` and still exit with status `0`. The Fusion workflow must include the same output guard so GitHub Actions cannot report a false success.
- Do not add an `[engines]` section to this package's `pesde.toml`. The repository and workflow already pin Pesde 0.7.3, and `[engines]` causes Pesde to query the GitHub Releases API during publishing. Omitting it avoids the unauthenticated engine-resolution API-limit failure already observed on GitHub-hosted runners.

Relevant references:

- [Pesde manifest reference](https://docs.pesde.dev/reference/manifest/)
- [Pesde dependency types](https://docs.pesde.dev/guides/dependencies/)
- [Authoring Roblox packages with Pesde](https://docs.pesde.dev/guides/roblox/)
- [Publishing packages](https://docs.pesde.dev/guides/publishing/)
- [Fusion 0.3 upstream release](https://github.com/dphfox/Fusion/releases/tag/v0.3-beta)
- [Pinned Fusion commit](https://github.com/dphfox/Fusion/commit/77e603534ff4013f4049611826ff0309d6000b15)

## Target `pesde.toml`

Replace `wally.toml` with a manifest equivalent to the following. Preserve normal TOML formatting, and generate the lockfile with Pesde rather than editing it manually.

```toml
name = "cameronpcampbell/supercorner_fusion03"
version = "0.1.1"
description = "Fusion 0.3 wrapper for Supercorner (A figma-inspired alternative to Roblox's UICorner)."
license = "MIT"
authors = ["Cameron P Campbell"]
repository = "https://github.com/cameronpcampbell/supercorner"

includes = [
    "pesde.toml",
    "README.md",
    "LICENSE.md",
    "src/**/*.luau",
]

[target]
environment = "roblox"
lib = "src/init.luau"
build_files = ["src"]

[indices]
default = "https://github.com/pesde-pkg/index"

[dependencies]
supercorner = { name = "cameronpcampbell/supercorner", version = "^0.1.1", target = "roblox" }
fusion = { repo = "dphfox/Fusion", rev = "77e603534ff4013f4049611826ff0309d6000b15" }
```

Do not add `default.project.json` to `includes`. Pesde's Roblox package format uses `target.build_files`, and Pesde explicitly forbids publishing `default.project.json` as part of a Roblox package.

## Implementation sequence

### 1. Replace Wally package metadata and generated files

In `supercorner_fusion03/`:

1. Add `pesde.toml` using the target manifest above.
2. Run `pesde install` from this directory and commit the generated `pesde.lock`.
3. Delete the tracked Wally files:
   - `wally.toml`
   - `wally.lock`
4. Delete Wally-specific package/project scaffolding that exists only to expose Wally's generated `_Index` tree:
   - `default.project.json`
   - `packages.project.json`
   - `packages_no_index.project.json`
   - `supercorner_fusion03_index.luau`
5. Remove the generated local `Packages/` directory if it exists. It is not tracked, but it must no longer be used by this subpackage.
6. Add a package-local `.gitignore` containing at least:

   ```gitignore
   /.pesde/
   /roblox_packages/
   /package.tar.gz
   ```

Do not publish `pesde.lock`; it is committed for reproducible development and CI installs but is intentionally absent from `includes`.

### 2. Convert source dependency paths and syntax

Pesde places dependency linker modules in a `roblox_packages` folder beside the package's `src` module. Use stable dependency aliases rather than versioned package folder names.

In `src/init.luau`, replace the Wally package root and both versioned requires with:

```luau
local Packages = script.Parent.roblox_packages
local Supercorner = require(Packages.supercorner)
local Fusion = require(Packages.fusion)
```

In both `src/atlas.luau` and `src/shared.luau`, use:

```luau
local Packages = script.Parent.Parent.roblox_packages
```

Then require `Packages.supercorner` where needed and `Packages.fusion` in all applicable files. The extra `.Parent` is required because these two modules are children of the `src` module, while `roblox_packages` is a sibling of `src`.

Replace every standalone `const` declaration in `supercorner_fusion03/src/**/*.luau` with `local`. At the time this plan was written, the affected bindings were:

- `CREATE_ONLY_PROPS`
- `SUPERCORNER_KEYS`
- `ATLAS_KEYS`
- `NON_PASSTHROUGH_KEYS`
- `UICORNER_HAS_INDIVIDUAL_RADII`

Do not otherwise refactor or change the Fusion wrapper's behavior or public API.

### 3. Rebuild the test project around Pesde's layout

Keep `test.project.json`, but remove its dependency on `packages.project.json`. Its Rojo tree should mirror the installed package layout:

```text
Packages/
  supercorner_fusion03   <- `src`
  roblox_packages/       <- generated Pesde dependency linkers
    fusion
    supercorner
```

Concretely, under the test script's `Packages` folder:

- Map `supercorner_fusion03` to `src`.
- Map `roblox_packages` to the generated `roblox_packages` directory.

Update both test scripts to use the new tree:

```luau
local Packages = script.Packages
local Fusion = require(Packages.roblox_packages.fusion)
local Supercorner = require(Packages.supercorner_fusion03)
```

Preserve the current test behavior. The package source itself must resolve the same `Packages.roblox_packages` sibling when it runs inside this test tree.

### 4. Update user-facing package documentation

Change `supercorner_fusion03/README.md` so it contains no Wally installation instructions. Use the Pesde package's underscore identity:

```sh
pesde add cameronpcampbell/supercorner_fusion03@0.1.1 -t roblox
```

Also show the direct manifest form:

```toml
[dependencies]
supercorner_fusion03 = { name = "cameronpcampbell/supercorner_fusion03", version = "^0.1.1", target = "roblox" }
```

Keep the existing usage and fallback-behavior documentation unless a require-path example needs a neutral name adjustment.

Update the existing `v0.1.1` changelog entry to mention the Pesde migration and new Pesde package name. Remove or rewrite the existing bullet that says Wally dependency resolution was fixed, because `v0.1.1` has not been tagged and this release will no longer be published to Wally.

### 5. Replace only the Fusion03 publishing workflow

Rewrite only `.github/workflows/supercorner_fusion03_release.yml`. Use `.github/workflows/supercorner_release.yml` as the structural reference, while retaining Fusion03-specific names, paths, tag parsing, changelog parsing, and release title.

Required workflow behavior:

1. Trigger only on tags matching `supercorner-fusion03-v*`.
2. Add a concurrency group based on `github.ref` and do not cancel an in-progress release.
3. Pin the downloaded CLI with:

   ```yaml
   env:
     PESDE_RELEASE: "v0.7.3+registry.0.2.3"
   ```

4. In preflight:
   - Check out the tagged commit.
   - Download the Linux Pesde binary from `pesde-pkg/pesde` using `gh release download` and `GH_TOKEN: ${{ github.token }}`. This download must be authenticated to avoid GitHub API limits.
   - Verify `pesde -v` reports the expected CLI.
   - Compare the version in `supercorner_fusion03/pesde.toml` with `${TAG#supercorner-fusion03-v}`.
   - Require an exact `# vX.Y.Z` changelog heading.
   - Run `pesde install --locked`.
   - Run `pesde publish --dry-run --yes` and treat either a nonzero exit or output containing `error occurred publishing` as failure.
   - Inspect `package.tar.gz` and compare it to the exact expected package file list.
5. The dry-run archive must contain exactly:

   ```text
   LICENSE.md
   README.md
   pesde.toml
   src/atlas.luau
   src/init.luau
   src/shared.luau
   ```

   Fail on missing or unexpected files. In particular, no test files, Wally files, lockfiles, generated dependency folders, project JSON, migration plan, or changelog should be shipped.
6. Create or update a draft GitHub release only after preflight succeeds.
7. Replace Wally release notes with:
   - Registry link: `https://pesde.dev/packages/cameronpcampbell/supercorner_fusion03`
   - CLI install command using the underscore package name.
   - Direct `pesde.toml` dependency form.
8. Put package publishing in its own `publish-package` job after draft-release creation.
9. Reuse the repository secret `PESDE_TOKEN`; do not use or reference `WALLY_TOKEN`. The existing secret value must include the `Bearer ` prefix because Pesde stores a token passed to `pesde auth login --token` verbatim.
10. Authenticate and verify identity before publishing:

    ```sh
    pesde auth login --token "$PESDE_TOKEN"
    pesde auth whoami
    ```

11. Publish from `supercorner_fusion03/` with `pesde publish --yes`.
12. Capture combined publish output with `tee`, enable `pipefail`, preserve a genuine nonzero exit status, and explicitly exit `1` if the log contains `error occurred publishing`. Use the already-fixed core Supercorner workflow as the exact guard reference.
13. Publish the draft GitHub release only in a final job that `needs: publish-package`. If Pesde fails or produces a false-success message, the GitHub release must remain a draft.
14. Remove all Wally installation, Rokit cache, Wally auth-file, and `wally publish` steps from this workflow. The workflow does not need Rokit because it downloads the pinned Pesde executable directly.

### 6. Local validation before committing

Run all commands from `supercorner_fusion03/` unless a different directory is stated.

1. Confirm the intended CLI:

   ```sh
   pesde -v
   ```

2. Generate and then verify the lockfile:

   ```sh
   pesde install
   pesde install --locked
   ```

3. Confirm dependency resolution:
   - Core Supercorner resolves from the Pesde index at a version satisfying `^0.1.1` with the `roblox` target.
   - Fusion resolves from Git at commit `77e603534ff4013f4049611826ff0309d6000b15`.
   - `roblox_packages/fusion` and `roblox_packages/supercorner` linker modules exist.
4. Ensure no invalid declarations remain:

   ```sh
   rg -n '\bconst\b' src test
   ```

   Expected result: no matches.
5. Ensure no package/workflow Wally references remain, excluding this planning document:

   ```sh
   rg -n -i 'wally|wally\.run|WALLY_TOKEN|UpliftGames' \
     . ../.github/workflows/supercorner_fusion03_release.yml \
     --glob '!PESDE_MIGRATION_PLAN.md'
   ```

   Expected result: no matches in the migrated package or its workflow.
6. Build the test project:

   ```sh
   rojo build test.project.json -o /tmp/supercorner_fusion03-test.rbxlx
   ```

7. Run the publish dry-run with the same false-success output guard used by CI:

   ```sh
   pesde publish --dry-run --yes
   ```

8. Inspect the archive:

   ```sh
   tar -tzf package.tar.gz | LC_ALL=C sort
   ```

   It must match the six-file list in the workflow section exactly.
9. Parse the workflow YAML and run `git diff --check`.
10. Review `git diff --name-only` and confirm changes are limited to `supercorner_fusion03/` and `.github/workflows/supercorner_fusion03_release.yml`.

### 7. Runtime smoke testing

Before release, open the Rojo test place and verify at least:

- The standard `Supercorner.new` example renders and reacts to radius/smoothing changes.
- `Supercorner.atlas` renders and animates across its keypoints.
- Fusion `Children` and `RootChildren` still mount at the expected hierarchy levels.
- `Button = true` still produces a `TextButton` root.
- Fill/stroke toggling and the `UICorner` fallback still behave as before.
- No require fails because of a missing versioned Wally `_Index` path.

Do not change public behavior to make the migration pass; any behavioral regression is a migration bug.

### 8. Release and post-publish verification

Only after all local validation succeeds:

1. Commit the migration, including `pesde.lock`.
2. Create and push tag `supercorner-fusion03-v0.1.1` at the migration commit.
3. Watch the dedicated Fusion03 workflow through all four phases: preflight, draft release, Pesde publish, and GitHub release publication.
4. Confirm the `Publish to pesde` log contains no `error occurred publishing` line and the job genuinely published the package.
5. Verify the package page exists:

   ```text
   https://pesde.dev/packages/cameronpcampbell/supercorner_fusion03
   ```

6. In a clean scratch Pesde Roblox project, run:

   ```sh
   pesde add cameronpcampbell/supercorner_fusion03@0.1.1 -t roblox
   pesde install --locked
   ```

7. Confirm the clean consumer receives the wrapper, native Pesde Supercorner dependency, and Git-pinned Fusion dependency with working linker modules.

If package publication fails, do not make the GitHub release public. Fix the cause and rerun the failed jobs. Pesde does not allow deleting a published package version, so the archive and metadata must be verified before the real publish; use yanking only if a broken version is accidentally published.

## Definition of done

The migration is complete only when all of the following are true:

- `supercorner_fusion03` has `pesde.toml` and a generated, committed `pesde.lock`.
- Its Pesde name is `cameronpcampbell/supercorner_fusion03`.
- It has no local Wally manifest, lockfile, generated Wally project scaffold, Wally registry dependency, Wally auth, or Wally publishing step.
- Supercorner resolves natively from Pesde at `^0.1.1`.
- Fusion resolves from the immutable upstream Fusion 0.3 Git commit.
- Source and tests use `roblox_packages` aliases rather than Wally `_Index` paths.
- No `const` declaration remains in package Luau files.
- The exact dry-run archive is correct and contains no development/generated files.
- The dedicated workflow fails on both real Pesde nonzero exits and Pesde's exit-zero error output.
- The GitHub release cannot become public unless Pesde publishing succeeds.
- A fresh consumer can install and run `cameronpcampbell/supercorner_fusion03@0.1.1` from Pesde.
- No React, core Supercorner, shared toolchain, or unrelated workflow file was changed.
