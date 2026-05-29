extends GutTest

const AERO_ENVIRONMENT_LOADER_SCRIPT = preload("res://../src/AeroEnvironmentLoader.gd")
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("res://../src/AeroWorkoutYamlEnvironmentBridge.gd")
const AERO_GLTF_TOOL_SCRIPT = preload("res://addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd")
const CORE_CONSTANTS_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/globals/aero_environment_constants.gd")
const CORE_REQUEST_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_request.gd")
const CORE_RESULT_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_result.gd")
const CORE_PROGRESS_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_progress.gd")
const CORE_ERROR_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_error.gd")
const CORE_REQUEST_VALIDATOR_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/validators/environment_request_validator.gd")
const FIXTURE_PACKAGE_DIR_PATH := "res://fixtures/workout_yaml_valid_all_kinds"
const FIXTURE_WORKOUT_YAML_PATH := "%s/workout.yaml" % FIXTURE_PACKAGE_DIR_PATH

func _supported_device_simulation() -> Dictionary:
	return {
		"profile": "desktop_rtx_4090",
		"device_name": "Desktop RTX 4090",
		"model_name": "Desktop RTX 4090",
		"platform": "linux",
		"os_name": "Linux",
		"os_version": "6.0",
		"cpu_name": "AMD Ryzen 9",
		"gpu_name": "NVIDIA GeForce RTX 4090",
		"gpu_vendor": "NVIDIA",
		"renderer_name": "forward_plus",
		"rendering_method": "forward_plus",
		"display_server": "x11",
		"screen_size": {"width": 2560, "height": 1440},
		"memory_gb": 32.0,
		"tags": ["desktop", "nvidia"],
	}

func _blacklisted_intel_iris_xe_simulation() -> Dictionary:
	return {
		"profile": "surface_pro_8",
		"device_name": "Surface Pro 8",
		"model_name": "Surface Pro 8",
		"platform": "windows",
		"os_name": "Windows",
		"os_version": "11",
		"cpu_name": "11th Gen Intel(R) Core(TM) i7-1185G7",
		"gpu_name": "Intel Iris Xe Graphics",
		"gpu_vendor": "Intel",
		"renderer_name": "forward_plus",
		"rendering_method": "forward_plus",
		"display_server": "windows",
		"screen_size": {"width": 2880, "height": 1920},
		"memory_gb": 16.0,
		"tags": ["surface", "intel"],
	}

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

