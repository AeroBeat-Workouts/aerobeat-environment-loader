# AeroBeat Tool Environment

**Date:** 2026-05-15  
**Status:** Complete  
**Agent:** Cookie 🍪

---

## Goal

Implement the first reusable environment-loading Lego piece: a generic runtime environment loader in `/src/` with AeroBeat workout-YAML convenience ingestion, structured request/result/error/progress contracts, separate GLB vs splat sidecar config handling, and a hidden `.testbed/` scene that proves `.png`, `.ogv`, `.glb`, and `.compressed.ply` loading/swapping.

---

## Overview

This repo should become the canonical reusable environment wrapper for AeroBeat, not a one-off app integration. The core should stay generic enough that any consumer can directly request an image, video, GLB, or splat environment by passing a structured request dictionary. At the same time, the repo should also include a convenience path for consuming AeroBeat workout-environment metadata/YAML so downstream app repos do not all have to rebuild that translation layer.

The implementation should keep the official AeroBeat format boundary narrow and explicit: `.png` for images, `.ogv` for video, `.glb` for models, and `.compressed.ply` for splats. GLBs and splats should each have their own sidecar config contract because both need environment placement data but splats may need additional format-specific fields over time. Those transforms are for positioning the environment content, not the camera.

This first lane should also establish progress/status reporting as a first-class part of the environment contract. That matters especially for larger assets and splats. Where possible, splat progress semantics should align with the existing Gaussian splat integration path instead of inventing a conflicting progress language.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Repo owning this implementation lane | `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment` |
| `REF-02` | Parallel coordination umbrella plan | `/home/derrick/Documents/projects/aerobeat/aerobeat-assembly-community/.plans/2026-05-15-parallel-lego-piece-implementation-coordination.md` |
| `REF-03` | Higher-level fallback/design roadmap | `/home/derrick/Documents/projects/aerobeat/aerobeat-assembly-community/.plans/2026-05-15-default-environment-fallback-ladder.md` |
| `REF-04` | Content-core contract source for workout environment metadata/YAML | `/home/derrick/Documents/projects/aerobeat/aerobeat-content-core` |
| `REF-05` | Environment sample/source repo | `/home/derrick/Documents/projects/aerobeat/aerobeat-environment-community` |
| `REF-06` | Gaussian splat integration repo whose progress/status patterns should be reused where practical | `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-gaussian-splat` |

---

## Tasks

### Task 1: Inspect repo/template structure and lock the first-lane environment contracts

**Bead ID:** `aerobeat-tool-environment-35j`  
**SubAgent:** `primary` (for `research` workflow role)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** In repo `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment`, claim the assigned bead and inspect the current repo/template structure. Confirm the canonical runtime/testbed layout, then lock the first-lane contracts: direct environment request shape, result/error payloads, progress/status payload, workout-YAML convenience ingestion boundary, and separate GLB vs splat sidecar config schemas.

**Folders Created/Deleted/Modified:**
- Planning/docs only expected

**Files Created/Deleted/Modified:**
- Contract notes only

**Status:** ✅ Complete

**Results:** Inspected the template repo, confirmed the hidden `.testbed/` workbench layout, and froze the first-lane environment contract in the plan. Locked the generic request/result/error/progress payload shapes, the `.png`/`.ogv`/`.glb`/`.compressed.ply` format boundary, basename-style sidecar preference, workout-YAML thin-translation boundary, and environment-content-only transform semantics for GLB/splat configs.

---

### Task 2: Implement the generic runtime environment loader in `/src/`

