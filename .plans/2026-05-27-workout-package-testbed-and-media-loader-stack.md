# AeroBeat Workout Package Testbed and Media Loader Stack

**Date:** 2026-05-27  
**Status:** In Progress  
**Last Updated:** 2026-05-27 17:26 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Refactor `aerobeat-environment-loader` so its testbed behaves like a workout-package proving surface, then land the missing or incomplete image/audio/gaussian-splat supporting repos needed for loading workout environments from arbitrary local package paths outside `res://`.

---

## Overview

This slice is no longer just a single-repo tweak. `aerobeat-environment-loader` remains the main proving surface, but the requested behavior depends on a cross-repo media stack: image, video, GLTF, gaussian splat, and now audio abstractions plus their Godot-vendor backends. The environment-loader testbed needs to become a workout-package simulator rather than a direct per-asset demo, with explicit `Load Workout` / `Unload Workout` controls and dynamically generated per-set load buttons after parsing a package-root `workout.yaml`.

The architectural direction stays consistent with the recent video and GLTF work: the environment loader should consume repo-level tool abstractions rather than raw vendor details, and workout packages must be loadable from arbitrary filesystem paths because real packages will arrive from mod.io downloads outside the Godot project tree. Real implementation work must stay in repo roots (`/src/`, `/assets/`, and `/.testbed/`) rather than inside generated `/addons/` mirrors, and each repo testbed should pull the repo root in via GodotEnv rather than editing mounted addon copies. This plan therefore starts with a repo and contract audit, then lands the needed vendor/tool surfaces, then rewires the environment-loader proving scene around a multi-set workout package example that exercises each supported environment type.

Because the requested scope includes partially refactored and newly created repos, the first execution step must verify current repo state, recent synced revisions, GodotEnv mount behavior, and whether any repo naming or README assumptions drifted from the live workspace. Local repo presence has now been confirmed across the requested stack after Derrick's `git-sync --all-aerobeat` refresh. One known non-blocking constraint is already accepted up front: gaussian splat loads should still be exercised during testing, but a known render bug means successful load attempts may not visibly render in screenshots yet. During execution, Beads bookkeeping also needed one correction: this repo's durable local Beads DB still uses the historical `aerobeat-tool-environment` prefix, so the temporary `aerobeat-environment-loader-*` IDs from the first pass were remapped onto real durable local bead IDs before continuing. Only after that audit should implementation branch into the per-repo coder → QA → auditor loop.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Main proving surface repo for this slice | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader` |
| `REF-02` | Latest completed GLTF chain handoff context | `/home/derrick/.openclaw/workspace/projects/openclaw-pico/handoffs/handoff-2026-05-26T21-30-30-04:00.md` |
| `REF-03` | Existing environment-loader first-lane plan and current contract baseline | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.plans/2026-05-15-environment-tool-first-implementation-lane.md` |
| `REF-04` | Gaussian splat tool repo to complete/refactor | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat` |
| `REF-05` | Existing GLTF tool repo to consume in the workout-package sample | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gltf` |
| `REF-06` | Existing video tool repo to consume in the workout-package sample | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player` |
| `REF-07` | New image tool repo expected by this slice | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader` |
| `REF-08` | New image vendor repo expected by this slice | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image` |
| `REF-09` | New audio tool repo expected by this slice | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player` |
| `REF-10` | New audio vendor repo expected by this slice | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio` |
| `REF-11` | Existing vendor repo whose functionality should be generalized out of environment-specific splat code | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs` |
| `REF-12` | User-provided public repo URL for gaussian-splat tool | `https://github.com/AeroBeat-Workouts/aerobeat-tool-gaussian-splat` |
| `REF-13` | User-provided public repo URL for image vendor wrapper | `https://github.com/AeroBeat-Workouts/aerobeat-vendor-godot-image` |
| `REF-14` | User-provided public repo URL for image tool wrapper | `https://github.com/AeroBeat-Workouts/aerobeat-tool-image-loader` |
| `REF-15` | User-provided public repo URL for audio vendor wrapper | `https://github.com/AeroBeat-Workouts/aerobeat-vendor-godot-audio` |
| `REF-16` | User-provided public repo URL for audio tool wrapper | `https://github.com/AeroBeat-Workouts/aerobeat-tool-audio-player` |

