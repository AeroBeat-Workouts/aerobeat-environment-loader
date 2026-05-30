# AeroBeat Environment Loader — Testbed Image Stack and Warning Cleanup

**Date:** 2026-05-29  
**Status:** Complete  
**Last Updated:** 2026-05-29 23:10 EDT  
**Blocked Reason:** None  
**Agent:** `chip`

---

## Goal

Update the hidden `.testbed` so image environments load through `aerobeat-tool-image-loader`, reproduce and fix the repeat set-switch crash/warnings, and simplify the testbed info panel/UI based on Derrick’s manual testing notes.

---

## Overview

The previous repair slice got `aerobeat-environment-loader` back into a working state and added device-aware fallback routing, but Derrick’s manual test pass exposed three follow-up classes of work. First, image fulfillment in the testbed still uses the built-in Godot image path, while the intended architecture is to route image loading through `aerobeat-tool-image-loader` and `aerobeat-vendor-godot-image` so the vendor boundary stays swappable just like the video and GLTF stacks. Second, the runtime is still fragile when cycling sets repeatedly, especially returning to image/video after moving through image → video → GLB → splat, and the attached console screenshot strongly suggests both local warning cleanup and a likely vendor-video teardown bug around a freed instance during `_unbind_surface_resize`. Third, the testbed UI still contains extra explanatory paragraphs and the image display-mode selector Derrick no longer wants.

This follow-up plan should stay narrow and truthful. We need to first reproduce the exact repeat-switch failure in the real hidden `.testbed`, decide which warnings belong to `aerobeat-environment-loader` versus `aerobeat-vendor-godot-video`, and then land the image-stack dependency change, runtime regression fix, warning cleanup, and UI simplification with QA/audit. Because the console failure appears to cross the environment-loader and vendor-video boundary, the plan explicitly allows a child fix in `aerobeat-vendor-godot-video` if the teardown bug is proven upstream-owned, while keeping the parent coordination and proving surface in `aerobeat-environment-loader`.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Owning repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader` |
| `REF-02` | Completed fallback-repair plan to preserve context | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.plans/archive/2026-05-29-environment-loader-device-fallback-repair-plan.md` |
| `REF-03` | Current testbed scene controller | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/scripts/environment_testbed.gd` |
| `REF-04` | Current loader runtime | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/AeroEnvironmentLoader.gd` |
| `REF-05` | Current testbed addon manifest | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/addons.jsonc` |
| `REF-06` | Image loader singleton repo | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader` |
| `REF-07` | Godot image vendor repo | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-image` |
| `REF-08` | Godot video vendor repo likely implicated in teardown regression | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video` |
| `REF-09` | Attached warning/crash screenshot | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/05/30/image-c5da4eb7.png` |
| `REF-10` | Attached info-panel screenshot | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/05/30/image-62658588.png` |

---

## Tasks

### Task 1: Reproduce the repeat-switch failure and assign ownership for warnings/regressions

**Bead ID:** `aerobeat-environment-loader-leg`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** Serve the `research` workflow role on the `primary` lane for `aerobeat-environment-loader-leg`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-leg --status in_progress --json` when you start. Reproduce Derrick’s exact manual sequence in the hidden `.testbed` (image -> video -> glb -> splat -> image -> video), capture the real failure/warning set, and identify which issues belong to `aerobeat-environment-loader` versus an upstream dependency such as `aerobeat-vendor-godot-video` or `aerobeat-tool-video-player`. Produce a concrete repair map for image-stack migration, repeat-switch runtime stability, warning cleanup, and UI cleanup.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/`

**Files Created/Deleted/Modified:**
- Audit notes / plan updates only unless a tiny discovery unblocker is necessary

**Status:** ✅ Complete

**Results:** Reproduced Derrick’s exact sequence against the real hidden `.testbed`: image -> video -> glb -> splat -> image -> video. The final image -> video hop throws the red runtime error `Left operand of 'is' is a previously freed instance.` Ownership split is now clear. Consumer-side, `aerobeat-environment-loader/src/AeroEnvironmentLoader.gd` returns too early from `_unload_video_player_manager()` after `video_manager.unload()`, leaving the old surface to be freed while backend state still references it. Upstream, `aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd` throws the actual script error because `_unbind_surface_resize()` does not guard against a freed instance before type/signal checks. `aerobeat-tool-video-player` is not the primary owner for the narrow regression. The same research pass also confirmed that image loading is still inline in `AeroEnvironmentLoader._load_image()` rather than going through `aerobeat-tool-image-loader` / `aerobeat-vendor-godot-image`, and that the display-mode UI is misleading because video requests can ask for `cover` while runtime state still ends up `contain`. This means Task 3 needs child repo work in `aerobeat-vendor-godot-video`, followed by GodotEnv sync back in the consumer.

---

### Task 2: Migrate testbed image fulfillment to the shared image-loader stack

