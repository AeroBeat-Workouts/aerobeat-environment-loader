extends GutTest

const AERO_ENVIRONMENT_LOADER_SCRIPT = preload("res://../src/AeroEnvironmentLoader.gd")
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("res://../src/AeroWorkoutYamlEnvironmentBridge.gd")
const AERO_GLTF_TOOL_SCRIPT = preload("res://addons/aerobeat-tool-gltf/src/AeroGLTFTool.gd")
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
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
	manager.canvas_root_path = NodePath("../CanvasRoot")
	manager.world_root_path = NodePath("../WorldRoot")
	root.add_child(manager)
	return {
		"root": root,
		"canvas_root": canvas_root,
		"world_root": world_root,
		"manager": manager,
	}

func _copy_fixture_to_temp(source_path: String, extension: String) -> String:
	var source_absolute := ProjectSettings.globalize_path(source_path)
	var read_handle := FileAccess.open(source_absolute, FileAccess.READ)
	assert_not_null(read_handle)
	var bytes := read_handle.get_buffer(read_handle.get_length())
	read_handle.close()
	var target_path := "/tmp/aerobeat-environment-loader-%s.%s" % [str(Time.get_unix_time_from_system()), extension]
	var write_handle := FileAccess.open(target_path, FileAccess.WRITE)
	assert_not_null(write_handle)
	write_handle.store_buffer(bytes)
	write_handle.close()
	return target_path

func _copy_fixture_file(source_absolute: String, target_absolute: String) -> void:
	var read_handle := FileAccess.open(source_absolute, FileAccess.READ)
	assert_not_null(read_handle)
	var bytes := read_handle.get_buffer(read_handle.get_length())
	read_handle.close()
	var write_handle := FileAccess.open(target_absolute, FileAccess.WRITE)
	assert_not_null(write_handle)
	write_handle.store_buffer(bytes)
	write_handle.close()

func _copy_fixture_directory_recursive(source_absolute: String, target_absolute: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(target_absolute), OK)
	var dir := DirAccess.open(source_absolute)
	assert_not_null(dir)
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var source_path := source_absolute.path_join(entry)
		var target_path := target_absolute.path_join(entry)
		if dir.current_is_dir():
			_copy_fixture_directory_recursive(source_path, target_path)
		else:
			_copy_fixture_file(source_path, target_path)
	dir.list_dir_end()

func _copy_workout_fixture_package_to_temp() -> Dictionary:
	var suffix := "%s-%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	var package_dir := "/tmp/aerobeat-environment-loader-workout-%s" % suffix
	var source_dir := ProjectSettings.globalize_path("res://fixtures/workout_yaml_valid_image")
	_copy_fixture_directory_recursive(source_dir, package_dir)
	return {
		"package_dir": package_dir,
		"workout_path": package_dir.path_join("workout.yaml"),
		"asset_path": package_dir.path_join("media/environments/demo.png"),
	}

func _make_multi_set_workout_package() -> Dictionary:
	var package_copy := _copy_workout_fixture_package_to_temp()
	var package_dir := String(package_copy.get("package_dir", ""))
	var second_environment_path := package_dir.path_join("environments/ab-environment-image-demo-2.yaml")
	var second_environment_file := FileAccess.open(second_environment_path, FileAccess.WRITE)
	assert_not_null(second_environment_file)
	second_environment_file.store_string("\n".join([
		"schemaId: aerobeat.environment.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"environmentId: ab-environment-image-demo-2",
		"environmentName: Image Demo Environment Two",
		"type: image_background",
		"resourcePath: media/environments/demo.png",
	]))
	second_environment_file.close()

	var second_set_path := package_dir.path_join("sets/ab-set-image-demo-round-2.yaml")
	var second_set_file := FileAccess.open(second_set_path, FileAccess.WRITE)
	assert_not_null(second_set_file)
	second_set_file.store_string("\n".join([
		"schemaId: aerobeat.set.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"setId: ab-set-image-demo-round-2",
		"setName: Image Demo Round Two",
		"environmentId: ab-environment-image-demo-2",
	]))
	second_set_file.close()

	var workout_file := FileAccess.open(String(package_copy.get("workout_path", "")), FileAccess.WRITE)
	assert_not_null(workout_file)
	workout_file.store_string("\n".join([
		"schemaId: aerobeat.workout-package.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"workoutId: ab-workout-image-demo",
		"workoutName: Image Demo Workout",
		"packageVersion: 1.0.0",
		"setOrder:",
		"  - ab-set-image-demo-round",
		"  - ab-set-image-demo-round-2",
	]))
	workout_file.close()
	return package_copy

func test_loader_exports_renamed_environment_identity() -> void:
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
	var script: Script = manager.get_script()
	assert_false(script.resource_path.ends_with("AeroToolManager.gd"))
	assert_true(script.resource_path.ends_with("AeroEnvironmentLoader.gd"))
	manager.free()

