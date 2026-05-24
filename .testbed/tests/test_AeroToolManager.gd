extends GutTest

const AERO_TOOL_MANAGER_SCRIPT = preload("res://../src/AeroToolManager.gd")
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("res://../src/AeroWorkoutYamlEnvironmentBridge.gd")
const CORE_CONSTANTS_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/globals/aero_environment_constants.gd")
const CORE_REQUEST_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_request.gd")
const CORE_RESULT_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_result.gd")
const CORE_PROGRESS_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_progress.gd")
const CORE_ERROR_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_error.gd")
const CORE_REQUEST_VALIDATOR_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/validators/environment_request_validator.gd")

func _make_manager() -> Dictionary:
	var root := Node.new()
	add_child_autofree(root)
	var canvas_root := Control.new()
	canvas_root.name = "CanvasRoot"
	root.add_child(canvas_root)
	var world_root := Node3D.new()
	world_root.name = "WorldRoot"
	root.add_child(world_root)
	var manager = AERO_TOOL_MANAGER_SCRIPT.new()
	manager.canvas_root_path = NodePath("../CanvasRoot")
	manager.world_root_path = NodePath("../WorldRoot")
	root.add_child(manager)
	return {
		"root": root,
		"canvas_root": canvas_root,
		"world_root": world_root,
		"manager": manager,
	}

func test_loader_constants_match_environment_core_contract() -> void:
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.KIND_IMAGE, CORE_CONSTANTS_SCRIPT.KIND_IMAGE)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.KIND_VIDEO, CORE_CONSTANTS_SCRIPT.KIND_VIDEO)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.KIND_GLB, CORE_CONSTANTS_SCRIPT.KIND_GLB)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.KIND_SPLAT, CORE_CONSTANTS_SCRIPT.KIND_SPLAT)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.STATUS_READY, CORE_CONSTANTS_SCRIPT.STATUS_READY)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.ERROR_INVALID_REQUEST, CORE_CONSTANTS_SCRIPT.ERROR_INVALID_REQUEST)
	assert_eq(AERO_TOOL_MANAGER_SCRIPT.OFFICIAL_FORMATS, CORE_CONSTANTS_SCRIPT.OFFICIAL_FORMATS)

func test_supports_kind_and_official_formats_are_locked() -> void:
	var manager = AERO_TOOL_MANAGER_SCRIPT.new()
	assert_true(manager.supports_kind("image"))
	assert_true(manager.supports_kind("video"))
	assert_true(manager.supports_kind("glb"))
	assert_true(manager.supports_kind("splat"))
	assert_false(manager.supports_kind("gif"))
	assert_eq(manager._detect_format("res://foo/bar/example.compressed.ply"), ".compressed.ply")
	assert_eq(manager._preferred_config_path("res://foo/bar/example.glb"), "res://foo/bar/example.json")
	assert_eq(manager._preferred_config_path("res://foo/bar/example.compressed.ply"), "res://foo/bar/example.json")
	manager.free()

func test_normalize_request_rejects_kind_extension_mismatch() -> void:
	var manager = AERO_TOOL_MANAGER_SCRIPT.new()
	var result := manager._normalize_request({
		"kind": "image",
		"asset_path": "res://assets/videos/calm_blue_sea_1.ogv",
	})
	assert_false(result.get("ok", false))
	assert_eq(result.get("error_code", ""), manager.ERROR_UNSUPPORTED_FORMAT)
	manager.free()

func test_normalize_request_matches_environment_core_validator() -> void:
	var manager = AERO_TOOL_MANAGER_SCRIPT.new()
	var request := {
		"request_id": "  glb-sidecar-test  ",
		"kind": " GLB ",
		"asset_path": "res://assets/models/alien-planet.glb",
		"display_mode": "contain",
		"metadata": {"from_test": true},
	}
	var manager_result := manager._normalize_request(request)
	var core_result: Dictionary = CORE_REQUEST_VALIDATOR_SCRIPT.normalize_request_dict(request)
	assert_true(manager_result.get("ok", false))
	assert_true(core_result.get("ok", false))
	assert_eq(manager_result.get("request_dict", {}), core_result.get("request_dict", {}))
	manager.free()