---

## Tasks

### Task 1: Audit and bootstrap the repo set for this slice

**Bead ID:** `aerobeat-environment-loader-m92`  
**SubAgent:** `primary` (for `research` workflow role)  
**Role:** `research`  
**References:** `REF-01`, `REF-04`, `REF-07`, `REF-08`, `REF-09`, `REF-10`, `REF-11`  
**Prompt:** In the AeroBeat workspace, claim the assigned bead and audit the repos required for the workout-package media stack. Confirm which repos already exist locally, clone any missing repos if they are intentionally absent but available from the user-provided remotes, inspect their current addon/testbed/readme state, verify GodotEnv mount assumptions, and produce a concrete implementation map for image/video/gltf/splat/audio responsibilities. Record any blockers or naming drift before implementation starts.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/`

**Files Created/Deleted/Modified:**
- Repo-local planning notes only at first

**Status:** ✅ Complete

**Results:** Audited the live repo stack after sync. Findings: `aerobeat-environment-loader`, `aerobeat-tool-gltf`, and `aerobeat-tool-video-player` already match the repo-root `src` + hidden `/.testbed/` direction well enough to build on. `aerobeat-tool-gaussian-splat` already contains a generic-manager-shaped implementation, but its README/test references still drift from the current layout and the exact environment-loader integration seam needs to be re-truthed before coding against it. `aerobeat-tool-image-loader` and `aerobeat-tool-audio-player` are still template shells. `aerobeat-vendor-godot-image` and `aerobeat-vendor-godot-audio` are the most incomplete repos: template READMEs/tests remain, repo-root `src/` is missing, and their current `.testbed` wiring still reflects placeholder/template assumptions. The audit also confirmed the accepted non-blocker that gaussian splat load attempts should still be exercised even though a known render bug may prevent visible output. Recommended implementation order: image vendor -> image tool, gaussian tool truthing/integration, environment-loader workout UX + package fixture, and audio vendor -> audio tool in parallel as a separate deliverable unless/until the environment contract explicitly needs audio.

---

### Task 2: Re-truth `aerobeat-tool-gaussian-splat` and lock the real integration seam

**Bead ID:** `aerobeat-tool-environment-7hu`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-04`, `REF-11`, `REF-12`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat`, claim the assigned bead and work from the truth of the current repo rather than an older refactor assumption. The repo already contains a generic-manager-shaped implementation; your job is to verify and tighten the real public API around `AeroGaussianSplatManager.gd`, remove or consolidate stale references/scripts/tests where appropriate, keep runtime logic in repo-root `src/`, make the runtime responsible for loading, placing, rotating, and unloading gaussian splats, and update the README/testbed/docs so they match the current architecture and the environment-loader integration seam. Exercise real load attempts in validation, but treat the known render-visibility bug as non-blocking.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/src/`
- `/.testbed/` as needed

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `README.md`
- `.testbed/*` as needed

**Status:** ✅ Complete

**Results:** Landed and pushed in `aerobeat-tool-gaussian-splat` as commit `566be90` (`Tighten gaussian splat repo-root runtime API`). The coder tightened the real repo-root API around `AeroGaussianSplatManager.gd`, removed stale lower-package assumptions, made the manager-facing runtime actions explicit (`load_splat`, `place_splat`, `rotate_splat`, `unload_splat`), kept the environment-loader seam in `AeroGaussianSplatEnvironmentFulfillment.gd`, and re-truthed the README/testbed/docs. Validation passed via `.testbed` addon install, headless import, GUT (`11/11`), and a real load smoke scene that successfully decoded a splat while still honoring the known non-blocking render-visibility bug.