func test_loader_video_stack_stays_on_shared_facade() -> void:
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
	var script: Script = manager.get_script()
	var source_text := FileAccess.get_file_as_string(script.resource_path)
	assert_true(source_text.contains('preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerManager.gd")'))
	assert_false(source_text.contains("VideoStreamPlayer"))
	manager.free()

func test_loader_glb_stack_stays_on_shared_facade() -> void:
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
	var script: Script = manager.get_script()
	var source_text := FileAccess.get_file_as_string(script.resource_path)
	assert_true(source_text.contains('preload("res://addons/aerobeat-tool-gltf/src/AeroGLTFTool.gd")'))
	assert_true(source_text.contains("load_scene({"))
	assert_false(source_text.contains("PackedScene).instantiate()"))
	manager.free()

func test_loader_constants_match_environment_core_contract() -> void:
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.KIND_IMAGE, CORE_CONSTANTS_SCRIPT.KIND_IMAGE)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.KIND_VIDEO, CORE_CONSTANTS_SCRIPT.KIND_VIDEO)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.KIND_GLB, CORE_CONSTANTS_SCRIPT.KIND_GLB)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.KIND_SPLAT, CORE_CONSTANTS_SCRIPT.KIND_SPLAT)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.STATUS_READY, CORE_CONSTANTS_SCRIPT.STATUS_READY)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.ERROR_INVALID_REQUEST, CORE_CONSTANTS_SCRIPT.ERROR_INVALID_REQUEST)
	assert_eq(AERO_ENVIRONMENT_LOADER_SCRIPT.OFFICIAL_FORMATS, CORE_CONSTANTS_SCRIPT.OFFICIAL_FORMATS)

func test_supports_kind_and_official_formats_are_locked() -> void:
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
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
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
	var result := manager._normalize_request({
		"kind": "image",
		"asset_path": "res://assets/videos/calm_blue_sea_1.ogv",
	})
	assert_false(result.get("ok", false))
	assert_eq(result.get("error_code", ""), manager.ERROR_UNSUPPORTED_FORMAT)
	manager.free()

func test_normalize_request_matches_environment_core_validator() -> void:
	var manager = AERO_ENVIRONMENT_LOADER_SCRIPT.new()
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