func test_workout_yaml_bridge_translates_to_generic_request_shape() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var result := bridge.build_request_from_workout_yaml(ProjectSettings.globalize_path("res://fixtures/workout_yaml_valid_image/workout.yaml"), {
		"request_id": "yaml-bridge-test",
		"display_mode": "contain",
		"metadata": {"from_test": true},
	})
	assert_true(result.get("ok", false))
	var request: Dictionary = result.get("request", {})
	assert_eq(request.get("request_id", ""), "yaml-bridge-test")
	assert_eq(request.get("kind", ""), "image")
	assert_true(String(request.get("asset_path", "")).ends_with("demo.png"))
	assert_eq(request.get("display_mode", ""), "contain")
	assert_true(Dictionary(request.get("metadata", {})).get("from_test", false))
	assert_eq(Dictionary(request.get("metadata", {})).get("source", ""), "workout_yaml")
	var request_model = CORE_REQUEST_SCRIPT.new(request)
	assert_eq(request_model.kind, "image")
	assert_eq(request_model.display_mode, "contain")

func test_load_environment_from_workout_yaml_emits_progress_and_success() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var progress_events: Array[Dictionary] = []
	manager.environment_load_progress.connect(func(progress: Dictionary) -> void:
		progress_events.append(progress)
	)
	manager.load_environment_from_workout_yaml("res://fixtures/workout_yaml_valid_image/workout.yaml", {
		"request_id": "workout-image-load",
		"display_mode": "contain",
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "workout-image-load")
	assert_eq(result.get("kind", ""), "image")
	assert_eq(result.get("format", ""), ".png")
	assert_true(progress_events.size() >= 3)
	assert_eq(progress_events[0].get("status", ""), manager.STATUS_RESOLVING)
	assert_eq(progress_events[progress_events.size() - 1].get("status", ""), manager.STATUS_READY)
	var last_progress := -1.0
	for progress in progress_events:
		var value := float(progress.get("progress", 0.0))
		assert_true(value >= 0.0 and value <= 1.0)
		assert_true(value >= last_progress)
		last_progress = value
		var progress_model = CORE_PROGRESS_SCRIPT.new(progress)
		assert_eq(progress_model.status, String(progress.get("status", "")))
	var result_model = CORE_RESULT_SCRIPT.new(result)
	assert_eq(result_model.kind, "image")
	assert_eq(result_model.format, ".png")
	var current: Dictionary = manager.get_current_environment()
	assert_eq(current.get("asset_path", ""), result.get("asset_path", ""))
	assert_eq(current.get("kind", ""), "image")
	assert_eq((setup["canvas_root"] as Control).get_child_count(), 1)
	await get_tree().process_frame

func test_load_environment_applies_glb_sidecar_config() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.load_environment({
		"request_id": "glb-sidecar-test",
		"kind": "glb",
		"asset_path": "res://assets/models/alien-planet.glb",
		"display_mode": "cover",
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("kind", ""), "glb")
	assert_eq(result.get("config_path", ""), "res://assets/models/alien-planet.json")
	assert_true(result.get("config_applied", false))
	assert_eq((setup["world_root"] as Node3D).get_child_count(), 1)
	var node := (setup["world_root"] as Node3D).get_child(0) as Node3D
	assert_not_null(node)
	assert_almost_eq(node.position.y, -1.0, 0.001)
	assert_almost_eq(node.scale.x, 1.5, 0.001)
	var result_model = CORE_RESULT_SCRIPT.new(result)
	assert_eq(result_model.kind, "glb")
	assert_true(result_model.config_applied)
	await get_tree().process_frame

func test_video_load_uses_shared_video_player_stack() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.load_environment({
		"request_id": "video-stack-test",
		"kind": "video",
		"asset_path": "res://assets/videos/calm_blue_sea_1.ogv",
		"display_mode": "cover",
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("kind", ""), "video")
	assert_eq((setup["canvas_root"] as Control).get_child_count(), 1)
	var surface := (setup["canvas_root"] as Control).get_child(0) as Control
	assert_not_null(surface)
	assert_eq(surface.name, "EnvironmentVideoSurface")
	assert_true(surface.get_child_count() >= 1)
	var playback_state: Dictionary = result.get("playback_state", {})
	assert_eq(playback_state.get("state", ""), "playing")
	assert_true(bool(playback_state.get("surface_attached", false)))
	var media_info: Dictionary = result.get("media_info", {})
	assert_eq(media_info.get("path", ""), "res://assets/videos/calm_blue_sea_1.ogv")
	assert_false(media_info.has("vendor"))
	assert_false(media_info.has("backend_family"))
	assert_false(result.has("video_manager"))
	assert_false(result.has("playback_backend"))
	assert_false(result.has("playback_backend_family"))
	assert_false(playback_state.has("backend"))
	assert_false(playback_state.has("backend_family"))
	await get_tree().process_frame

func test_video_stack_failures_bridge_into_environment_error_details() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.load_environment({
		"request_id": "missing-video-import",
		"kind": "video",
		"asset_path": "res://assets/videos/does_not_exist.ogv",
		"metadata": {"source": "test"},
	})
	var error: Dictionary = await manager.environment_load_failed
	assert_false(error.get("ok", true))
	assert_eq(error.get("error_code", ""), manager.ERROR_FILE_MISSING)
	assert_eq(error.get("message", ""), "Godot could not load the requested video stream resource.")
	var details: Dictionary = error.get("details", {})
	assert_eq(details.get("subsystem", ""), "video")
	assert_eq(details.get("stage", ""), "load")
	assert_eq(details.get("resource_path", ""), "res://assets/videos/does_not_exist.ogv")
	assert_false(details.has("backend"))
	assert_false(details.has("backend_family"))
	assert_false(details.has("backend_script"))
	assert_eq(Dictionary(details.get("video_error", {})).get("code", ""), "backend_stream_load_failed")
	assert_false(Dictionary(details.get("video_error", {})).has("vendor"))
	assert_false(Dictionary(details.get("video_error", {})).has("backend_family"))
	assert_eq(Dictionary(details.get("state", {})).get("state", ""), "error")
	var error_model = CORE_ERROR_SCRIPT.new(error)
	assert_eq(error_model.request_id, "missing-video-import")
	assert_eq(error_model.metadata.get("source", ""), "test")
	assert_eq(error_model.details.get("subsystem", ""), "video")
	await get_tree().process_frame

func test_failure_payload_round_trips_through_core_error_contract() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.load_environment({
		"request_id": "bad-video-load",
		"kind": "video",
		"asset_path": "/tmp/outside-project.ogv",
		"metadata": {"source": "test"},
	})
	var error: Dictionary = await manager.environment_load_failed
	assert_false(error.get("ok", true))
	assert_eq(error.get("error_code", ""), manager.ERROR_FILE_MISSING)
	var error_model = CORE_ERROR_SCRIPT.new(error)
	assert_eq(error_model.request_id, "bad-video-load")
	assert_eq(error_model.metadata.get("source", ""), "test")
	assert_eq(error_model.details, {})
	await get_tree().process_frame

func test_clear_environment_unloads_video_manager_state() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.load_environment({
		"request_id": "clear-video-test",
		"kind": "video",
		"asset_path": "res://assets/videos/calm_blue_sea_1.ogv",
		"display_mode": "cover",
	})
	await manager.environment_load_succeeded
	var video_manager = manager._video_player_manager
	assert_not_null(video_manager)
	manager.clear_environment()
	await get_tree().process_frame
	var state: Dictionary = video_manager.get_state()
	assert_eq(state.get("state", ""), "idle")
	assert_false(bool(state.get("surface_attached", true)))
	assert_false(bool(state.get("media_loaded", true)))
	assert_eq(manager.get_current_environment(), {})
	assert_eq((setup["canvas_root"] as Control).get_child_count(), 0)

func test_clear_environment_emits_signal_and_resets_state() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var cleared := {"count": 0}
	manager.environment_cleared.connect(func() -> void:
		cleared["count"] += 1
	)
	manager.load_environment({
		"request_id": "clear-test",
		"kind": "image",
		"asset_path": "res://assets/images/perfect-hue-may-14-2026.png",
	})
	await manager.environment_load_succeeded
	manager.clear_environment()
	await get_tree().process_frame
	assert_eq(cleared["count"], 1)
	assert_true(manager.get_current_environment().is_empty())
	assert_eq((setup["canvas_root"] as Control).get_child_count(), 0)