**Bead ID:** `aerobeat-environment-loader-3o4`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-3o4`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-3o4 --status in_progress --json` when you start. Update the environment-loader hidden `.testbed` and runtime seam so image environments are fulfilled through the `AeroImageLoader` singleton/service boundary instead of direct built-in Godot image loading. Add `aerobeat-tool-image-loader` and `aerobeat-vendor-godot-image` to the hidden `.testbed` dependency stack, wire the loader/runtime accordingly, and update tests/docs to keep the image vendor boundary explicitly swappable.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/`

**Files Created/Deleted/Modified:**
- `.testbed/addons.jsonc`
- `.testbed/project.godot`
- `src/AeroEnvironmentLoader.gd`
- `.testbed/tests/test_AeroEnvironmentLoader.gd`
- `.testbed/tests/test_example.gd`
- `README.md`
- `plugin.cfg`

**Status:** ✅ Complete

**Results:** Landed in commit `3b452a9` (`Route image environments through AeroImageLoader`) and pushed to `origin/main`. Image environments now route through `AeroImageLoader` instead of direct built-in `Image` / `ImageTexture` loading. The hidden `.testbed` now depends on `aerobeat-tool-image-loader` and `aerobeat-vendor-godot-image`, exposes `AeroImageLoader` in `.testbed/project.godot`, and the docs/tests were updated to make the image vendor boundary explicitly swappable. Validation passed with `godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, `godot --headless --path .testbed --import`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`37/37` passing, `1002` asserts).

---

### Task 3: Fix repeat set-switch runtime regression and clean up warnings

**Bead ID:** `aerobeat-environment-loader-zmd`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-08`, `REF-09`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-zmd`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-zmd --status in_progress --json` when you start. Fix the repeat-switch regression triggered by cycling image -> video -> glb -> splat -> image -> video, including the red freed-instance video teardown failure and the attached warning set. Research has already assigned the upstream runtime error to `aerobeat-vendor-godot-video`; child bead `aerobeat-vendor-godot-video-cf6` was created there for the backend guard fix. Land the environment-loader-side proving/consumer adjustments here, coordinate the upstream fix, and after the upstream fix lands use the repo-local GodotEnv sync flow to refresh dependencies and verify the consumer against the updated dependency state.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-video/`

**Files Created/Deleted/Modified:**
- `src/AeroEnvironmentLoader.gd`
- `.testbed/tests/test_AeroEnvironmentLoader.gd`
- upstream dependency file `aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd`
- upstream test `aerobeat-vendor-godot-video/.testbed/tests/test_AeroGodotVideoBackendFactory.gd`

**Status:** ✅ Complete

**Results:** This slice landed across the owning repos. Upstream, `aerobeat-vendor-godot-video` fixed the freed-surface backend guard in commit `12a0d61` (`Guard freed video surface teardown`) and added a regression test covering unload/detach/rebind/reload after a surface is freed. Consumer-side, `aerobeat-environment-loader` landed commit `bad8f51` (`Fix video teardown repeat-switch regression`) so `_unload_video_player_manager()` no longer returns immediately after `video_manager.unload()` and now explicitly detaches the old video surface before teardown completes. After refreshing dependencies through `/home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, validation passed with `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`39/39` passing, `1074` asserts). The exact repeated sequence `image -> video -> glb -> splat -> image -> video` was re-verified after refresh and the red runtime error `Left operand of 'is' is a previously freed instance.` did not recur.

---

### Task 4: Simplify the testbed info panel/UI copy and controls

**Bead ID:** `aerobeat-environment-loader-ypb`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`, `REF-10`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-ypb`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-ypb --status in_progress --json` when you start. Remove the top descriptive paragraph beginning with `Hidden workout package...`, remove the lower status-copy block beginning with `Workout package testbed ready...`, and remove the `cover` / `contain` display-mode UI control from the info panel. Keep the testbed useful for QA without the extra explanatory text.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/environment_testbed.tscn`
- `.testbed/scripts/environment_testbed.gd`

**Status:** ✅ Complete

**Results:** Landed in commit `43023e6` (`Clean up environment loader testbed UI`) and pushed to `origin/main`. This bead removed the top descriptive paragraph from the info panel, removed the lower startup/status-copy block from `_ready()`, and removed the `cover` / `contain` display-mode control from the testbed UI. The testbed was kept functional by hardwiring environment requests to `cover`. Initial validation was temporarily blocked by the image-stack dependency gap, which has since been resolved by Task 2; full consumer validation now belongs to the combined repeat-switch regression pass and QA.

---

### Task 5: QA the migrated image stack, repeat-switch flow, and cleaned UI

**Bead ID:** `aerobeat-environment-loader-ug8`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** Serve the `qa` workflow role on the `primary` lane for `aerobeat-environment-loader-ug8`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-ug8 --status in_progress --json` when you start. Independently verify that image environments now load through the shared image-loader stack, that the repeated set-switch flow no longer throws the freed-instance video teardown error, that the meaningful warning set is cleaned up, and that the UI copy/controls match Derrick’s screenshots and requests.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`

**Files Created/Deleted/Modified:**
- Validation artifacts only unless tiny approved QA fixes are needed

**Status:** ✅ Complete

