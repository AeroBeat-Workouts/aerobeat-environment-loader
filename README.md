# AeroBeat Environment Loader

`aerobeat-environment-loader` is the shared **environment loader/orchestrator package** for AeroBeat.

It consumes the contract surface from `aerobeat-environment-core` while keeping the concrete loader-facing
entrypoint and generic fulfillment behavior that current callers already use.

In plain English: `aerobeat-environment-core` owns the reusable request/result/error/progress/config
contract vocabulary, and this repo stays responsible for turning those requests into mounted scene
content.

## What this repo owns now

- the public `AeroToolManager.gd` compatibility entrypoint used by current consumers
- environment orchestration concerns such as mount roots, current-environment replacement, and signal emission
- built-in image and GLB fulfillment owned directly in this repo
- shared video fulfillment composed through the stable `AeroVideoPlayerManager` abstraction while keeping the active playback backend swappable
- the lightweight workout/YAML bridge and parser that resolve a package into a generic environment request
- placeholder splat loading behavior until specialized fulfillment repos take over that path

## What this repo does not own

- the shared environment contract truth for request/result/error/progress/config types
- the canonical kind/status constants and request normalization helpers
- specialized fulfillment implementations that belong in sibling environment-family repos
- the shared video playback contract/facade/backend repos, beyond consuming them as dependencies here

## Repository Details

- **Type:** Environment loader/orchestrator package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Dependency contract:**
  - `aerobeat-environment-core` — required shared environment contract package
  - `aerobeat-tool-core` — shared video playback vocabulary consumed by the video stack
  - `aerobeat-tool-video-player` — stable `AeroVideoPlayerManager` playback facade for environment video fulfillment
  - `aerobeat-vendor-godot-video` — current default backend package that satisfies the shared video facade behind this repo
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

That restores this repo's current dev/test manifest into `.testbed/addons/`. Canonically, the loader
manifest now includes `aerobeat-environment-core` plus the shared video stack (`aerobeat-tool-core`,
`aerobeat-tool-video-player`, `aerobeat-vendor-godot-video`) and repo-local test tooling.

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
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

## Validation notes

- `.testbed/addons.jsonc` is the committed dev/test dependency contract.
- The canonical manifest for this repo is `aerobeat-environment-core` + the shared video stack + `gut`.
- Repo-local tests validate both the current loader behavior and that the loader stays coherent with
  the core-owned contract subtree while routing video loads through `AeroVideoPlayerManager` without
  exposing vendor-specific playback details to loader consumers.
- Preserve the compatibility surface first: loader callers can keep using dictionary requests/signals
  even though the internal contract truth now lives in `aerobeat-environment-core` and video playback
  now routes through the shared sibling packages.