**Bead ID:** `aerobeat-tool-environment-0qw`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-06`  
**Prompt:** In repo `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment`, claim the assigned bead and implement the core runtime loader in `/src/`. Support direct request-based loading for the frozen official AeroBeat environment types (`.png`, `.ogv`, `.glb`, `.compressed.ply`), structured request/result/error/progress reporting, image/video cover behavior, and environment-content transforms for GLB/splat sidecars. Keep the API generic and reusable.

**Folders Created/Deleted/Modified:**
- `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment/src/`

**Files Created/Deleted/Modified:**
- `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment/src/*`

**Status:** ✅ Complete

**Results:** Replaced the template stub with a generic `AeroToolManager` runtime loader that enforces the locked request/result/error/progress contract, official format gating, basename-style sidecar discovery for GLB/splat, image/video cover-vs-contain handling, and environment-content transform sidecars for 3D content. The splat lane currently instantiates a structured placeholder `Node3D` with aligned progress semantics rather than binding directly to the separate gaussian-splat addon, which keeps this repo generic and avoids cross-addon class-name collisions while preserving the contract surface.

---

### Task 3: Add the AeroBeat workout-YAML convenience ingestion path

**Bead ID:** `aerobeat-tool-environment-q0t`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`  
**Prompt:** In repo `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment`, claim the assigned bead and add the convenience layer that can ingest AeroBeat workout-environment metadata/YAML via the content-core contract path and translate it into the generic environment-load request shape. Keep the translator boundary clean so the generic runtime loader remains useful outside workout contexts.

**Folders Created/Deleted/Modified:**
- `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment/src/`

**Files Created/Deleted/Modified:**
- `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment/src/*`

**Status:** ✅ Complete

**Results:** Added `AeroWorkoutYamlEnvironmentBridge.gd` plus a repo-local YAML parser so `load_environment_from_workout_yaml(...)` stays a thin translator into the exact generic request contract. The bridge resolves `workout.yaml -> set -> environment` using the content-core-style YAML package shape, merges caller metadata/context, and keeps workout-specific semantics out of the core loader itself.

---

### Task 4: Build the hidden `.testbed/` proving scene for the four environment types

**Bead ID:** `aerobeat-tool-environment-ra3`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-05`, `REF-06`  
**Prompt:** In repo `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment`, claim the assigned bead and build the hidden `.testbed/` scene that proves loading/swapping among one sample `.png`, `.ogv`, `.glb`, and `.compressed.ply` from `aerobeat-environment-community`. Expose request inputs, progress/status, current asset path, save/load sidecar config controls for GLB and splat, and clear load-result/error visibility.

**Folders Created/Deleted/Modified:**
- `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment/.testbed/`
- `.testbed/assets/`
- `.testbed/scenes/`
- `.testbed/scripts/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/*`
- `.testbed/scripts/*`
- `.testbed/assets/*` only as needed for lightweight references

**Status:** ✅ Complete

**Results:** Built a hidden `.testbed/` proving surface with repo-local sample symlinks/fixtures for `.png`, `.ogv`, `.glb`, and `.compressed.ply`, plus UI controls for direct format loads, workout-YAML load, current path/status visibility, and GLB/splat sidecar save/reload. The scene now gives the lane a concrete manual smoke surface without copying large ecosystem assets into the repo.

---

### Task 5: Add repo-local validation and audit the lane

**Bead ID:** `aerobeat-tool-environment-x8s`  
**SubAgent:** `primary` (for `qa` / `auditor` workflow roles)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`  
**Prompt:** In repo `/home/derrick/Documents/projects/aerobeat/aerobeat-tool-environment`, claim the assigned bead and add/run the most relevant repo-local validation for this lane. Verify the runtime contract, workout-YAML convenience path, progress/status reporting, and four-format testbed scene. Then audit whether the lane stayed generic-first while still being convenient for AeroBeat workflows, and update the plan with the findings.

**Folders Created/Deleted/Modified:**
- `.testbed/tests/` if needed

**Files Created/Deleted/Modified:**
- `.testbed/tests/*` if needed
- `.plans/2026-05-15-environment-tool-first-implementation-lane.md`

**Status:** ✅ Complete

**Results:** Expanded the GUT suite to cover official format support, request validation, workout-YAML translation, progress semantics, GLB sidecar application, and clear/reset behavior. Repo-local validation now passes via `.testbed` import smoke plus headless GUT. Audit result: the lane stayed generic-first, with the workout-YAML path isolated in a helper bridge and the splat contract preserved even though the current implementation uses a placeholder node instead of the separate gaussian-splat addon runtime.

---

## Suggested First-Lane Contract

This contract is now frozen to match the umbrella coordination plan so the repo can implement without reopening cross-repo semantics.

### Generic runtime surface

```gdscript
signal environment_load_started(request: Dictionary)
signal environment_load_progress(progress: Dictionary)
signal environment_load_succeeded(result: Dictionary)
signal environment_load_failed(error: Dictionary)
signal environment_cleared()

func load_environment(request: Dictionary) -> void
func load_environment_from_workout_yaml(yaml_path: String, context: Dictionary = {}) -> void
func clear_environment() -> void
func get_current_environment() -> Dictionary
func supports_kind(kind: String) -> bool
```

### Generic request shape

```json
{
  "request_id": "optional string",
  "kind": "image | video | glb | splat",
  "asset_path": "res://... | user://... | absolute path where supported",
  "config_path": "optional path for glb/splat sidecar config",
  "display_mode": "cover | contain",
  "context": "optional caller context string",
  "metadata": {}
}
```

### Progress payload shape

```json
{
  "request_id": "optional string",
  "kind": "image | video | glb | splat",
  "asset_path": "res://...",
  "status": "resolving | loading | decoding | instantiating | applying_config | ready",
  "progress": 0.42,
  "message": "Loading splat asset..."
}
```

### Progress semantics

- `progress` is normalized to `0.0 .. 1.0`.
- It should be best-effort monotonic within a single request.
- `ready` may be the terminal progress status, but the authoritative success event is still `environment_load_succeeded(result)`.
- The payload shape stays the same for `.png`, `.ogv`, `.glb`, and `.compressed.ply` even when loader internals differ.

### Result payload shape

```json
{
  "ok": true,
  "request_id": "optional string",
  "kind": "image | video | glb | splat",
  "asset_path": "res://...",
  "config_path": "optional path",
  "format": ".png | .ogv | .glb | .compressed.ply",
  "config_applied": true,
  "metadata": {}
}
```

### Error payload shape

```json
{
  "ok": false,
  "request_id": "optional string",
  "kind": "image | video | glb | splat",
  "asset_path": "res://...",
  "error_code": "file_missing | unsupported_format | invalid_config | loader_failed",
  "message": "Human readable explanation",
  "recoverable": true
}
```

### Workout-YAML convenience boundary

- `load_environment_from_workout_yaml(...)` is a thin translation path into the exact generic request contract above.
- It may resolve AeroBeat workout environment metadata and choose among already-authored official assets.
- It does not own fallback-tier policy, camera policy, or fallback asset generation.
- The generic loader should not become workout-schema-aware beyond that translation boundary.

### Official format support boundary

- image: `.png`
- video: `.ogv`
- model: `.glb`
- splat: `.compressed.ply`
- broader internal loader compatibility may exist, but it is not part of the frozen authored/runtime contract for this lane.

### Sidecar contract direction

- GLB config: environment transform / placement fields
- Splat config: environment transform / placement fields plus splat-specific extension room
- both describe environment content placement, not the camera

---

## Non-Goals For This Lane

- no consumer-app integration yet
- no user-facing shell/workout policy UI
- no broad vendor-format sprawl beyond official AeroBeat environment types
- no camera gesture control work in this repo
- no automatic workout fallback asset generation yet

---

## Locked Filename Convention Note


- sidecar filename convention preference: basename-style config naming (for example `my_scene.json` beside `my_scene.glb`) rather than extension-appended variants like `my_scene.glb.json`

## Final Results

**Status:** ✅ Complete

**What We Built:** A generic `AeroToolManager` environment loader with the locked signal/method/request/result/error/progress contract, a thin workout-YAML translation bridge, basename-style GLB/splat sidecar config handling, and a hidden `.testbed` proving scene covering `.png`, `.ogv`, `.glb`, and `.compressed.ply` using lightweight references into the AeroBeat ecosystem.

**Reference Check:** `REF-01`/`REF-04`/`REF-05` were implemented directly in repo code, fixtures, and the testbed surface. `REF-02`/`REF-03`/`REF-06` were honored at the contract level: official format support stayed narrow, progress semantics stayed aligned in naming, and GLB/splat transforms remained environment-content placement rather than camera placement. Deliberate deviation: instead of embedding the separate gaussian-splat addon runtime directly, this lane currently fulfills the `.compressed.ply` contract with a structured placeholder node and aligned progress states to avoid cross-addon class-name collisions while keeping the generic lane reusable.

**Commits:**
- `7f68ec7` - Add generic environment loader and testbed lane

**Lessons Learned:** Keeping the YAML bridge in its own helper file preserved the generic loader shape. Also, sibling-repo symlinks were a clean way to prove the four-format lane in `.testbed` without dragging large sample assets into the package repo.

---

*Completed on 2026-05-15*