---

### Task 3: Implement `aerobeat-vendor-godot-image`

**Bead ID:** `aerobeat-tool-environment-bhp`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-08`, `REF-13`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image`, claim the assigned bead and implement the Godot-native image vendor wrapper for loading local images from either `res://`, `user://`, or arbitrary absolute device paths into textures suitable for Aerobeat slots. Focus first on `.png` support, expose clean success/failure callbacks or signals, and build a `.testbed` file-picker demo that can preview the loaded image with stretch vs contain/cover-style display behavior.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `README.md`
- `.testbed/*`

**Status:** ✅ Complete

**Results:** Landed and pushed in `aerobeat-vendor-godot-image` as commit `8dad143` (`Implement Godot PNG image vendor wrapper`). The repo now contains a real vendor wrapper in `src/`, a checked-in PNG fixture under `assets/images/`, a hidden proving surface in `/.testbed/`, truthful package metadata/docs, and automated coverage for `.png` loading from `res://`, `user://`, project-relative paths, and arbitrary absolute local paths. Validation passed with `.testbed` headless import plus GUT (`3` scripts, `10` tests, `10` passing, `83` asserts).

---

### Task 4: Implement `aerobeat-tool-image-loader`

**Bead ID:** `aerobeat-tool-environment-4ae`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-07`, `REF-08`, `REF-13`, `REF-14`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader`, claim the assigned bead and build the singleton abstraction `AeroImageLoader.gd` on top of the chosen image vendor backend. Keep the consumer-facing contract vendor-agnostic, support slot placement plus maintain-aspect vs stretch behavior, and provide a `.testbed` file-picker proving scene that exercises those modes through the abstraction rather than the raw vendor package.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `README.md`
- `.testbed/*`

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 5: Implement `aerobeat-vendor-godot-audio`

**Bead ID:** `aerobeat-tool-environment-gau`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-10`, `REF-15`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio`, claim the assigned bead and implement the Godot-native audio backend with load, unload, play, pause, resume, stop, volume, and seek operations for `.wav` and `.ogg` assets from either packaged or arbitrary local paths. Expose promise-like success/failure callbacks plus state change listening, and build a `.testbed` player GUI driven by a file picker so the full behavior can be exercised manually.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `README.md`
- `.testbed/*`

**Status:** ✅ Complete

**Results:** Landed and pushed in `aerobeat-vendor-godot-audio` as commit `81eaee4` (`Implement Godot audio backend and testbed`). The repo now contains a real backend stack in `src/`, packaged `.ogg` and `.wav` fixtures in `assets/audio/`, a hidden proving surface in `/.testbed/` with file-picker and playback controls, truthful docs, and automated coverage for packaged and arbitrary absolute-path audio loads plus playback operations, callbacks, and state listening. Validation passed via `.testbed` addon install, headless import, and GUT (`12/12` passing).

---

### Task 6: Implement `aerobeat-tool-audio-player`

