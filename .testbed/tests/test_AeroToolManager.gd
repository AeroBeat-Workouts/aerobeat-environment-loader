extends GutTest

const AERO_TOOL_MANAGER_SCRIPT = preload("res://../src/AeroToolManager.gd")
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("res://../src/AeroWorkoutYamlEnvironmentBridge.gd")

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
	await get_tree().process_frame

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