**Results:** The initial QA pass correctly failed on the remaining placeholder `Environment` warning, which drove the narrow retry bead `aerobeat-environment-loader-qd6`. After commit `6e8a82a`, QA reran and passed. The rerun re-verified that image environments load through the shared image-loader stack, the real repeated sequence `image -> video -> glb -> splat -> image -> video` executes cleanly in the hidden `.testbed`, the freed-instance teardown regression does not recur, the UI cleanup matches Derrick’s request, and the placeholder `Environment` warning is gone from import/runtime output. Exact QA commands included `godot --headless --path .testbed --import`, the full GUT suite (`39/39` passing, `1074` asserts), and a real hidden `.testbed` runtime probe script that drove the committed workout fixture through the repeated sequence. Remaining import warning `ObjectDB instances leaked at exit` was treated as non-blocking because it did not affect correctness and is not the scoped warning that triggered the retry.

---

### Task 5b: Remove placeholder `Environment` node warning from the hidden testbed scene

**Bead ID:** `aerobeat-environment-loader-qd6`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-09`, `REF-10`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-qd6`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-qd6 --status in_progress --json` when you start. Fix the remaining hidden `.testbed` scene warning `Node Environment of type Environment cannot be created. A placeholder will be created instead.` Keep the fix narrow, validate the scene/import path, commit/push to `main`, and report exact files changed plus validation results so QA can be rerun cleanly.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/environment_testbed.tscn`
- any directly affected scene-support script if needed

**Status:** ✅ Complete

**Results:** Landed in commit `6e8a82a` and pushed to `origin/main`. The invalid child node `[node name="Environment" type="Environment" parent="WorldEnvironment"]` was replaced with a proper `Environment` subresource assigned via `WorldEnvironment.environment`, removing the placeholder warning while keeping the fix narrow to the hidden testbed scene file. Validation passed with `godot --headless --path .testbed --import` and `godot --headless --path .testbed --quit-after 1`, and the previous placeholder warning did not recur.

---

### Task 6: Audit the follow-up cleanup slice

**Bead ID:** `aerobeat-environment-loader-4s2`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01` through `REF-10`  
**Prompt:** Serve the `auditor` workflow role on the `primary` lane for `aerobeat-environment-loader-4s2`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-4s2 --status in_progress --json` when you start. Independently truth-check the image-loader migration, repeat-switch regression fix, warning cleanup, UI simplification, and QA evidence. Confirm the testbed now matches Derrick’s intended dependency architecture and no longer regresses on the repeated set-switch sequence.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/`

**Files Created/Deleted/Modified:**
- Plan updates only unless audit finds a real retry gap

**Status:** ✅ Complete

**Results:** Audit passed and the bead was closed. Independent audit verified the full follow-up slice across the owning repos: image environments now route through the shared image-loader stack, the repeated sequence `image -> video -> glb -> splat -> image -> video` no longer regresses, the freed-instance teardown error is gone, the placeholder `Environment` warning is gone, and the UI cleanup matches Derrick’s requested panel/control removals. The auditor rechecked the env-loader commits `3b452a9`, `bad8f51`, `43023e6`, and `6e8a82a`, the upstream vendor-video commit `12a0d61`, reran env-loader validation (`39/39` passing, `1074` asserts), reran vendor-video validation (`18/18` passing, `174` asserts), and drove the exact repeated runtime sequence independently. Scope-drift check passed: the backend guard fix stayed in `aerobeat-vendor-godot-video`, while environment-loader kept the consumer orchestration/testbed changes.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Completed the follow-up environment-loader cleanup slice. Image environments now load through the shared `AeroImageLoader` + `aerobeat-vendor-godot-image` stack, the repeated testbed sequence `image -> video -> glb -> splat -> image -> video` no longer regresses, the upstream freed-surface backend bug was fixed in `aerobeat-vendor-godot-video`, the consumer teardown bug was fixed in `aerobeat-environment-loader`, the placeholder `Environment` warning is gone, and the testbed UI now matches Derrick’s requested cleanup with the extra paragraphs and display-mode selector removed.

**Reference Check:** `REF-01` through `REF-10` were satisfied across reproduction, implementation, QA, and audit. Ownership stayed clean: shared backend guard fix in `aerobeat-vendor-godot-video`, consumer orchestration/image/testbed work in `aerobeat-environment-loader`.

**Commits:**
- `3b452a9` - Route image environments through AeroImageLoader
- `bad8f51` - Fix video teardown repeat-switch regression
- `43023e6` - Clean up environment loader testbed UI
- `6e8a82a` - Fix testbed WorldEnvironment scene resource
- `12a0d61` - Guard freed video surface teardown (`aerobeat-vendor-godot-video`)

**Lessons Learned:** The right split for this slice was cross-repo but ownership-disciplined. Image loading belonged behind the shared image tool/vendor boundary instead of inline in environment-loader, while the red repeat-switch failure was a two-part bug: a consumer teardown bug in env-loader and an upstream freed-instance guard bug in the video vendor backend. Once those landed in the correct repos and the consumer refreshed via GodotEnv sync, QA and audit could verify the whole sequence cleanly.

---

*Completed on 2026-05-29*
