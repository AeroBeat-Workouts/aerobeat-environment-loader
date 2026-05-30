# AeroBeat Environment Loader — Device Fallback Repair

**Date:** 2026-05-29  
**Status:** Complete  
**Last Updated:** 2026-05-29 17:56 EDT  
**Blocked Reason:** None  
**Agent:** `chip`

---

## Goal

Repair `aerobeat-environment-loader` so it can load a simulated workout package YAML through the hidden `.testbed`, then add device-aware fallback environment selection so unsupported hardware loads each set’s fallback environment instead of its preferred environment.

---

## Overview

`aerobeat-environment-loader` has already been through a broad workout-package refactor, but Derrick called out that the repo is currently in a non-working state and now needs a focused repair slice rather than another broad architecture expansion. The immediate proving goal is not just “make tests pass” — it is to restore a truthful hidden `.testbed` scene that can load a simulated workout package YAML using the current `aerobeat-tool-*` dependency stack and then exercise a new device-aware environment-selection rule.

The new functional requirement introduces a contract change to the workout/environment YAML seam. Each set currently resolves to a single `environmentId`, and the YAML bridge maps that to one environment record. Derrick confirmed the new ownership model: fallback is set-level, every set must define a fallback or the workout YAML is invalid, and unsupported-device policy is owned by `aerobeat-environment-loader` through a repo-local asset file under `assets/` that is passed into the runtime. The first supported policy shape is a GPU blacklist with Intel Iris Xe as the first forced-fallback entry.

The repair should stay disciplined: truth the current broken state first, then define the YAML contract change, then fix the bridge/loader/testbed so the same simulated workout package can prove both branches — preferred on supported hardware and fallback on unsupported hardware / simulated Intel Iris Xe. The `.testbed` should use the real tool dependencies rather than custom shortcuts, and the device decision seam should be explicit enough that downstream workout-package behavior is auditable.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Owning repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader` |
| `REF-02` | Current workout-package testbed/media-stack plan | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.plans/2026-05-27-workout-package-testbed-and-media-loader-stack.md` |
| `REF-03` | Current loader runtime entrypoint | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/AeroEnvironmentLoader.gd` |
| `REF-04` | Current workout YAML bridge | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/AeroWorkoutYamlEnvironmentBridge.gd` |
| `REF-05` | Current committed all-kinds workout fixture | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/fixtures/workout_yaml_valid_all_kinds/workout.yaml` |
| `REF-06` | Hidden testbed dependency manifest | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/addons.jsonc` |
| `REF-07` | New device-detection singleton repo to integrate | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-device-detection` |
| `REF-08` | Environment-loader README / current repo truth | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/README.md` |
| `REF-09` | Prior memory on official workout/environment package decisions | `memory/2026-05-14.md#L17-L35` |

---

## Tasks

### Task 1: Audit the broken refactor state and define the repair seam

**Bead ID:** `aerobeat-environment-loader-ir6`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-08`, `REF-09`  
**Prompt:** Serve the `research` workflow role on the `primary` lane for `aerobeat-environment-loader-ir6`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-ir6 --status in_progress --json` when you start. Audit the current non-working state of `aerobeat-environment-loader`: identify exactly what is broken in the hidden `.testbed`, the workout YAML bridge, and the current fixture/test flow; verify the current dependency graph; and propose the narrowest truthful repair seam for adding device-aware fallback selection without widening scope unnecessarily. Include exact failures or breakpoints, not just general impressions.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/`

**Files Created/Deleted/Modified:**
- Audit notes / plan updates only unless a tiny unblocker is necessary for discovery

**Status:** ✅ Complete

**Results:** The research pass found three concrete blockers. First, the hidden `.testbed` is broken by stale GLTF facade references: `godot --headless --path .testbed --import` fails because `src/AeroEnvironmentLoader.gd` and `.testbed/tests/test_AeroEnvironmentLoader.gd` still preload `res://addons/aerobeat-tool-gltf-loader/src/AeroGLTFTool.gd`, but the declared addon actually exposes `src/AeroGLTFLoader.gd`; a stale undeclared `.testbed/addons/aerobeat-tool-gltf` leftover is masking that rename drift. Second, the workout YAML bridge and both committed/generated fixtures still encode the obsolete single-`environmentId` set contract, so they cannot represent Derrick’s required `preferredEnvironmentId` + `fallbackEnvironmentId` pair even after the parse failure is fixed. Third, there is no device-detection integration in this repo yet: no `.testbed/addons.jsonc` dependency on `aerobeat-tool-device-detection`, no loader-owned blacklist YAML asset under `assets/`, no loader routing logic, and no fallback-routing tests. The narrowest truthful repair seam is: (1) repair the stale GLTF facade references so the real loader suite runs again, (2) upgrade the bridge + fixtures/tests to the set-level preferred/fallback contract while keeping policy decisions out of the bridge, then (3) add loader-owned device-detection + blacklist routing in the loader between bridge resolution and `load_environment(...)`.