func _write_tiny_splat_fixture(target_absolute: String) -> void:
	var write_handle := FileAccess.open(target_absolute, FileAccess.WRITE)
	assert_not_null(write_handle)
	write_handle.store_string("\n".join([
		"ply",
		"format binary_little_endian 1.0",
		"comment Tiny placeholder proving fixture for workout-package splat seam",
		"element vertex 0",
		"property float x",
		"property float y",
		"property float z",
		"end_header",
	]) + "\n")
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
	var source_dir := ProjectSettings.globalize_path(FIXTURE_PACKAGE_DIR_PATH)
	_copy_fixture_directory_recursive(source_dir, package_dir)
	var media_dir := package_dir.path_join("media/environments")
	assert_eq(DirAccess.make_dir_recursive_absolute(media_dir), OK)
	var image_asset_path := media_dir.path_join("demo.png")
	var video_asset_path := media_dir.path_join("calm_blue_sea_1.ogv")
	var glb_asset_path := media_dir.path_join("alien-planet.glb")
	var glb_config_path := media_dir.path_join("alien-planet.json")
	var splat_asset_path := media_dir.path_join("countryside-farm.compressed.ply")
	var splat_config_path := media_dir.path_join("countryside-farm.json")
	_copy_fixture_file(ProjectSettings.globalize_path("res://assets/images/perfect-hue-may-14-2026.png"), image_asset_path)
	_copy_fixture_file(ProjectSettings.globalize_path("res://assets/videos/calm_blue_sea_1.ogv"), video_asset_path)
	_copy_fixture_file(ProjectSettings.globalize_path("res://assets/models/alien-planet.glb"), glb_asset_path)
	_copy_fixture_file(ProjectSettings.globalize_path("res://assets/models/alien-planet.json"), glb_config_path)
	_write_tiny_splat_fixture(splat_asset_path)
	_copy_fixture_file(ProjectSettings.globalize_path("res://assets/splats/CountrySide farm.json"), splat_config_path)

	var environment_image_file := FileAccess.open(package_dir.path_join("environments/ab-environment-image-demo.yaml"), FileAccess.WRITE)
	assert_not_null(environment_image_file)
	environment_image_file.store_string("\n".join([
		"schemaId: aerobeat.environment.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"environmentId: ab-environment-image-demo",
		"environmentName: Image Demo Environment",
		"type: image_background",
		"resourcePath: media/environments/demo.png",
	]))
	environment_image_file.close()

	var environment_video_file := FileAccess.open(package_dir.path_join("environments/ab-environment-video-demo.yaml"), FileAccess.WRITE)
	assert_not_null(environment_video_file)
	environment_video_file.store_string("\n".join([
		"schemaId: aerobeat.environment.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"environmentId: ab-environment-video-demo",
		"environmentName: Video Demo Environment",
		"type: video_background",
		"resourcePath: media/environments/calm_blue_sea_1.ogv",
	]))
	environment_video_file.close()

	var environment_glb_file := FileAccess.open(package_dir.path_join("environments/ab-environment-glb-demo.yaml"), FileAccess.WRITE)
	assert_not_null(environment_glb_file)
	environment_glb_file.store_string("\n".join([
		"schemaId: aerobeat.environment.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"environmentId: ab-environment-glb-demo",
		"environmentName: GLB Demo Environment",
		"type: glb_environment",
		"resourcePath: media/environments/alien-planet.glb",
	]))
	environment_glb_file.close()

	var environment_splat_file := FileAccess.open(package_dir.path_join("environments/ab-environment-splat-demo.yaml"), FileAccess.WRITE)
	assert_not_null(environment_splat_file)
	environment_splat_file.store_string("\n".join([
		"schemaId: aerobeat.environment.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"environmentId: ab-environment-splat-demo",
		"environmentName: Gaussian Splat Demo Environment",
		"type: splat",
		"resourcePath: media/environments/countryside-farm.compressed.ply",
	]))
	environment_splat_file.close()

	return {
		"package_dir": package_dir,
		"workout_path": package_dir.path_join("workout.yaml"),
		"image_asset_path": image_asset_path,
		"video_asset_path": video_asset_path,
		"glb_asset_path": glb_asset_path,
		"glb_config_path": glb_config_path,
		"splat_asset_path": splat_asset_path,
		"splat_config_path": splat_config_path,
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
		"preferredEnvironmentId: ab-environment-image-demo-2",
		"fallbackEnvironmentId: ab-environment-image-demo",
	]))
	second_set_file.close()

	var workout_file := FileAccess.open(String(package_copy.get("workout_path", "")), FileAccess.WRITE)
	assert_not_null(workout_file)
	workout_file.store_string("\n".join([
		"schemaId: aerobeat.workout-package.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"workoutId: ab-workout-environment-stack-demo",
		"workoutName: Environment Stack Demo Workout",
		"packageVersion: 1.0.0",
		"setOrder:",
		"  - ab-set-image-demo-round",
		"  - ab-set-video-demo-round",
		"  - ab-set-glb-demo-round",
		"  - ab-set-splat-demo-round",
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
	assert_true(source_text.contains('preload("res://addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd")'))
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
	var result := bridge.build_request_from_workout_yaml(ProjectSettings.globalize_path(FIXTURE_WORKOUT_YAML_PATH), {
		"request_id": "yaml-bridge-test",
		"display_mode": "contain",
		"metadata": {"from_test": true},
	})
	assert_true(result.get("ok", false))
	var request: Dictionary = result.get("request", {})
	assert_eq(request.get("request_id", ""), "yaml-bridge-test")
	assert_eq(request.get("kind", ""), "image")
	assert_true(String(request.get("asset_path", "")).ends_with("perfect-hue-may-14-2026.png"))
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
	assert_eq(request.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("package_dir", ""), String(package_copy.get("package_dir", "")))
	assert_eq(metadata.get("workout_path", ""), workout_path)
	assert_eq(metadata.get("source", ""), "workout_yaml")
	assert_eq(metadata.get("environment_record_path", ""), String(package_copy.get("package_dir", "")).path_join("environments/ab-environment-image-demo.yaml"))
	assert_eq(metadata.get("preferred_environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("fallback_environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "preferred")
	var candidates := Dictionary(metadata.get("environment_candidates", {}))
	assert_eq(Dictionary(candidates.get("preferred", {})).get("environment_id", ""), "ab-environment-image-demo")
	assert_eq(Dictionary(candidates.get("fallback", {})).get("environment_id", ""), "ab-environment-image-demo")

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
	assert_eq(request.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("package_dir", ""), package_dir)
	assert_eq(metadata.get("workout_path", ""), package_dir.path_join("workout.yaml"))

func test_inspect_workout_package_returns_manifest_for_each_set() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _make_multi_set_workout_package()
	var result := bridge.inspect_workout_package(String(package_copy.get("workout_path", "")))
	assert_true(result.get("ok", false))
	assert_eq(result.get("workout_id", ""), "ab-workout-environment-stack-demo")
	assert_eq(result.get("workout_name", ""), "Environment Stack Demo Workout")
	var set_order: Array = result.get("set_order", [])
	assert_eq(set_order.size(), 5)
	assert_eq(String(set_order[1]), "ab-set-video-demo-round")
	var sets: Array = result.get("sets", [])
	assert_eq(sets.size(), 5)
	var second_set := Dictionary(sets[4])
	assert_eq(second_set.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(second_set.get("set_name", ""), "Image Demo Round Two")
	assert_eq(second_set.get("kind", ""), "image")
	assert_eq(second_set.get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(second_set.get("preferred_environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(second_set.get("fallback_environment_id", ""), "ab-environment-image-demo")
	assert_eq(Dictionary(second_set.get("preferred_environment", {})).get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(Dictionary(second_set.get("fallback_environment", {})).get("environment_id", ""), "ab-environment-image-demo")
	assert_eq(second_set.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))

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
	assert_eq(request.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))
	var metadata := Dictionary(request.get("metadata", {}))
	assert_eq(metadata.get("source", ""), "workout_yaml")
	assert_eq(metadata.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(metadata.get("set_name", ""), "Image Demo Round Two")
	assert_eq(int(metadata.get("set_index", -1)), 4)
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(metadata.get("preferred_environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(metadata.get("fallback_environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "preferred")
	var candidates := Dictionary(metadata.get("environment_candidates", {}))
	assert_eq(Dictionary(candidates.get("preferred", {})).get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(Dictionary(candidates.get("fallback", {})).get("environment_id", ""), "ab-environment-image-demo")

func test_workout_yaml_bridge_rejects_missing_preferred_environment_id() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _copy_workout_fixture_package_to_temp()
	var set_path := String(package_copy.get("package_dir", "")).path_join("sets/ab-set-image-demo-round.yaml")
	var set_file := FileAccess.open(set_path, FileAccess.WRITE)
	assert_not_null(set_file)
	set_file.store_string("\n".join([
		"schemaId: aerobeat.set.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"setId: ab-set-image-demo-round",
		"setName: Image Demo Round",
		"fallbackEnvironmentId: ab-environment-image-demo",
	]) + "\n")
	set_file.close()
	var result := bridge.inspect_workout_package(String(package_copy.get("workout_path", "")))
	assert_false(result.get("ok", true))
	assert_eq(result.get("error_code", ""), "invalid_workout_yaml")
	assert_eq(result.get("message", ""), "Resolved set is missing preferredEnvironmentId.")

func test_workout_yaml_bridge_rejects_missing_fallback_environment_id() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _copy_workout_fixture_package_to_temp()
	var set_path := String(package_copy.get("package_dir", "")).path_join("sets/ab-set-image-demo-round.yaml")
	var set_file := FileAccess.open(set_path, FileAccess.WRITE)
	assert_not_null(set_file)
	set_file.store_string("\n".join([
		"schemaId: aerobeat.set.v1",
		"schemaVersion: 1",
		"recordVersion: 1",
		"setId: ab-set-image-demo-round",
		"setName: Image Demo Round",
		"preferredEnvironmentId: ab-environment-image-demo",
	]) + "\n")
	set_file.close()
	var result := bridge.inspect_workout_package(String(package_copy.get("workout_path", "")))
	assert_false(result.get("ok", true))
	assert_eq(result.get("error_code", ""), "invalid_workout_yaml")
	assert_eq(result.get("message", ""), "Resolved set is missing fallbackEnvironmentId.")

func test_load_environment_from_workout_yaml_emits_progress_and_success() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var progress_events: Array[Dictionary] = []
	manager.environment_load_progress.connect(func(progress: Dictionary) -> void:
		progress_events.append(progress)
	)
	manager.load_environment_from_workout_yaml(FIXTURE_WORKOUT_YAML_PATH, {
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
	assert_eq(result.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))
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
		"device_detection_simulation": _supported_device_simulation(),
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "workout-image-load-second-set")
	assert_eq(result.get("kind", ""), "image")
	assert_eq(result.get("asset_path", ""), String(package_copy.get("image_asset_path", "")))
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("set_id", ""), "ab-set-image-demo-round-2")
	assert_eq(metadata.get("set_name", ""), "Image Demo Round Two")
	assert_eq(int(metadata.get("set_index", -1)), 4)
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(metadata.get("preferred_environment_id", ""), "ab-environment-image-demo-2")
	assert_eq(metadata.get("fallback_environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "preferred")
	var routing := Dictionary(metadata.get("device_routing", {}))
	assert_eq(routing.get("reason", ""), "supported_device")
	assert_eq(Dictionary(routing.get("device", {})).get("gpu_name", ""), "NVIDIA GeForce RTX 4090")
	await get_tree().process_frame

func test_blacklisted_intel_iris_xe_routes_workout_set_to_fallback_environment() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var package_copy := _make_multi_set_workout_package()
	manager.load_environment_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-image-demo-round-2", {
		"request_id": "workout-image-load-blacklisted-intel",
		"display_mode": "contain",
		"device_detection_simulation": _blacklisted_intel_iris_xe_simulation(),
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "fallback")
	var routing := Dictionary(metadata.get("device_routing", {}))
	assert_eq(routing.get("reason", ""), "blacklisted_gpu")
	assert_eq(routing.get("matched_gpu_rule", ""), "Intel Iris Xe")
	assert_eq(Dictionary(routing.get("device", {})).get("gpu_name", ""), "Intel Iris Xe Graphics")
	await get_tree().process_frame

func test_missing_loader_policy_routes_workout_set_to_fallback() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	manager.unsupported_device_policy_path = "res://fixtures/missing_unsupported_device_policy.yaml"
	var package_copy := _make_multi_set_workout_package()
	manager.load_environment_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-image-demo-round-2", {
		"request_id": "workout-image-load-missing-policy",
		"display_mode": "contain",
		"device_detection_simulation": _supported_device_simulation(),
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "fallback")
	var routing := Dictionary(metadata.get("device_routing", {}))
	assert_eq(routing.get("reason", ""), "policy_missing")
	assert_false(routing.get("policy_loaded", true))
	await get_tree().process_frame

func test_invalid_loader_policy_routes_workout_set_to_fallback() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var invalid_policy_path := "/tmp/aerobeat-environment-loader-invalid-policy-%s.yaml" % str(Time.get_ticks_usec())
	var invalid_policy_file := FileAccess.open(invalid_policy_path, FileAccess.WRITE)
	assert_not_null(invalid_policy_file)
	invalid_policy_file.store_string("schemaId: aerobeat.environment_loader.unsupported_devices.v1\ngpuBlacklist: Intel Iris Xe\n")
	invalid_policy_file.close()
	manager.unsupported_device_policy_path = invalid_policy_path
	var package_copy := _make_multi_set_workout_package()
	manager.load_environment_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-image-demo-round-2", {
		"request_id": "workout-image-load-invalid-policy",
		"display_mode": "contain",
		"device_detection_simulation": _supported_device_simulation(),
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("environment_id", ""), "ab-environment-image-demo")
	assert_eq(metadata.get("selected_environment_role", ""), "fallback")
	var routing := Dictionary(metadata.get("device_routing", {}))
	assert_eq(routing.get("reason", ""), "policy_invalid")
	assert_false(routing.get("policy_loaded", true))
	await get_tree().process_frame

func test_load_environment_from_absolute_workout_set_splat_succeeds() -> void:
	var setup := _make_manager()
	var manager = setup["manager"]
	var package_copy := _copy_workout_fixture_package_to_temp()
	manager.load_environment_from_workout_set(String(package_copy.get("workout_path", "")), "ab-set-splat-demo-round", {
		"request_id": "workout-splat-load-absolute",
		"display_mode": "contain",
	})
	var result: Dictionary = await manager.environment_load_succeeded
	assert_true(result.get("ok", false))
	assert_eq(result.get("request_id", ""), "workout-splat-load-absolute")
	assert_eq(result.get("kind", ""), "splat")
	assert_eq(result.get("format", ""), ".compressed.ply")
	assert_eq(result.get("asset_path", ""), String(package_copy.get("splat_asset_path", "")))
	assert_eq(result.get("config_path", ""), String(package_copy.get("splat_config_path", "")))
	assert_true(result.get("config_applied", false))
	assert_eq((setup["world_root"] as Node3D).get_child_count(), 1)
	var node := (setup["world_root"] as Node3D).get_child(0) as Node3D
	assert_not_null(node)
	assert_eq(node.name, "EnvironmentSplat")
	assert_almost_eq(node.position.y, -1.0, 0.001)
	assert_true(int(result.get("point_count", 0)) >= 1)
	var metadata := Dictionary(result.get("metadata", {}))
	assert_eq(metadata.get("set_id", ""), "ab-set-splat-demo-round")
	await get_tree().process_frame

func test_absolute_workout_package_can_switch_media_type_per_set() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var package_copy := _copy_workout_fixture_package_to_temp()
	var workout_path := String(package_copy.get("workout_path", ""))
	var expected := {
		"ab-set-image-demo-round": {
			"kind": "image",
			"asset_path": String(package_copy.get("image_asset_path", "")),
		},
		"ab-set-video-demo-round": {
			"kind": "video",
			"asset_path": String(package_copy.get("video_asset_path", "")),
		},
		"ab-set-glb-demo-round": {
			"kind": "glb",
			"asset_path": String(package_copy.get("glb_asset_path", "")),
		},
		"ab-set-splat-demo-round": {
			"kind": "splat",
			"asset_path": String(package_copy.get("splat_asset_path", "")),
		},
	}
	var inspection := bridge.inspect_workout_package(workout_path)
	assert_true(inspection.get("ok", false))
	var set_order: Array = inspection.get("set_order", [])
	assert_eq(set_order, [
		"ab-set-image-demo-round",
		"ab-set-video-demo-round",
		"ab-set-glb-demo-round",
		"ab-set-splat-demo-round",
	])
	for set_id in set_order:
		var result := bridge.build_request_from_workout_set(workout_path, String(set_id), {
			"request_id": "switch-%s" % String(set_id),
			"display_mode": "contain",
		})
		assert_true(result.get("ok", false))
		var request: Dictionary = result.get("request", {})
		var metadata := Dictionary(request.get("metadata", {}))
		var expected_case := Dictionary(expected.get(String(set_id), {}))
		assert_eq(request.get("kind", ""), expected_case.get("kind", ""))
		assert_eq(request.get("asset_path", ""), expected_case.get("asset_path", ""))
		assert_eq(request.get("display_mode", ""), "contain")
		assert_eq(metadata.get("set_id", ""), String(set_id))
		assert_eq(metadata.get("workout_path", ""), workout_path)

func test_committed_workout_fixture_covers_all_supported_environment_kinds() -> void:
	var bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var result := bridge.inspect_workout_package(ProjectSettings.globalize_path(FIXTURE_WORKOUT_YAML_PATH))
	assert_true(result.get("ok", false))
	assert_eq(result.get("workout_id", ""), "ab-workout-environment-stack-demo")
	assert_eq(result.get("workout_name", ""), "Environment Stack Demo Workout")
	var set_order: Array = result.get("set_order", [])
	assert_eq(set_order, [
		"ab-set-image-demo-round",
		"ab-set-video-demo-round",
		"ab-set-glb-demo-round",
		"ab-set-splat-demo-round",
	])
	var sets: Array = result.get("sets", [])
	assert_eq(sets.size(), 4)
	assert_eq(Dictionary(sets[0]).get("kind", ""), "image")
	assert_eq(Dictionary(sets[1]).get("kind", ""), "video")
	assert_eq(Dictionary(sets[2]).get("kind", ""), "glb")
	assert_eq(Dictionary(sets[3]).get("kind", ""), "splat")
	assert_true(String(Dictionary(sets[0]).get("asset_path", "")).ends_with("assets/images/perfect-hue-may-14-2026.png"))
	assert_true(String(Dictionary(sets[1]).get("asset_path", "")).ends_with("assets/videos/calm_blue_sea_1.ogv"))
	assert_true(String(Dictionary(sets[2]).get("asset_path", "")).ends_with("assets/models/alien-planet.glb"))
	assert_true(String(Dictionary(sets[3]).get("asset_path", "")).ends_with("assets/splats/CountrySide farm.compressed.ply"))

func test_external_workout_package_copy_materializes_local_media_references() -> void:
	var package_copy := _copy_workout_fixture_package_to_temp()
	assert_true(FileAccess.file_exists(String(package_copy.get("image_asset_path", ""))))
	assert_true(FileAccess.file_exists(String(package_copy.get("video_asset_path", ""))))
	assert_true(FileAccess.file_exists(String(package_copy.get("glb_asset_path", ""))))
	assert_true(FileAccess.file_exists(String(package_copy.get("glb_config_path", ""))))
	assert_true(FileAccess.file_exists(String(package_copy.get("splat_asset_path", ""))))
	assert_true(FileAccess.file_exists(String(package_copy.get("splat_config_path", ""))))
	var video_environment_text := FileAccess.get_file_as_string(String(package_copy.get("package_dir", "")).path_join("environments/ab-environment-video-demo.yaml"))
	var glb_environment_text := FileAccess.get_file_as_string(String(package_copy.get("package_dir", "")).path_join("environments/ab-environment-glb-demo.yaml"))
	var splat_environment_text := FileAccess.get_file_as_string(String(package_copy.get("package_dir", "")).path_join("environments/ab-environment-splat-demo.yaml"))
	assert_true(video_environment_text.contains("resourcePath: media/environments/calm_blue_sea_1.ogv"))
	assert_true(glb_environment_text.contains("resourcePath: media/environments/alien-planet.glb"))
	assert_true(splat_environment_text.contains("resourcePath: media/environments/countryside-farm.compressed.ply"))

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