**Bead ID:** `aerobeat-tool-environment-6mp`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-09`, `REF-10`, `REF-15`, `REF-16`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, claim the assigned bead and build the vendor-agnostic audio singleton abstraction that mirrors the vendor backend’s load/unload/play/pause/resume/stop/volume/seek surface, including success/failure callbacks and state-change listening. Add a `.testbed` scene similar to the vendor proving surface, but pipe all playback through the tool abstraction.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `README.md`
- `.testbed/*`

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 7: Rework `aerobeat-environment-loader` into a workout-package-driven testbed

**Bead ID:** `aerobeat-tool-environment-4oi`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, claim the assigned bead and refactor `environment_testbed.tscn` so it is explicitly a workout-package proving surface. Replace direct per-asset demo controls with `Load Workout` and `Unload Workout`, open a file picker targeted at a package-root `workout.yaml`, support packages outside `res://`, unload the current environment cleanly, remove dynamically generated set buttons on unload, and after a workout loads generate `Load Set 1`, `Load Set 2`, etc. buttons for each set so the user can load environments from the package via the repo-level tool abstractions.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/environment_testbed.tscn`
- `.testbed/scripts/*`
- `src/*.gd`
- `README.md` / docs if needed

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 8: Add a repo-local workout package fixture that covers image/video/glb/splat

**Bead ID:** `aerobeat-tool-environment-92e`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, claim the assigned bead and create a lightweight workout-package example for the testbed. It should include one set per supported environment type currently in scope for environment loading: image, video, GLB, and gaussian splat. Prefer lightweight/local fixtures or symlink/reference strategies over copying large media blobs, and ensure the package-root `workout.yaml` proves external-path loading semantics.

**Folders Created/Deleted/Modified:**
- `/.testbed/fixtures/` or equivalent repo-local sample area

**Files Created/Deleted/Modified:**
- workout package sample files
- `workout.yaml`
- docs describing the fixture

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 8b: Rename the committed workout fixture and prove one-set-per-kind switching

**Bead ID:** `aerobeat-tool-environment-67g`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, claim the assigned bead and tighten the newly landed committed workout-package fixture. Rename the misleading fixture directory so its name matches the fact that it contains one set per supported environment kind, and strengthen the proof surface around changing media type per set in a single workout package. Keep the package lightweight, preserve external absolute-path package semantics, update the hidden `/.testbed/` defaults/docs as needed, and expand repo-local validation so image/video/GLB/splat set switching in one workout is explicitly covered.

**Folders Created/Deleted/Modified:**
- `/.testbed/fixtures/` or equivalent repo-local sample area

**Files Created/Deleted/Modified:**
- workout package sample files
- `workout.yaml`
- docs/tests describing the fixture and set-switching proof

**Status:** ✅ Complete

**Results:** Landed and pushed in `aerobeat-environment-loader` as commit `441277e` (`Rename all-kinds workout fixture and tighten set-switch proof`). The committed workout-package fixture directory was renamed from `workout_yaml_valid_image` to `workout_yaml_valid_all_kinds` so the fixture name now truthfully matches its contents: one set each for image, video, GLB, and gaussian splat. The hidden `/.testbed/` default fixture path and README/docs were updated accordingly. Repo-local validation was expanded with an explicit absolute-path workout-package test that iterates one copied package’s set order and proves `build_request_from_workout_set(...)` switches image/video/GLB/splat request kind + asset path correctly while preserving lightweight external absolute-path package semantics. Validation passed via `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`28/28` tests passing, `626` asserts).

---

### Task 8c: Fix committed workout fixture splat asset format/path mismatch

**Bead ID:** `aerobeat-tool-environment-h7s`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-11`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, claim the assigned bead and fix the committed workout fixture so its splat set actually passes the end-to-end workout-package flow. Align the fixture asset path/format with the loader’s current `kind: splat` contract (`.compressed.ply`), preserve the one-workout one-set-per-kind proving goal, and rerun the relevant repo-local validation for the environment-loader workout-package seam.

**Status:** ✅ Complete

**Results:** Landed and pushed in `aerobeat-environment-loader` as commit `5d544b9` (`Fix workout-package splat fixture contract`). The committed all-kinds workout fixture now points its splat set at the loader's required `.compressed.ply` resource while preserving the sibling `.json` sidecar config arrangement. Repo-local validation was expanded with a direct absolute-package splat-set success test, and the end-to-end workout-package splat seam now passes through `load_environment_from_workout_set(...)`.

---

### Task 9: QA the vendor/tool/testbed stack end-to-end

**Bead ID:** `aerobeat-tool-environment-83x`  
**SubAgent:** `primary` (for `qa` workflow role)  
**Role:** `qa`  
**References:** `REF-01` through `REF-11`  
**Prompt:** Claim the assigned bead and run end-to-end QA across the new/updated repos. Verify image/audio vendor testbeds, image/audio tool testbeds, gaussian-splat proving behavior, and the environment-loader workout-package flow including external absolute-path package loading and proper unload/reload button behavior. Capture exact validation commands, artifacts, and any behavior gaps that need retry work.

**Folders Created/Deleted/Modified:**
- Validation artifact directories only as needed

**Files Created/Deleted/Modified:**
- Plan updates only unless QA requires tiny fixes on an approved retry

**Status:** ✅ Complete

**Results:** QA passed across the landed stack after a focused retry on the environment-loader splat seam. Image/audio/video vendor+tool repos all passed repo-local validation, GLTF vendor+tool multi-instance/transform proving passed, and gaussian-splat proving passed with the known render limitation called out truthfully. The environment-loader workout-package flow now passes the required external absolute-path package load, unload/reload button behavior, and one-workout one-set-per-kind switching across image/video/GLB/splat. QA bead `aerobeat-tool-environment-83x` was closed once the splat fixture blocker was resolved and the stack was judged ready for independent audit.

---

### Task 10: Audit the finished stack and close the loop

**Bead ID:** `aerobeat-tool-environment-mal`  
**SubAgent:** `primary` (for `auditor` workflow role)  
**Role:** `auditor`  
**References:** `REF-01` through `REF-16`  
**Prompt:** Claim the assigned bead and independently audit the completed work against this plan, the code diffs, the repo READMEs/testbeds, and the validation evidence. Confirm that the environment-loader now behaves as a workout-package proving surface, that external-path loading really works, that vendor details are abstracted behind the tool layers where intended, and that the gaussian-splat/image/audio repos truthfully match their new architecture.

**Folders Created/Deleted/Modified:**
- None expected

**Files Created/Deleted/Modified:**
- Plan updates only

**Status:** ⏳ Pending

**Results:** Not started.

---

## Final Results

**Status:** ⚠️ Partial / Handoff

**What We Built:** The original workout-package environment-loader slice is now substantially complete: vendor/tool stacks for image, audio, video, GLTF, and gaussian-splat were landed; the environment-loader hidden testbed was refactored into a workout-package proving surface with `Load Workout` / `Unload Workout` and per-set load buttons; a committed one-workout all-kinds fixture now proves switching across image/video/GLB/splat; remote URL image loading, mount-path-safe vendor image loading, loop + multi-slot audio/video behavior, and multi-instance/transform GLTF and splat proving were all added across their respective repos. The end-to-end QA seam is now green and ready for independent audit.

**Reference Check:** `REF-01` through `REF-16` were used across the slice; the remaining missing check is the still-pending independent auditor pass on bead `aerobeat-tool-environment-mal`. Additional requested autoplay and content-schema transform-metadata audit scopes were added to the plan but not yet executed in this session handoff.

**Commits:**
- `566be90` - Tighten gaussian splat repo-root runtime API
- `8dad143` - Implement Godot PNG image vendor wrapper
- `1d054c2` - Build AeroImageLoader singleton abstraction
- `81eaee4` - Implement Godot audio backend and testbed
- `b651614` - Implement tool audio playback abstraction
- `608c1d9` - Make vendor image package mount-path safe
- `b86b0c3` - Add remote URL support to Godot image vendor
- `bc349db` - Expose remote image URL loading through wrapper
- `91caa2e` - Refactor workout package testbed flow
- `6e701f2` - Add multi-environment workout package fixture
- `441277e` - Rename all-kinds workout fixture and tighten set-switch proof
- `5d544b9` - Fix workout-package splat fixture contract
- `2556e6f` - Add loop and multi-slot Godot audio playback
- `82ec47b` - Add loop and multi-slot support to tool audio
- `96093d6` - Add multi-video support and loop behavior at vendor layer
- `c59293e` - Add loop and multi-slot support to tool video
- `399c77a` - Add multi-instance GLTF runtime loading
- `5d51e66` - Add multi-instance GLTF tool support
- `4ea283c` - Add GDGS transform proving controls
- `85bfe50` - Add gaussian splat transform reporting and parent placement

**Lessons Learned:** The biggest practical integration risks were not the core loader APIs but stale addon installs, fixture truth mismatches, and historical path assumptions. The workout-package proof only became audit-ready once the committed fixture matched the actual `.compressed.ply` splat contract and QA exercised the full absolute-path package seam. Beads bookkeeping also needed an early correction because the durable local DB still used the historical `aerobeat-tool-environment` prefix.

---

## Additional Requested Scope (added 2026-05-27 10:58 EDT)

- Add `loop` functionality to the singleton/backend logic in:
  - `aerobeat-vendor-godot-audio`
  - `aerobeat-tool-audio-player`
  - `aerobeat-vendor-godot-video`
  - `aerobeat-tool-video-player`
- Treat looping as a supported configuration that can be enabled or disabled.
- Expose loop controls in each repo’s hidden `/.testbed/` GUI so the behavior can be exercised manually.
- Fold loop verification into the eventual QA/audit pass for this plan.

### Task 11: Add loop support to `aerobeat-vendor-godot-audio`

**Bead ID:** `aerobeat-tool-environment-1ls`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-10`, `REF-15`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio`, claim the assigned bead and add loop enable/disable support to the singleton/backend logic. Make it part of the supported playback configuration, expose it through the hidden `/.testbed/` GUI, and update docs/tests so loop behavior is verified for the vendor layer.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `.testbed/*`
- `README.md` if needed

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 12: Add loop support to `aerobeat-tool-audio-player`

**Bead ID:** `aerobeat-tool-environment-az9`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-09`, `REF-10`, `REF-15`, `REF-16`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, claim the assigned bead and add loop enable/disable support to the tool abstraction on top of the vendor audio backend. Expose loop controls in the hidden `/.testbed/` GUI, keep the abstraction vendor-agnostic, and update docs/tests so loop behavior is verified through the tool layer.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `.testbed/*`
- `README.md` if needed

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 13: Add loop support to `aerobeat-vendor-godot-video`

**Bead ID:** `aerobeat-tool-environment-1i9`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video`, claim the assigned bead and add loop enable/disable support to the vendor video backend logic. Make looping a supported configuration, expose it via the hidden `/.testbed/` GUI, and update docs/tests so loop behavior is verified at the vendor layer.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `.testbed/*`
- `README.md` if needed

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 14: Add loop support to `aerobeat-tool-video-player`

**Bead ID:** `aerobeat-tool-environment-szb`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, claim the assigned bead and add loop enable/disable support to the tool abstraction on top of the vendor video backend. Expose loop controls in the hidden `/.testbed/` GUI, keep the abstraction vendor-agnostic, and update docs/tests so loop behavior is verified through the tool layer.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `.testbed/*`
- `README.md` if needed

**Status:** ⏳ Pending

**Results:** Not started.

**Ordering Note:** Intended execution order is vendor-audio -> tool-audio and vendor-video -> tool-video. If Beads dependency wiring remains unavailable in the current local DB, follow this ordering from the plan directly and include it in QA/audit verification.

### Task 15: Make `aerobeat-vendor-godot-image` mount-path-safe without a `/.testbed/src/` bridge

**Bead ID:** `aerobeat-tool-environment-blk`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-08`, `REF-13`, `REF-14`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image`, claim the assigned bead and remove the need for the hidden consumer-testbed `/.testbed/src/` bridge by making the vendor package fully mount-path-safe when consumed via GodotEnv/addon mounting. Eliminate brittle `res://src/...` root assumptions, keep real work in repo-root `src/` and `/.testbed/`, update tests/docs, and verify the consumer-style proving surface still works without patching generated `/addons/` mirrors.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image/src/`
- `/.testbed/`

**Files Created/Deleted/Modified:**
- `src/*.gd`
- `.testbed/*`
- `README.md` if needed

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 16: Add true remote URL image loading across vendor + tool layers

**Bead ID:** `aerobeat-tool-environment-5ce`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-07`, `REF-08`, `REF-13`, `REF-14`  
**Prompt:** Coordinate the next image-loading slice across `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image` and `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader`. Add truthful support for remote `http/https` URL image loading in addition to existing local-path loading, keep the vendor layer responsible for fetch/decode details, expose the capability cleanly through the tool abstraction, update hidden `/.testbed/` GUIs for manual proving, and expand tests/docs so local-path vs remote-URL behavior is explicit.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/src/`
- both repos' `/.testbed/`

**Files Created/Deleted/Modified:**
- vendor image `src/*.gd`
- tool image `src/*.gd`
- both repos' `.testbed/*`
- both repos' `README.md` as needed

**Status:** ⏳ Pending

**Results:** Not started.

---

## Additional Requested Scope (added 2026-05-27 12:44 EDT)

- Add multi-audio support to:
  - `aerobeat-vendor-godot-audio`
  - `aerobeat-tool-audio-player`
- Add multi-video support to:
  - `aerobeat-vendor-godot-video`
  - `aerobeat-tool-video-player`
- Add multi-gltf support to:
  - `aerobeat-vendor-godot-gltf`
  - `aerobeat-tool-gltf`
- The goal is to bring those media stacks up to parity with the already-landed multi-image support in `aerobeat-vendor-godot-image` and `aerobeat-tool-image-loader`.
- Each affected repo’s hidden `/.testbed/` human-verifiable scene/project should demonstrate multiple independently controllable slots/surfaces, similar to the image repos.
- Add position, rotation, and scale support to:
  - `aerobeat-vendor-godot-gltf`
  - `aerobeat-tool-gltf`
  - `aerobeat-vendor-gdgs`
  - `aerobeat-tool-gaussian-splat`
- For 3D assets, loading should support attaching to a parent object and applying transform settings after load.
- Each affected 3D repo’s hidden `/.testbed/` human-verifiable scene/project should expose those transform controls for verification.

### Task 17: Add multi-audio support to `aerobeat-vendor-godot-audio`

**Bead ID:** `aerobeat-tool-environment-l2j`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-10`, `REF-15`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio`, claim the assigned bead and add multi-audio support so multiple audio slots/instances can be loaded and controlled independently, similar to the multi-image pattern. Update the hidden `/.testbed/` scene/project so multiple audio slots can be exercised by a human with independent settings and controls, and update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 18: Add multi-audio support to `aerobeat-tool-audio-player`

**Bead ID:** `aerobeat-tool-environment-vr8`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-09`, `REF-10`, `REF-15`, `REF-16`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, claim the assigned bead and add multi-audio support to the tool abstraction on top of the vendor layer. Multiple audio slots/instances should be independently controllable in the hidden `/.testbed/` proving surface, mirroring the multi-image pattern while keeping the abstraction vendor-agnostic. Update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 19: Add multi-video support to `aerobeat-vendor-godot-video`

**Bead ID:** `aerobeat-tool-environment-jhk`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video`, claim the assigned bead and add multi-video support so multiple video slots/instances can be loaded and controlled independently, similar to the multi-image pattern. Update the hidden `/.testbed/` scene/project so multiple video slots can be exercised by a human with independent settings and controls, and update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 20: Add multi-video support to `aerobeat-tool-video-player`

**Bead ID:** `aerobeat-tool-environment-3q0`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, claim the assigned bead and add multi-video support to the tool abstraction on top of the vendor layer. Multiple video slots/instances should be independently controllable in the hidden `/.testbed/` proving surface, mirroring the multi-image pattern while keeping the abstraction vendor-agnostic. Update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 21: Add multi-GLTF support plus transform controls to `aerobeat-vendor-godot-gltf`

**Bead ID:** `aerobeat-tool-environment-9tc`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-05`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf`, claim the assigned bead and add multi-GLTF support plus position/rotation/scale controls so multiple GLTF assets can be loaded as independent instances attached to parent objects with transform settings applied after load. Update the hidden `/.testbed/` proving surface for human verification and update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 22: Add multi-GLTF support plus transform controls to `aerobeat-tool-gltf`

**Bead ID:** `aerobeat-tool-environment-4ja`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-05`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gltf`, claim the assigned bead and add multi-GLTF support plus position/rotation/scale controls to the tool abstraction on top of the vendor layer. Multiple GLTF instances should be independently controllable in the hidden `/.testbed/` proving surface while keeping the abstraction vendor-agnostic. Update docs/tests accordingly.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 23: Add transform controls to `aerobeat-vendor-gdgs`

**Bead ID:** `aerobeat-tool-environment-rtz`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-11`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`, claim the assigned bead and add position/rotation/scale support to the vendor testbed/proving surface so loaded splat assets can be attached to a parent object and have transform settings applied and verified by a human.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 24: Add transform controls to `aerobeat-tool-gaussian-splat`

**Bead ID:** `aerobeat-tool-environment-osb`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-04`, `REF-11`, `REF-12`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat`, claim the assigned bead and add position/rotation/scale support to the tool/runtime seam plus the hidden `/.testbed/` proving surface so loaded splat assets can be attached to a parent object and have transform settings applied and verified by a human.

**Status:** ⏳ Pending

**Results:** Not started.

**Ordering Note:** Intended execution order is vendor-audio -> tool-audio, vendor-video -> tool-video, vendor-gltf -> tool-gltf, and vendor-gdgs -> tool-gaussian-splat. If Beads dependency wiring remains unavailable in the current local DB, follow this ordering from the plan directly and include it in QA/audit verification.

## Additional Requested Scope (added 2026-05-27 17:09 EDT)

### Task 25: Add autoplay support to `aerobeat-vendor-godot-video`

**Bead ID:** `aerobeat-tool-environment-zks`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video`, claim the assigned bead and add autoplay support to the singleton/backend logic plus the hidden `/.testbed/` scene. Make autoplay a supported configuration that can be enabled or disabled and verify it truthfully in docs/tests.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 26: Add autoplay support to `aerobeat-tool-video-player`

**Bead ID:** `aerobeat-tool-environment-o6y`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, claim the assigned bead and add autoplay support to the tool abstraction plus the hidden `/.testbed/` scene. Keep the abstraction vendor-agnostic and verify autoplay behavior truthfully in docs/tests.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 27: Add autoplay support to `aerobeat-vendor-godot-audio`

**Bead ID:** `aerobeat-tool-environment-18p`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-10`, `REF-15`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio`, claim the assigned bead and add autoplay support to the singleton/backend logic plus the hidden `/.testbed/` scene. Make autoplay a supported configuration that can be enabled or disabled and verify it truthfully in docs/tests.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 28: Add autoplay support to `aerobeat-tool-audio-player`

**Bead ID:** `aerobeat-tool-environment-r2x`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-09`, `REF-10`, `REF-15`, `REF-16`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, claim the assigned bead and add autoplay support to the tool abstraction plus the hidden `/.testbed/` scene. Keep the abstraction vendor-agnostic and verify autoplay behavior truthfully in docs/tests.

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 29: Audit content repos for GLB and splat transform metadata support

**Bead ID:** `aerobeat-tool-environment-h1t`  
**SubAgent:** `primary` (for `research` workflow role)  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-11`  
**Prompt:** Audit the relevant AeroBeat content/config repos and the current workout/environment metadata flow to determine how GLB and gaussian splat environments should gain position/rotation/scale metadata in workout packages. Identify the owning schema/contracts, the repos/files that need to change, how that metadata should flow through content -> package -> loader/tool/vendor layers, and what plan slices should be added next so background environments can load with the expected transform settings.

**Status:** ⏳ Pending

**Results:** Not started.

**Ordering Note:** Intended execution order for this added scope is vendor-video -> tool-video, vendor-audio -> tool-audio, plus a separate research audit for content/schema changes before implementation of workout-package transform metadata.

---

*Completed on Pending*