---

### Task 2: Extend the workout/environment YAML contract for preferred + fallback environments

**Bead ID:** `aerobeat-environment-loader-0ie`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-08`, `REF-09`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-0ie`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-0ie --status in_progress --json` when you start. Update the environment-loader-side workout YAML bridge and its fixture/test surface so each set must express both `preferredEnvironmentId` and `fallbackEnvironmentId`, and make workout-package validation fail when either is missing. Keep unsupported-device policy out of workout YAML; it is loader-owned runtime config, not package-owned data. Update repo-local docs/tests so the new contract is truthful and explicit.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/fixtures/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `src/AeroEnvironmentLoader.gd`
- `src/AeroWorkoutYamlEnvironmentBridge.gd`
- `.testbed/tests/test_AeroEnvironmentLoader.gd`
- `.testbed/tests/test_example.gd`
- `.testbed/fixtures/workout_yaml_valid_all_kinds/sets/*.yaml`
- `README.md`
- `plugin.cfg`

**Status:** ✅ Complete

**Results:** Landed in commit `c2b42d4` (`Repair loader GLTF bridge and workout fallback contract`) and pushed to `origin/main`. This bead repaired the stale GLTF facade drift that had been blocking the hidden `.testbed` and silently skipping the real loader suite: `src/AeroEnvironmentLoader.gd` and `.testbed/tests/test_AeroEnvironmentLoader.gd` now preload the real `aerobeat-tool-gltf-loader` facade path, and the vendor runtime adapter was updated to the current `aerobeat-vendor-godot-gltf` runtime-loader path while keeping the legacy path as fallback. The workout YAML bridge now requires set-level `preferredEnvironmentId` and `fallbackEnvironmentId`, fails validation if either is missing, and resolves/exposes both candidates through `preferred_*`, `fallback_*`, `environment_candidates`, and `selected_environment_role: preferred` metadata without putting policy logic into the bridge. Committed fixtures and helper-generated test packages were upgraded to the new pair contract, and repo docs/metadata were updated to match. Validation passed with `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -glog=1` (`31/31` passing, `813` asserts). The repo is now ready for Task 3 device-routing work.

---

### Task 3: Repair the hidden `.testbed` scene around simulated workout-package loading + device-aware selection

**Bead ID:** `aerobeat-environment-loader-h2a`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-environment-loader-h2a`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-h2a --status in_progress --json` when you start. Make the hidden `.testbed` scene work again using the simulated workout package YAML and the real `aerobeat-tool-*` dependency stack, add `aerobeat-tool-device-detection` as a dependency, and introduce a loader-owned unsupported-device YAML asset file under this repo’s `assets/` folder that is passed into the runtime as blacklist policy. On scene load, use device detection plus that GPU blacklist to decide whether each set resolves to its preferred environment or fallback environment. The first blacklisted GPU entry is Intel Iris Xe, and unsupported devices should always route to fallback.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/assets/`

**Files Created/Deleted/Modified:**
- `.testbed/addons.jsonc`
- `.testbed/project.godot`
- `.testbed/scripts/environment_testbed.gd`
- `.testbed/tests/test_AeroEnvironmentLoader.gd`
- `.testbed/tests/test_example.gd`
- `README.md`
- `assets/unsupported_device_policy.yaml`
- `src/AeroEnvironmentLoader.gd`

**Status:** ✅ Complete

**Results:** Task 3 is landed on `main` and `origin/main` with latest commit `be014c2` (`Add device-based workout environment fallback routing`), following earlier support commit `a06f28a` (`Add device-aware fallback routing to loader`). The hidden `.testbed` now declares `aerobeat-tool-device-detection`, autoloads `AeroDeviceDetection`, and the loader owns an unsupported-device YAML policy asset under `assets/unsupported_device_policy.yaml` with Intel Iris Xe blacklisted. Loader/runtime routing now selects preferred vs fallback after bridge resolution based on device detection plus the GPU blacklist, keeping policy out of workout YAML and out of the bridge. Repo-local tests now cover supported-device -> preferred, blacklisted Intel Iris Xe -> fallback, missing policy -> fallback, and invalid policy -> fallback, while the hidden `.testbed` still truthfully exercises the simulated workout-package flow. Validation passed with `godotenv addons install` from `.testbed`, `godot --headless --path .testbed --import --quit-after 1000`, `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -glog=1` (`34/34` passing), and a scene smoke load via `godot --headless --path .testbed --scene res://scenes/environment_testbed.tscn --quit-after 2`.

---

### Task 4: QA supported-vs-unsupported device routing in the hidden testbed

**Bead ID:** `aerobeat-environment-loader-5av`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Serve the `qa` workflow role on the `primary` lane for `aerobeat-environment-loader-5av`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-5av --status in_progress --json` when you start. Independently verify that the repaired hidden `.testbed` loads the simulated workout package, that supported-device flows choose preferred environments, that unsupported-device flows choose fallback environments, and that Intel Iris Xe is truthfully caught by the contract path. Use the highest-fidelity repo-local checks available and report exact commands and observed branch behavior.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/`

**Files Created/Deleted/Modified:**
- Validation artifacts only unless tiny approved QA fixes are needed

**Status:** ✅ Complete

**Results:** QA passed and the bead was closed. Independent verification confirmed the hidden `.testbed` still installs and boots with the current dependency stack, the simulated workout package loads through the real loader path, supported-device flows choose preferred environments, unsupported-device flows choose fallback environments, Intel Iris Xe is caught specifically by the blacklist contract path, and unsupported-device policy ownership remains loader-owned in `assets/unsupported_device_policy.yaml` rather than workout-owned YAML. The QA pass ran `godotenv addons install` from `.testbed`, `godot --headless --path .testbed --import --quit-after 1000`, the full GUT suite (`34/34` passing, `983` asserts), a headless scene smoke boot of `res://scenes/environment_testbed.tscn`, and a standalone absolute-path loader probe that called `AeroEnvironmentLoader.load_environment_from_workout_set(...)` directly. That probe verified: simulated supported device (`NVIDIA GeForce RTX 4090`) -> `selected_environment_role: preferred`; generic unsupported device (`gpu_name: unknown`) -> `selected_environment_role: fallback`, `reason: unsupported_device`; and blacklisted Intel simulation (`Intel Iris Xe Graphics`) -> `selected_environment_role: fallback`, `reason: blacklisted_gpu`, `matched_gpu_rule: Intel Iris Xe`. Non-blocking note: the scene smoke run emitted a placeholder `Environment` warning that did not break QA correctness.

---

### Task 5: Audit the repaired loader and the new fallback contract

**Bead ID:** `aerobeat-environment-loader-h2q`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** Serve the `auditor` workflow role on the `primary` lane for `aerobeat-environment-loader-h2q`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader`, run `bd update aerobeat-environment-loader-h2q --status in_progress --json` when you start. Independently truth-check the repaired environment-loader, the new preferred/fallback YAML contract, the device-detection integration, the hidden `.testbed` proving surface, and the QA evidence. Confirm the loader is back in a working state and the Intel Iris Xe fallback rule is represented coherently for downstream workout-package use.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/`

**Files Created/Deleted/Modified:**
- Plan updates only unless audit finds a real retry gap

**Status:** ✅ Complete

**Results:** Audit passed and the bead was closed. Independent review confirmed the new set-level preferred/fallback YAML contract is coherent and enforced, unsupported-device policy is loader-owned under `assets/unsupported_device_policy.yaml` rather than workout-owned YAML, device detection is integrated through the real hidden `.testbed` runtime path, and preferred/fallback routing works for supported devices, generic unsupported devices, and blacklisted Intel Iris Xe. The auditor re-ran the hidden `.testbed` addon install, import, full GUT suite (`34/34` passing, `983` asserts), a scene smoke load, and an independent routing probe using a temporary workout package with distinct preferred/fallback environments. QA evidence matched repo state, and no mirrored-addon or consumer-copy scope drift was found. Non-blocking note: the scene smoke run still emits the placeholder `Environment` warning, but it does not break correctness.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Repaired `aerobeat-environment-loader` back to a working state, fixed the stale GLTF facade drift that had been breaking the hidden `.testbed`, upgraded the workout-package set contract to require `preferredEnvironmentId` plus `fallbackEnvironmentId`, added loader-owned unsupported-device policy in YAML under `assets/unsupported_device_policy.yaml`, integrated `aerobeat-tool-device-detection`, and implemented real preferred-vs-fallback routing so blacklisted devices such as Intel Iris Xe always load each set’s fallback environment instead of its preferred environment.

**Reference Check:** `REF-01` through `REF-09` were satisfied across audit, implementation, QA, and final audit. The final seam matches the agreed ownership split: workout YAML owns set-level preferred/fallback IDs, while unsupported-device policy is loader-owned and runtime-passed from this repo.

**Commits:**
- `c2b42d4` - Repair loader GLTF bridge and workout fallback contract
- `a06f28a` - Add device-aware fallback routing to loader
- `be014c2` - Add device-based workout environment fallback routing

**Lessons Learned:** The first real blocker was hidden drift, not new feature code: stale GLTF facade preloads were making the import fail and silently skipping the real loader suite. Once the repo was brought back to truthful baseline, the cleanest architecture was to keep preferred/fallback candidate resolution in the workout bridge and reserve policy ownership for the loader runtime. That split made it straightforward to add loader-owned GPU blacklist YAML without polluting workout packages with hardware policy.

---

*Completed on 2026-05-29*
