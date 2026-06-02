# AeroBeat Environment Loader

`aerobeat-environment-loader` is the shared **environment loader/orchestrator package** for AeroBeat.

It consumes the contract surface from `aerobeat-environment-core` while keeping the concrete loader-facing
entrypoint and generic fulfillment behavior that current callers already use.

In plain English: `aerobeat-environment-core` owns the reusable request/result/error/progress/config
contract vocabulary, and this repo stays responsible for turning those requests into mounted scene
content.

## What this repo owns now

- the public `AeroEnvironmentLoader.gd` entrypoint used by current consumers
- environment orchestration concerns such as mount roots, current-environment replacement, and signal emission
- image fulfillment composed through the shared `AeroImageLoader` facade while keeping the active runtime/vendor backend swappable
- GLB fulfillment orchestrated through the shared `AeroGLTFLoader` facade while keeping the active runtime/vendor backend behind the tool stack
- shared video fulfillment composed through the stable `AeroVideoPlayerManager` abstraction while keeping the active playback backend swappable
- the lightweight workout/YAML bridge and parser that resolve a package into a generic environment request
- placeholder splat loading behavior until specialized fulfillment repos take over that path

## What this repo does not own

- the shared environment contract truth for request/result/error/progress/config types
- the canonical kind/status constants and request normalization helpers
- specialized fulfillment implementations that belong in sibling environment-family repos
- the shared GLTF and video tool/vendor stacks, beyond consuming them as dependencies here

## Repository Details

- **Type:** Environment loader/orchestrator package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Dependency contract:**
  - `aerobeat-environment-core` — required shared environment contract package
  - `aerobeat-tool-image-loader` — stable `AeroImageLoader` image-loading facade for environment image fulfillment
  - `aerobeat-vendor-godot-image` — current default image backend package that satisfies the shared image facade behind this repo
  - `aerobeat-tool-core` — shared video playback vocabulary consumed by the video stack
  - `aerobeat-tool-video-player` — stable `AeroVideoPlayerManager` playback facade for environment video fulfillment
  - `aerobeat-vendor-godot-video` — current default backend package that satisfies the shared video facade behind this repo
  - `aerobeat-tool-gltf-loader` — stable `AeroGLTFLoader` scene-loading facade for GLB/GLTF environment fulfillment
  - `aerobeat-vendor-godot-gltf` — current default runtime backend package behind the shared GLTF facade
  - additional adjacent environment-family repos only when this loader intentionally composes them

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

The repo root remains the package/published boundary for downstream consumers. Day-to-day development,
debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw
toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
/workspace/scripts/godotenv-sync --repo /workspace/projects/aerobeat/aerobeat-environment-loader
```

That restores this repo's current dev/test manifest into `.testbed/addons/`. For a truthful drift check,
clear any previously restored `.testbed/addons/` and `.testbed/.addons/` state first so missing explicit
dependencies cannot be masked by stale local installs. Canonically, the loader manifest now includes
`aerobeat-environment-core`, the shared image stack (`aerobeat-tool-image-loader`,
`aerobeat-vendor-godot-image`), the shared GLTF stack (`aerobeat-tool-gltf-loader`,
`aerobeat-vendor-godot-gltf`), the shared video stack (`aerobeat-tool-core`,
`aerobeat-tool-video-player`, `aerobeat-vendor-godot-video`), and repo-local test tooling.

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

## Current asset-path policy

- Request normalization accepts local `asset_path` values without requiring callers to pre-convert them to `res://`.
- **Video:** this loader now forwards existing absolute/package-local paths to `AeroVideoPlayerManager` instead of rejecting them early for not being `res://`. In the pinned `aerobeat-vendor-godot-video` slice, verified playback now includes both importable resource paths and absolute local file paths, with any backend limitations still surfaced as truthful playback-backed error details rather than a misleading loader-side gate.
- **Image:** this repo now routes image loading through `AeroImageLoader`, so packaged and external local PNGs follow the shared image tool/vendor path instead of a loader-owned `Image`/`ImageTexture` branch. Loader-side failures are mapped into environment-domain errors while the underlying runtime details stay in the image stack's result details.
- **GLB:** this repo now routes GLB loading through `AeroGLTFLoader`, so packaged and external local GLBs follow the shared GLTF tool/vendor path instead of a loader-owned imported-resource branch. Loader-side failures are mapped into environment-domain errors while the underlying runtime details stay in the GLTF stack's result details.
- Ownership boundary: if we need richer package-local image, video, or GLTF source transports later, that should land in the appropriate playback/resource dependency layers rather than as a silent vendor patch here.

## Workout YAML bridge contract

- Each set YAML record must now declare both `preferredEnvironmentId` and `fallbackEnvironmentId`.
- Workout-package validation fails if either field is missing.
- The bridge resolves **both** environment records and exposes them in the returned set descriptor / request metadata as `preferred_*`, `fallback_*`, and `environment_candidates`.
- The bridge still resolves and exposes the candidate metadata first; the loader then makes the preferred-vs-fallback decision at runtime before calling `load_environment(...)`.
- Unsupported-device routing policy remains loader-owned runtime logic and is intentionally **not** encoded in workout YAML.
- The committed loader-owned policy asset lives at `assets/unsupported_device_policy.yaml`, currently using a GPU blacklist with `Intel Iris Xe` as the first forced-fallback entry, and `.testbed/project.godot` wires `AeroDeviceDetection` so the hidden testbed can prove live/simulated device routing truthfully.

## Validation notes

- `.testbed/addons.jsonc` is the committed dev/test dependency contract.
- The canonical manifest for this repo is `aerobeat-environment-core` + the shared image stack + the shared GLTF stack + the shared video stack + `aerobeat-vendor-godot-unit-test`.
- `.testbed/project.godot` autoloads `AeroImageLoader` and `AeroDeviceDetection` so the hidden workbench proves the public image-loader/device-routing seams instead of direct vendor wiring.
- Repo-local tests validate both the current loader behavior and that the loader stays coherent with
  the core-owned contract subtree while routing image loads through `AeroImageLoader`, GLB loads through `AeroGLTFLoader`, and video loads through
  `AeroVideoPlayerManager` without exposing vendor-specific runtime details to loader consumers.
- The hidden testbed now ships a committed workout-package fixture at
  `.testbed/fixtures/workout_yaml_valid_all_kinds/workout.yaml` with one set each for image, video,
  GLB, and gaussian splat. The committed YAML stays lightweight by pointing at shared
  `/.testbed/assets/` fixtures through relative paths, and repo-local tests also copy that package to
  `/tmp`, materialize local media payloads under the copied package root, and load the copied
  `workout.yaml` by absolute path while explicitly switching image/video/GLB/splat sets to prove
  external-path loading semantics.
- Preserve the compatibility surface first: loader callers can keep using dictionary requests/signals
  even though the internal contract truth now lives in `aerobeat-environment-core` and image/video/GLB fulfillment
  now routes through the shared sibling packages.