func test_workout_yaml_bridge_accepts_absolute_workout_yaml_path() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _copy_workout_fixture_package_to_temp()
	var workout_path := String(package_copy.get("workout_path", ""))
	var result := bridge.build_request_from_workout_yaml(workout_path, {
		"request_id": "yaml-bridge-absolute-workout",
		"metadata": {"source": "test"},
	})
	assert_true(result.get("ok", false))
	var request: Dictionary = result.get("request", {})
	assert_eq(request.get("request_id", ""), "yaml-bridge-absolute-workout")
	assert_eq(request.get("kind", ""), "image")
	assert_eq(request.get("asset_path", ""), String(package_copy.get("asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("package_dir", ""), String(package_copy.get("package_dir", "")))
	assert_eq(metadata.get("workout_path", ""), workout_path)
	assert_eq(metadata.get("source", ""), "workout_yaml")
	assert_eq(metadata.get("environment_record_path", ""), String(package_copy.get("package_dir", "")).path_join("environments/ab-environment-image-demo.yaml"))

func test_workout_yaml_bridge_accepts_absolute_package_directory_path() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _copy_workout_fixture_package_to_temp()
	var package_dir := String(package_copy.get("package_dir", ""))
	var result := bridge.build_request_from_workout_yaml(package_dir, {
		"request_id": "yaml-bridge-absolute-package",
	})
	assert_true(result.get("ok", false))
	var request: Dictionary = result.get("request", {})
	assert_eq(request.get("request_id", ""), "yaml-bridge-absolute-package")
	assert_eq(request.get("kind", ""), "image")
	assert_eq(request.get("asset_path", ""), String(package_copy.get("asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("package_dir", ""), package_dir)
	assert_eq(metadata.get("workout_path", ""), package_dir.path_join("workout.yaml"))

func test_inspect_workout_package_returns_manifest_for_each_set() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _make_multi_set_workout_package()
	var result := bridge.inspect_workout_package(String(package_copy.get("workout_path", "")))
	assert_true(result.get("ok", false))
	assert_eq(result.get("workout_id", ""), "ab-workout-image-demo")
	assert_eq(result.get("workout_name", ""), "Image Demo Workout")
	var set_order: Array = result.get("set_order", [])
	assert_eq(set_order.size(), 2)
	assert_eq(String(set_order[1]), "ab-set-image-demo-round-2")
	var sets: Array = result.get("sets", [])
	assert_eq(sets.size(), 2)
	var second_set := Dictionary(sets[1])
	assert_eq(second_set.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(second_set.get("set_name", ""), "Image Demo Round Two")
	assert_eq(second_set.get("kind", ""), "image")
	assert_eq(second_set.get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(second_set.get("asset_path", ""), String(package_copy.get("asset_path", "")))

func test_workout_yaml_bridge_builds_request_for_specific_set() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _make_multi_set_workout_package()
	var result := bridge.build_request_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-image-demo-round-2", {
		"request_id": "yaml-bridge-second-set",
		"metadata": {"source": "test"},
	})
	assert_true(result.get("ok", false))
	var request: Dictionary = result.get("request", {})
	assert_eq(request.get("request_id", ""), "yaml-bridge-second-set")
	assert_eq(request.get("kind", ""), "image")
	assert_eq(request.get("asset_path", ""), String(package_copy.get("asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("source", ""), "workout_yaml")
	assert_eq(metadata.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(metadata.get("set_name", ""), "Image Demo Round Two")
	assert_eq(int(metadata.get("set_index", -1)), 1)
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo-2")

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

func test_load_environment_from_absolute_workout_yaml_path_succeeds() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var package_copy := _copy_workout_fixture_package_to_temp()
	manager.load_environment_from_workout_yaml(String(package_copy.get("workout_path", "")), {
		"request_id": "workout-image-load-absolute",
		"display_mode": "contain",
		"metadata": {"source": "absolute-test"},
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "workout-image-load-absolute")
	assert_eq(result.get("kind", ""), "image")
	assert_eq(result.get("asset_path", ""), String(package_copy.get("asset_path", "")))
	assert_eq(Dictionary(result.get("metadata", {})).get("package_dir", ""), String(package_copy.get("package_dir", "")))
	assert_eq(Dictionary(result.get("metadata", {})).get("workout_path", ""), String(package_copy.get("workout_path", "")))
	assert_eq(Dictionary(result.get("metadata", {})).get("source", ""), "workout_yaml")
	await get_tree().process_frame

func test_load_environment_from_workout_set_uses_selected_set_metadata() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var package_copy := _make_multi_set_workout_package()
	manager.load_environment_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-image-demo-round-2", {
		"request_id": "workout-image-load-second-set",
		"display_mode": "contain",
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "workout-image-load-second-set")
	assert_eq(result.get("kind", ""), "image")
	assert_eq(result.get("asset_path", ""), String(package_copy.get("asset_path", "")))
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(metadata.get("set_name", ""), "Image Demo Round Two")
	assert_eq(int(metadata.get("set_index", -1)), 1)
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo-2")
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
	var gltf_details: Dictionary = result.get("gltf_details", {})
	var vendor_details: Dictionary = Dictionary(gltf_details.get("vendor", {}))
	assert_false(vendor_details.has("document"))
	assert_false(vendor_details.has("state"))
	assert_false(vendor_details.has("scene"))
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

func test_external_video_path_round_trips_through_core_result_contract() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var temp_video_path := _copy_fixture_to_temp("res://assets/videos/calm_blue_sea_1.ogv", "ogv")
	manager.load_environment({
		"request_id": "external-video-load",
		"kind": "video",
		"asset_path": temp_video_path,
		"metadata": {"source": "test"},
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "external-video-load")
	assert_eq(result.get("asset_path", ""), temp_video_path)
	assert_eq(result.get("kind", ""), "video")
	var result_model = CORE_RESULT_SCRIPT.new(result)
	assert_eq(result_model.request_id, "external-video-load")
	assert_eq(result_model.metadata.get("source", ""), "test")
	assert_eq(Dictionary(result.get("media_info", {})).get("path", ""), temp_video_path)
	assert_eq(Dictionary(result.get("media_info", {})).get("locality", ""), "absolute_path")
	assert_eq(Dictionary(result.get("playback_state", {})).get("state", ""), "playing")
	await get_tree().process_frame

func test_glb_outside_project_loads_through_shared_gltf_stack() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var temp_glb_path := _copy_fixture_to_temp("res://assets/models/alien-planet.glb", "glb")
	manager.load_environment({
		"request_id": "external-glb-load",
		"kind": "glb",
		"asset_path": temp_glb_path,
		"metadata": {"source": "test"},
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("kind", ""), "glb")
	assert_eq(result.get("asset_path", ""), temp_glb_path)
	assert_eq(result.get("absolute_path", ""), temp_glb_path)
	assert_eq(result.get("resource_path", ""), "")
	assert_false(result.get("config_applied", true))
	assert_eq((setup["world_root"] as Node3D).get_child_count(), 1)
	var scene_root := (setup["world_root"] as Node3D).get_child(0)
	assert_not_null(scene_root)
	var gltf_details: Dictionary = result.get("gltf_details", {})
	assert_true(gltf_details.has("vendor"))
	assert_false(Dictionary(gltf_details.get("vendor", {})).has("document"))
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
