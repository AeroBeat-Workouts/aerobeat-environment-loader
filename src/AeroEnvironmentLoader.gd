extends Node

signal environment_load_started(request: Dictionary)
signal environment_load_progress(progress: Dictionary)
signal environment_load_succeeded(result: Dictionary)
signal environment_load_failed(error: Dictionary)
signal environment_cleared()

class _AeroEnvironmentLoaderGLTFBackendAdapter:
	extends RefCounted

	const RUNTIME_LOADER_SCRIPT_PATHS := [
		"res://addons/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_runtime_loader.gd",
		"res://addons/aerobeat-vendor-godot-gltf/loaders/aero_godot_gltf_runtime_loader.gd",
	]

	var _runtime_loader: Variant = null

	func load_scene_bundle(request: Dictionary) -> Dictionary:
		var asset_path := String(request.get("asset_path", "")).strip_edges()
		var format := String(request.get("format", request.get("container", ""))).strip_edges().to_lower()
		var runtime_loader: Variant = _resolve_runtime_loader()
		if runtime_loader == null or not runtime_loader.has_method("load_source"):
			return {
				"ok": false,
				"error_code": "vendor_runtime_unavailable",
				"message": "Vendor GLTF runtime loader is unavailable.",
				"recoverable": true,
				"details": {
					"asset_path": asset_path,
					"format": format,
				},
			}

		var source := {
			"path": asset_path,
			"format": format,
		}
		var instantiate := bool(request.get("instantiate", true))
		var runtime_result: Dictionary = runtime_loader.load_scene(source) if instantiate else runtime_loader.load_source(source)
		if not bool(runtime_result.get("success", false)):
			return {
				"ok": false,
				"error_code": String(runtime_result.get("code", "vendor_load_failed")),
				"message": String(runtime_result.get("message", "Vendor GLTF runtime loader failed.")),
				"recoverable": true,
				"details": _dictionary_or_empty_static(runtime_result.get("detail", {})),
			}

		var detail := _dictionary_or_empty_static(runtime_result.get("detail", {}))
		var normalized_path := _normalize_asset_path(asset_path)
		var resource_path := _resource_path_for(asset_path)
		var scene_root: Variant = detail.get("scene", null)
		var packed_scene: PackedScene = null
		if instantiate and scene_root != null:
			packed_scene = PackedScene.new()
			var pack_error := packed_scene.pack(scene_root)
			if pack_error != OK:
				packed_scene = null

		return {
			"ok": true,
			"asset_path": asset_path,
			"absolute_path": normalized_path,
			"resource_path": resource_path,
			"format": format,
			"container": String(request.get("container", format)),
			"scene_root": scene_root,
			"packed_scene": packed_scene,
			"warnings": [],
			"details": {
				"vendor": detail,
				"instantiate": instantiate,
			},
		}

	func _resolve_runtime_loader() -> Variant:
		if _runtime_loader != null and _runtime_loader.has_method("load_source"):
			return _runtime_loader

		for script_path in RUNTIME_LOADER_SCRIPT_PATHS:
			if not ResourceLoader.exists(script_path, "Script"):
				continue
			var script_resource: Variant = load(script_path)
			if script_resource == null or not script_resource.has_method("new"):
				continue
			_runtime_loader = script_resource.new()
			if _runtime_loader != null and _runtime_loader.has_method("load_source"):
				return _runtime_loader

		return null

	func _normalize_asset_path(asset_path: String) -> String:
		if asset_path.is_empty():
			return ""
		return ProjectSettings.globalize_path(asset_path) if asset_path.begins_with("res://") or asset_path.begins_with("user://") else asset_path.simplify_path()

	func _resource_path_for(asset_path: String) -> String:
		if asset_path.begins_with("res://"):
			return asset_path
		return ""

	static func _dictionary_or_empty_static(value: Variant) -> Dictionary:
		if value is Dictionary:
			return Dictionary(value).duplicate(true)
		return {}

const VERSION: String = "0.2.0"
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("AeroWorkoutYamlEnvironmentBridge.gd")
const AERO_VIDEO_PLAYER_MANAGER_SCRIPT = preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerManager.gd")
const AERO_GLTF_TOOL_SCRIPT = preload("res://addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd")
const AERO_ENVIRONMENT_CONSTANTS = preload("res://addons/aerobeat-environment-core/src/contracts/globals/aero_environment_constants.gd")
const AERO_ENVIRONMENT_RESULT_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_result.gd")
const AERO_ENVIRONMENT_ERROR_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_error.gd")
const AERO_ENVIRONMENT_PROGRESS_SCRIPT = preload("res://addons/aerobeat-environment-core/src/contracts/data_types/environment_progress.gd")
const AERO_ENVIRONMENT_REQUEST_VALIDATOR = preload("res://addons/aerobeat-environment-core/src/contracts/validators/environment_request_validator.gd")
const AERO_ENVIRONMENT_CONFIG_HELPER = preload("res://addons/aerobeat-environment-core/src/contracts/validators/environment_config_helper.gd")

const KIND_IMAGE := AERO_ENVIRONMENT_CONSTANTS.KIND_IMAGE
const KIND_VIDEO := AERO_ENVIRONMENT_CONSTANTS.KIND_VIDEO
const KIND_GLB := AERO_ENVIRONMENT_CONSTANTS.KIND_GLB
const KIND_SPLAT := AERO_ENVIRONMENT_CONSTANTS.KIND_SPLAT
const DISPLAY_MODE_COVER := AERO_ENVIRONMENT_CONSTANTS.DISPLAY_MODE_COVER
const DISPLAY_MODE_CONTAIN := AERO_ENVIRONMENT_CONSTANTS.DISPLAY_MODE_CONTAIN
const ERROR_FILE_MISSING := AERO_ENVIRONMENT_CONSTANTS.ERROR_FILE_MISSING
const ERROR_UNSUPPORTED_FORMAT := AERO_ENVIRONMENT_CONSTANTS.ERROR_UNSUPPORTED_FORMAT
const ERROR_INVALID_REQUEST := AERO_ENVIRONMENT_CONSTANTS.ERROR_INVALID_REQUEST
const ERROR_INVALID_CONFIG := AERO_ENVIRONMENT_CONSTANTS.ERROR_INVALID_CONFIG
const ERROR_LOADER_FAILED := AERO_ENVIRONMENT_CONSTANTS.ERROR_LOADER_FAILED
const STATUS_RESOLVING := AERO_ENVIRONMENT_CONSTANTS.STATUS_RESOLVING
const STATUS_LOADING := AERO_ENVIRONMENT_CONSTANTS.STATUS_LOADING
const STATUS_DECODING := AERO_ENVIRONMENT_CONSTANTS.STATUS_DECODING
const STATUS_INSTANTIATING := AERO_ENVIRONMENT_CONSTANTS.STATUS_INSTANTIATING
const STATUS_APPLYING_CONFIG := AERO_ENVIRONMENT_CONSTANTS.STATUS_APPLYING_CONFIG
const STATUS_READY := AERO_ENVIRONMENT_CONSTANTS.STATUS_READY
const OFFICIAL_FORMATS := AERO_ENVIRONMENT_CONSTANTS.OFFICIAL_FORMATS
const TEXTURE_RECT_STRETCH_COVER := 6
const TEXTURE_RECT_STRETCH_CONTAIN := 5
const VIDEO_FAILURE_SUBSYSTEM := "video"
const VIDEO_ERROR_STAGE_ATTACH := "attach_surface"
const VIDEO_ERROR_STAGE_LOAD := "load"
const VIDEO_ERROR_STAGE_PLAY := "play"
const VIDEO_ERROR_STAGE_UNLOAD := "unload"
const GLTF_FAILURE_SUBSYSTEM := "gltf"
const GLTF_ERROR_STAGE_LOAD := "load"
const GLTF_ERROR_STAGE_ATTACH := "attach_scene_root"
const GLTF_ERROR_STAGE_CONFIG := "apply_config"

@export var is_active: bool = true
@export var canvas_root_path: NodePath
@export var world_root_path: NodePath
@export var create_default_roots: bool = true

var _canvas_root: Control
var _world_root: Node3D
var _current_environment: Dictionary = {}
var _current_display_node: Node
var _active_request: Dictionary = {}
var _bridge: RefCounted
var _video_player_manager: Node
var _gltf_tool: RefCounted

func _ready() -> void:
	_bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	_ensure_roots()

func _ensure_bridge() -> RefCounted:
	if _bridge == null:
		_bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	return _bridge

func _load_environment_from_workout_bridge_result(yaml_path: String, context: Dictionary, bridge_result: Dictionary) -> void:
	if not bridge_result.get("ok", false):
		var request := {
			"request_id": String(context.get("request_id", "")).strip_edges(),
			"kind": "",
			"asset_path": yaml_path.strip_edges(),
			"config_path": String(context.get("config_path", "")).strip_edges(),
			"display_mode": String(context.get("display_mode", DISPLAY_MODE_COVER)).strip_edges(),
			"context": context.duplicate(true),
			"metadata": Dictionary(context.get("metadata", {})) if context.get("metadata", {}) is Dictionary else {},
		}
		_emit_failure(
			request,
			String(bridge_result.get("error_code", ERROR_INVALID_REQUEST)),
			String(bridge_result.get("message", "Workout YAML bridge failed.")),
			bool(bridge_result.get("recoverable", true))
		)
		return
	load_environment(Dictionary(bridge_result.get("request", {})))

func load_environment(request: Dictionary) -> void:
	if not is_active:
		_emit_failure(_request_stub(request), ERROR_LOADER_FAILED, "AeroEnvironmentLoader is inactive.", true)
		return
	var normalized_result := _normalize_request(request)
	if not normalized_result.get("ok", false):
		var failed_request := _dictionary_from_request_variant(normalized_result.get("request_dict", normalized_result.get("request", _request_stub(request))))
		_emit_failure(
			failed_request,
			String(normalized_result.get("error_code", ERROR_INVALID_REQUEST)),
			String(normalized_result.get("message", "Invalid environment request.")),
			bool(normalized_result.get("recoverable", true))
		)
		return
	var normalized_request: Dictionary = _dictionary_from_request_variant(normalized_result.get("request_dict", normalized_result.get("request", {})))
	_active_request = normalized_request.duplicate(true)
	environment_load_started.emit(_active_request.duplicate(true))
	_emit_progress(_active_request, STATUS_RESOLVING, 0.0, "Resolving environment request...")
	call_deferred("_perform_load", _active_request.duplicate(true))

func inspect_workout_package(yaml_path: String) -> Dictionary:
	if _bridge == null:
		_bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	return _bridge.inspect_workout_package(yaml_path)

func load_environment_from_workout_yaml(yaml_path: String, context: Dictionary = {}) -> void:
	_load_environment_from_workout_bridge_result(yaml_path, context, _ensure_bridge().build_request_from_workout_yaml(yaml_path, context))

func load_environment_from_workout_set(yaml_path: String, set_reference: Variant, context: Dictionary = {}) -> void:
	_load_environment_from_workout_bridge_result(yaml_path, context, _ensure_bridge().build_request_from_workout_set(yaml_path, set_reference, context))

func clear_environment() -> void:
	_clear_current_environment(true)

func get_current_environment() -> Dictionary:
	return _current_environment.duplicate(true)

func supports_kind(kind: String) -> bool:
	return AERO_ENVIRONMENT_CONSTANTS.supports_kind(kind)

func _perform_load(request: Dictionary) -> void:
	_clear_current_environment(false)
	match String(request.get("kind", "")):
		KIND_IMAGE:
			_load_image(request)
		KIND_VIDEO:
			_load_video(request)
		KIND_GLB:
			_load_glb(request)
		KIND_SPLAT:
			await _load_splat(request)
		_:
			_emit_failure(request, ERROR_UNSUPPORTED_FORMAT, "Unsupported environment kind: %s" % request.get("kind", ""), true)

func _load_image(request: Dictionary) -> void:
	_emit_progress(request, STATUS_LOADING, 0.1, "Loading image environment...")
	var absolute_path := _to_absolute_path(String(request.get("asset_path", "")))
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		_emit_failure(request, ERROR_FILE_MISSING, "Image file does not exist: %s" % request.get("asset_path", ""), true)
		return
	var image := Image.new()
	var image_error := image.load(absolute_path)
	if image_error != OK:
		_emit_failure(request, ERROR_LOADER_FAILED, "Image failed to load: %s" % absolute_path, true)
		return
	_emit_progress(request, STATUS_DECODING, 0.45, "Decoding image environment...")
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		_emit_failure(request, ERROR_LOADER_FAILED, "Image texture could not be created for %s." % absolute_path, true)
		return
	var texture_rect := TextureRect.new()
	texture_rect.name = "EnvironmentImage"
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TEXTURE_RECT_STRETCH_COVER if String(request.get("display_mode", DISPLAY_MODE_COVER)) == DISPLAY_MODE_COVER else TEXTURE_RECT_STRETCH_CONTAIN
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 0.0
	texture_rect.offset_top = 0.0
	texture_rect.offset_right = 0.0
	texture_rect.offset_bottom = 0.0
	_canvas_root.add_child(texture_rect)
	_finalize_success(request, texture_rect, {
		"format": OFFICIAL_FORMATS[KIND_IMAGE],
		"config_path": "",
		"config_applied": false,
	})

func _load_video(request: Dictionary) -> void:
	_emit_progress(request, STATUS_LOADING, 0.1, "Loading video environment...")
	var asset_resolution := _resolve_asset_path(String(request.get("asset_path", "")))
	var requested_asset_path := String(asset_resolution.get("requested_path", ""))
	var absolute_path := String(asset_resolution.get("absolute_path", ""))
	var resource_path := String(asset_resolution.get("resource_path", ""))
	var load_path := _preferred_video_load_path(asset_resolution)
	if load_path.is_empty():
		_emit_failure(
			request,
			ERROR_INVALID_REQUEST,
			"Video request could not be resolved to a loadable local path: %s" % requested_asset_path,
			true,
			_build_asset_resolution_details(asset_resolution)
		)
		return
	_emit_progress(request, STATUS_INSTANTIATING, 0.55, "Instantiating video environment...")
	var surface := _build_video_surface()
	_canvas_root.add_child(surface)

	var video_manager := _ensure_video_player_manager()
	video_manager.attach_surface(surface)
	var attach_error := _get_video_manager_error(video_manager)
	if not attach_error.is_empty():
		_emit_video_failure(request, load_path, VIDEO_ERROR_STAGE_ATTACH, video_manager, "Video output surface could not be attached.", ERROR_LOADER_FAILED, bool(attach_error.get("recoverable", true)), asset_resolution)
		_unload_video_player_manager(video_manager, request, VIDEO_ERROR_STAGE_UNLOAD, load_path)
		surface.queue_free()
		return

	video_manager.load({
		"path": load_path,
		"kind": "file",
		"autoplay": false,
		"metadata": {
			"environment_request_id": String(request.get("request_id", "")),
			"environment_kind": KIND_VIDEO,
			"requested_asset_path": requested_asset_path,
			"absolute_asset_path": absolute_path,
			"resource_asset_path": resource_path,
		},
	})
	var load_error := _get_video_manager_error(video_manager)
	if not load_error.is_empty():
		_emit_video_failure(request, load_path, VIDEO_ERROR_STAGE_LOAD, video_manager, "Video stream could not be loaded.", ERROR_LOADER_FAILED, bool(load_error.get("recoverable", true)), asset_resolution)
		_unload_video_player_manager(video_manager, request, VIDEO_ERROR_STAGE_UNLOAD, load_path)
		surface.queue_free()
		return

	video_manager.play()
	var play_error := _get_video_manager_error(video_manager)
	if not play_error.is_empty():
		_emit_video_failure(request, load_path, VIDEO_ERROR_STAGE_PLAY, video_manager, "Video playback could not be started.", ERROR_LOADER_FAILED, bool(play_error.get("recoverable", true)), asset_resolution)
		_unload_video_player_manager(video_manager, request, VIDEO_ERROR_STAGE_UNLOAD, load_path)
		surface.queue_free()
		return

	var video_state: Dictionary = _sanitize_video_state(video_manager.get_state())
	var media_info: Dictionary = _sanitize_video_media_info(video_manager.get_media_info())
	_finalize_success(request, surface, {
		"format": OFFICIAL_FORMATS[KIND_VIDEO],
		"config_path": "",
		"config_applied": false,
		"playback_state": video_state,
		"media_info": media_info,
	})

func _load_glb(request: Dictionary) -> void:
	_emit_progress(request, STATUS_LOADING, 0.1, "Loading GLB environment...")
	var gltf_tool := _ensure_gltf_tool()
	var gltf_result: Dictionary = gltf_tool.load_scene({
		"asset_path": String(request.get("asset_path", "")),
		"container": "glb",
		"format": "glb",
		"instantiate": true,
		"metadata": {
			"environment_request_id": String(request.get("request_id", "")),
			"environment_kind": KIND_GLB,
			"requested_asset_path": String(request.get("asset_path", "")),
		},
	})
	if not gltf_result.get("ok", false):
		_emit_gltf_failure(request, gltf_result)
		return
	_emit_progress(request, STATUS_INSTANTIATING, 0.55, "Attaching GLB environment...")
	var scene_root: Variant = gltf_result.get("scene_root", null)
	if scene_root == null or not (scene_root is Node):
		_emit_failure(
			request,
			ERROR_LOADER_FAILED,
			"GLTF scene bundle did not include a valid scene_root.",
			false,
			_build_gltf_failure_details(request, {
				"error_code": "missing_scene_root",
				"message": "GLTF scene bundle did not include a valid scene_root.",
				"recoverable": false,
				"details": _sanitize_gltf_details(_dictionary_or_empty(gltf_result.get("details", {}))),
			}, GLTF_ERROR_STAGE_ATTACH)
		)
		return
	var scene_instance := scene_root as Node
	_world_root.add_child(scene_instance)
	var config_result: Dictionary = _apply_config_if_present(request, scene_instance)
	if not config_result.get("ok", false):
		scene_instance.queue_free()
		_emit_failure(
			request,
			ERROR_INVALID_CONFIG,
			String(config_result.get("message", "GLB config could not be applied.")),
			true,
			_build_gltf_failure_details(request, {
				"error_code": ERROR_INVALID_CONFIG,
				"message": String(config_result.get("message", "GLB config could not be applied.")),
				"recoverable": true,
				"details": _sanitize_gltf_details(_dictionary_or_empty(gltf_result.get("details", {}))),
			}, GLTF_ERROR_STAGE_CONFIG)
		)
		return
	_finalize_success(request, scene_instance, {
		"format": OFFICIAL_FORMATS[KIND_GLB],
		"container": String(gltf_result.get("container", "glb")),
		"resource_path": String(gltf_result.get("resource_path", "")),
		"absolute_path": String(gltf_result.get("absolute_path", "")),
		"warnings": _array_or_empty(gltf_result.get("warnings", [])),
		"gltf_details": _sanitize_gltf_details(_dictionary_or_empty(gltf_result.get("details", {}))),
		"config_path": String(config_result.get("config_path", "")),
		"config_applied": bool(config_result.get("config_applied", false)),
		"config": config_result.get("config", {}),
	})

func _load_splat(request: Dictionary) -> void:
	_emit_progress(request, STATUS_LOADING, 0.1, "Reading gaussian splat environment...")
	var absolute_path := _to_absolute_path(String(request.get("asset_path", "")))
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		_emit_failure(request, ERROR_FILE_MISSING, "Splat file does not exist: %s" % request.get("asset_path", ""), true)
		return
	await get_tree().process_frame
	_emit_progress(request, STATUS_DECODING, 0.45, "Decoding gaussian splat contract...")
	var file_size := FileAccess.get_file_as_bytes(absolute_path).size()
	await get_tree().process_frame
	_emit_progress(request, STATUS_INSTANTIATING, 0.75, "Instantiating gaussian splat placeholder...")
	var placeholder := Node3D.new()
	placeholder.name = "EnvironmentSplat"
	placeholder.set_meta("asset_path", absolute_path)
	placeholder.set_meta("point_count_estimate", max(file_size / 60, 1))
	var marker := Marker3D.new()
	marker.name = "Anchor"
	placeholder.add_child(marker)
	_world_root.add_child(placeholder)
	var config_result: Dictionary = _apply_config_if_present(request, placeholder)
	if not config_result.get("ok", false):
		placeholder.queue_free()
		_emit_failure(request, ERROR_INVALID_CONFIG, String(config_result.get("message", "Splat config could not be applied.")), true)
		return
	_finalize_success(request, placeholder, {
		"format": OFFICIAL_FORMATS[KIND_SPLAT],
		"config_path": String(config_result.get("config_path", "")),
		"config_applied": bool(config_result.get("config_applied", false)),
		"config": config_result.get("config", {}),
		"point_count": int(placeholder.get_meta("point_count_estimate", 0)),
	})

func _ensure_roots() -> void:
	if canvas_root_path != NodePath(""):
		_canvas_root = get_node_or_null(canvas_root_path) as Control
	if _canvas_root == null and create_default_roots:
		_canvas_root = Control.new()
		_canvas_root.name = "EnvironmentCanvasRoot"
		_canvas_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_canvas_root.offset_left = 0.0
		_canvas_root.offset_top = 0.0
		_canvas_root.offset_right = 0.0
		_canvas_root.offset_bottom = 0.0
		add_child(_canvas_root)
	if world_root_path != NodePath(""):
		_world_root = get_node_or_null(world_root_path) as Node3D
	if _world_root == null and create_default_roots:
		_world_root = Node3D.new()
		_world_root.name = "EnvironmentWorldRoot"
		add_child(_world_root)

func _clear_current_environment(emit_signal: bool) -> void:
	_teardown_video_player_manager()
	if _current_display_node != null and is_instance_valid(_current_display_node):
		_current_display_node.queue_free()
	_current_display_node = null
	_current_environment = {}
	_active_request = {}
	if emit_signal:
		environment_cleared.emit()

func _ensure_video_player_manager() -> Node:
	if _video_player_manager != null and is_instance_valid(_video_player_manager):
		if _video_player_manager.get_parent() == null:
			add_child(_video_player_manager)
		return _video_player_manager
	_video_player_manager = _build_video_player_manager()
	_video_player_manager.name = "EnvironmentVideoPlayerManager"
	add_child(_video_player_manager)
	return _video_player_manager

func _teardown_video_player_manager() -> void:
	_unload_video_player_manager(_video_player_manager)

func _ensure_gltf_tool() -> RefCounted:
	if _gltf_tool != null:
		return _gltf_tool
	_gltf_tool = AERO_GLTF_TOOL_SCRIPT.new()
	if _gltf_tool != null and _gltf_tool.has_method("set_runtime_backend"):
		_gltf_tool.set_runtime_backend(_AeroEnvironmentLoaderGLTFBackendAdapter.new())
	return _gltf_tool

func _unload_video_player_manager(video_manager: Node, request: Dictionary = {}, stage: String = VIDEO_ERROR_STAGE_UNLOAD, resource_path: String = "") -> void:
	if video_manager == null or not is_instance_valid(video_manager):
		return
	if video_manager.has_method("unload"):
		video_manager.unload()
		return
	var unload_error := _get_video_manager_error(video_manager)
	var state: Dictionary = _get_video_manager_state(video_manager)
	if bool(state.get("surface_attached", false)):
		if bool(state.get("media_loaded", not Dictionary(state.get("source", {})).is_empty())) and video_manager.has_method("stop"):
			video_manager.stop()
		if video_manager.has_method("detach_surface"):
			video_manager.detach_surface()
	if not request.is_empty() and unload_error.is_empty() and not _get_video_manager_error(video_manager).is_empty():
		_emit_video_failure(request, resource_path, stage, video_manager, "Video teardown could not be completed.", ERROR_LOADER_FAILED, true)

func _get_video_manager_error(video_manager: Node) -> Dictionary:
	if video_manager == null or not is_instance_valid(video_manager) or not video_manager.has_method("get_last_error"):
		return {}
	var last_error: Variant = video_manager.get_last_error()
	if last_error is Dictionary:
		return Dictionary(last_error).duplicate(true)
	return {}

func _get_video_manager_state(video_manager: Node) -> Dictionary:
	if video_manager == null or not is_instance_valid(video_manager) or not video_manager.has_method("get_state"):
		return {}
	var state: Variant = video_manager.get_state()
	if state is Dictionary:
		return Dictionary(state).duplicate(true)
	return {}

func _get_video_manager_media_info(video_manager: Node) -> Dictionary:
	if video_manager == null or not is_instance_valid(video_manager) or not video_manager.has_method("get_media_info"):
		return {}
	var media_info: Variant = video_manager.get_media_info()
	if media_info is Dictionary:
		return Dictionary(media_info).duplicate(true)
	return {}

func _build_video_surface() -> Control:
	var surface := Control.new()
	surface.name = "EnvironmentVideoSurface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	surface.offset_left = 0.0
	surface.offset_top = 0.0
	surface.offset_right = 0.0
	surface.offset_bottom = 0.0
	return surface

func _build_video_player_manager() -> Node:
	var discovered_manager := _discover_video_player_manager()
	if discovered_manager != null:
		return discovered_manager
	return AERO_VIDEO_PLAYER_MANAGER_SCRIPT.new()

func _discover_video_player_manager() -> Node:
	var global_classes: Array = ProjectSettings.get_global_class_list()
	for entry_variant in global_classes:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var global_class_name := String(entry.get("class", ""))
		var script_path := String(entry.get("path", ""))
		var lowered_name := global_class_name.to_lower()
		var lowered_path := script_path.to_lower()
		if not lowered_name.contains("videobackendfactory") and not lowered_path.contains("videobackendfactory.gd"):
			continue
		var factory_script: Variant = load(script_path)
		if factory_script == null:
			continue
		var factory: Variant = factory_script.new()
		if factory == null or not factory.has_method("create_manager"):
			continue
		var manager: Variant = factory.create_manager()
		if manager != null and _is_video_player_manager_candidate(manager):
			return manager
	return null

func _is_video_player_manager_candidate(candidate: Variant) -> bool:
	return candidate != null \
		and candidate is Node \
		and candidate.has_method("attach_surface") \
		and candidate.has_method("load") \
		and candidate.has_method("play") \
		and candidate.has_method("get_state") \
		and candidate.has_method("get_last_error")

func _sanitize_video_state(video_state: Dictionary) -> Dictionary:
	var sanitized := video_state.duplicate(true)
	sanitized.erase("backend")
	sanitized.erase("backend_family")
	sanitized.erase("vendor")
	return sanitized

func _sanitize_video_media_info(media_info: Dictionary) -> Dictionary:
	var sanitized := media_info.duplicate(true)
	sanitized.erase("vendor")
	sanitized.erase("backend_family")
	return sanitized

func _sanitize_video_error(video_error: Dictionary) -> Dictionary:
	var sanitized := video_error.duplicate(true)
	sanitized.erase("vendor")
	sanitized.erase("backend_family")
	return sanitized

func _emit_video_failure(request: Dictionary, resource_path: String, stage: String, video_manager: Node, fallback_message: String, fallback_error_code: String = ERROR_LOADER_FAILED, fallback_recoverable: bool = true, asset_resolution: Dictionary = {}) -> void:
	var video_error := _get_video_manager_error(video_manager)
	var video_state := _get_video_manager_state(video_manager)
	var media_info := _get_video_manager_media_info(video_manager)
	var environment_error_code := _map_video_error_to_environment_code(video_error, resource_path, fallback_error_code)
	var message := String(video_error.get("message", fallback_message))
	var recoverable := bool(video_error.get("recoverable", fallback_recoverable))
	var details := _build_video_failure_details(request, resource_path, stage, video_manager, media_info, video_state, video_error, asset_resolution)
	_emit_failure(request, environment_error_code, message, recoverable, details)

func _map_video_error_to_environment_code(video_error: Dictionary, resource_path: String, fallback_error_code: String) -> String:
	var code := String(video_error.get("code", "")).strip_edges().to_lower()
	match code:
		"backend_stream_load_failed":
			return ERROR_FILE_MISSING if _detect_format(resource_path) == OFFICIAL_FORMATS[KIND_VIDEO] else ERROR_UNSUPPORTED_FORMAT
		"backend_source_kind_unsupported":
			return ERROR_UNSUPPORTED_FORMAT
		"invalid_source", "backend_source_missing_path", "backend_source_not_local", "backend_invalid_rate":
			return ERROR_INVALID_REQUEST
		"invalid_surface", "backend_invalid_surface", "backend_player_unavailable", "backend_not_loaded", "not_ready", "backend_rejected":
			return ERROR_LOADER_FAILED
		_:
			return fallback_error_code

func _build_video_failure_details(request: Dictionary, resource_path: String, stage: String, video_manager: Node, media_info: Dictionary, video_state: Dictionary, video_error: Dictionary, asset_resolution: Dictionary = {}) -> Dictionary:
	var details := {
		"subsystem": VIDEO_FAILURE_SUBSYSTEM,
		"stage": stage,
		"resource_path": resource_path,
		"requested_asset_path": String(request.get("asset_path", "")),
		"state": _sanitize_video_state(video_state),
		"media_info": _sanitize_video_media_info(media_info),
		"video_error": _sanitize_video_error(video_error),
	}
	if not asset_resolution.is_empty():
		details.merge(_build_asset_resolution_details(asset_resolution), true)
	return details

func _emit_gltf_failure(request: Dictionary, gltf_result: Dictionary, stage: String = GLTF_ERROR_STAGE_LOAD) -> void:
	var environment_error_code := _map_gltf_error_to_environment_code(request, gltf_result)
	var message := String(gltf_result.get("message", "GLTF scene bundle could not be loaded."))
	var recoverable := bool(gltf_result.get("recoverable", true))
	var details := _build_gltf_failure_details(request, gltf_result, stage)
	_emit_failure(request, environment_error_code, message, recoverable, details)

func _map_gltf_error_to_environment_code(request: Dictionary, gltf_result: Dictionary) -> String:
	var code := String(gltf_result.get("error_code", "")).strip_edges().to_lower()
	match code:
		ERROR_UNSUPPORTED_FORMAT, "unsupported_format":
			return ERROR_UNSUPPORTED_FORMAT
		ERROR_INVALID_REQUEST, "invalid_request":
			return ERROR_INVALID_REQUEST
		"invalid_source":
			var validation_error: Dictionary = _dictionary_or_empty(_dictionary_or_empty(gltf_result.get("details", {})).get("validation_error", {}))
			var field := String(validation_error.get("field", "")).strip_edges().to_lower()
			if field == "format":
				return ERROR_UNSUPPORTED_FORMAT
			if field == "path":
				return ERROR_INVALID_REQUEST
			return ERROR_INVALID_REQUEST
		"load_failed":
			var asset_resolution := _resolve_asset_path(String(request.get("asset_path", "")))
			if not bool(asset_resolution.get("file_exists", false)):
				return ERROR_FILE_MISSING
			return ERROR_LOADER_FAILED
		"backend_unavailable", "backend_failed", "scene_generation_failed", "invalid_load_result":
			return ERROR_LOADER_FAILED
		_:
			return ERROR_LOADER_FAILED

func _build_gltf_failure_details(request: Dictionary, gltf_result: Dictionary, stage: String = GLTF_ERROR_STAGE_LOAD) -> Dictionary:
	var asset_resolution := _resolve_asset_path(String(request.get("asset_path", "")))
	var details := {
		"subsystem": GLTF_FAILURE_SUBSYSTEM,
		"stage": stage,
		"gltf_error": {
			"code": String(gltf_result.get("error_code", "")),
			"message": String(gltf_result.get("message", "")),
			"recoverable": bool(gltf_result.get("recoverable", true)),
			"details": _sanitize_gltf_details(_dictionary_or_empty(gltf_result.get("details", {}))),
		},
	}
	details.merge(_build_asset_resolution_details(asset_resolution), true)
	return details

func _sanitize_gltf_details(gltf_details: Dictionary) -> Dictionary:
	var sanitized := gltf_details.duplicate(true)
	if sanitized.has("vendor") and sanitized["vendor"] is Dictionary:
		var vendor_details := Dictionary(sanitized["vendor"]).duplicate(true)
		vendor_details.erase("document")
		vendor_details.erase("state")
		vendor_details.erase("scene")
		sanitized["vendor"] = vendor_details
	sanitized.erase("document")
	sanitized.erase("state")
	sanitized.erase("scene")
	return sanitized

func _resolve_asset_path(path: String) -> Dictionary:
	var requested_path := path.strip_edges()
	var absolute_path := _to_absolute_path(requested_path)
	var resource_path := _to_resource_path(requested_path)
	return {
		"requested_path": requested_path,
		"absolute_path": absolute_path,
		"resource_path": resource_path,
		"file_exists": not absolute_path.is_empty() and FileAccess.file_exists(absolute_path),
	}

func _preferred_video_load_path(asset_resolution: Dictionary) -> String:
	var resource_path := String(asset_resolution.get("resource_path", ""))
	if not resource_path.is_empty():
		return resource_path
	return String(asset_resolution.get("absolute_path", ""))

func _build_asset_resolution_details(asset_resolution: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var details := {
		"requested_asset_path": String(asset_resolution.get("requested_path", "")),
		"absolute_asset_path": String(asset_resolution.get("absolute_path", "")),
		"resource_asset_path": String(asset_resolution.get("resource_path", "")),
		"asset_exists": bool(asset_resolution.get("file_exists", false)),
	}
	if not extra.is_empty():
		details.merge(extra, true)
	return details

func _normalize_request(request: Dictionary) -> Dictionary:
	var result: Dictionary = AERO_ENVIRONMENT_REQUEST_VALIDATOR.normalize_request_dict(request)
	var request_dict := _dictionary_from_request_variant(result.get("request_dict", result.get("request", {})))
	if result.get("ok", false):
		return {
			"ok": true,
			"request": request_dict,
			"request_dict": request_dict,
			"request_model": result.get("request", null),
		}
	return {
		"ok": false,
		"request": request_dict,
		"request_dict": request_dict,
		"request_model": result.get("request", null),
		"error": result.get("error", null),
		"error_dict": result.get("error_dict", {}),
		"error_code": result.get("error_code", ERROR_INVALID_REQUEST),
		"message": result.get("message", "Invalid environment request."),
		"recoverable": result.get("recoverable", true),
	}

func _invalid_request(request: Dictionary, message: String) -> Dictionary:
	var normalized_result := AERO_ENVIRONMENT_REQUEST_VALIDATOR.normalize_request_dict(request, false)
	var request_dict := _dictionary_from_request_variant(normalized_result.get("request_dict", normalized_result.get("request", request)))
	return {
		"ok": false,
		"request": request_dict,
		"request_dict": request_dict,
		"error_code": ERROR_INVALID_REQUEST,
		"message": message,
		"recoverable": true,
	}

func _normalize_display_mode(display_mode: String) -> String:
	return AERO_ENVIRONMENT_CONSTANTS.normalize_display_mode(display_mode)

func _preferred_config_path(asset_path: String) -> String:
	return AERO_ENVIRONMENT_CONSTANTS.preferred_config_path(asset_path)

func _apply_config_if_present(request: Dictionary, target: Node) -> Dictionary:
	var config_path := String(request.get("config_path", "")).strip_edges()
	if config_path.is_empty():
		return {
			"ok": true,
			"config_applied": false,
			"config_path": "",
			"config": {},
		}
	var absolute_path := _to_absolute_path(config_path)
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return {
			"ok": true,
			"config_applied": false,
			"config_path": config_path,
			"config": {},
		}
	_emit_progress(request, STATUS_APPLYING_CONFIG, 0.82, "Applying environment config...")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute_path))
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"message": "Environment config is not a JSON object: %s" % config_path,
		}
	var config: Dictionary = parsed
	var apply_result: Dictionary = AERO_ENVIRONMENT_CONFIG_HELPER.apply_config_dict(config, target)
	if not apply_result.get("ok", false):
		return apply_result
	return {
		"ok": true,
		"config_applied": true,
		"config_path": config_path,
		"config": config,
	}

func _apply_environment_transform(config: Dictionary, target: Node) -> Dictionary:
	return AERO_ENVIRONMENT_CONFIG_HELPER.apply_config_dict(config, target)

func _variant_to_vector3(value: Variant, default_value: Vector3) -> Vector3:
	return AERO_ENVIRONMENT_CONFIG_HELPER.variant_to_vector3(value, default_value)

func _finalize_success(request: Dictionary, node: Node, extra: Dictionary = {}) -> void:
	_current_display_node = node
	_emit_progress(request, STATUS_READY, 1.0, "Environment ready.")
	var typed_result = AERO_ENVIRONMENT_RESULT_SCRIPT.new({
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"config_path": String(extra.get("config_path", String(request.get("config_path", "")))),
		"format": String(extra.get("format", _detect_format(String(request.get("asset_path", ""))))),
		"config_applied": bool(extra.get("config_applied", false)),
		"metadata": Dictionary(request.get("metadata", {})).duplicate(true),
		"details": extra.duplicate(true),
	})
	var result: Dictionary = typed_result.to_dict()
	for key in extra.keys():
		result[key] = extra[key]
	_current_environment = result.duplicate(true)
	_active_request = {}
	environment_load_succeeded.emit(result)

func _emit_failure(request: Dictionary, error_code: String, message: String, recoverable: bool, details: Dictionary = {}) -> void:
	var typed_error = AERO_ENVIRONMENT_ERROR_SCRIPT.new({
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"error_code": error_code,
		"message": message,
		"recoverable": recoverable,
		"metadata": Dictionary(request.get("metadata", {})).duplicate(true),
		"details": details.duplicate(true),
	})
	var error: Dictionary = typed_error.to_dict()
	_active_request = {}
	environment_load_failed.emit(error)

func _emit_progress(request: Dictionary, status: String, progress: float, message: String) -> void:
	var typed_progress = AERO_ENVIRONMENT_PROGRESS_SCRIPT.new({
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"status": status,
		"progress": progress,
		"message": message,
		"metadata": Dictionary(request.get("metadata", {})).duplicate(true),
	})
	var payload: Dictionary = typed_progress.to_dict()
	environment_load_progress.emit(payload)

func _request_stub(request: Dictionary) -> Dictionary:
	return {
		"request_id": String(request.get("request_id", "")).strip_edges(),
		"kind": String(request.get("kind", "")).strip_edges().to_lower(),
		"asset_path": String(request.get("asset_path", "")).strip_edges(),
		"config_path": String(request.get("config_path", "")).strip_edges(),
		"display_mode": _normalize_display_mode(String(request.get("display_mode", DISPLAY_MODE_COVER)).strip_edges()),
		"context": request.get("context", {}) if request.get("context", {}) is Dictionary else {},
		"metadata": Dictionary(request.get("metadata", {})) if request.get("metadata", {}) is Dictionary else {},
	}

func _detect_format(asset_path: String) -> String:
	return AERO_ENVIRONMENT_CONSTANTS.detect_format(asset_path)

func _to_absolute_path(path: String) -> String:
	return AERO_ENVIRONMENT_REQUEST_VALIDATOR.to_absolute_path(path)

func _to_resource_path(path: String) -> String:
	return AERO_ENVIRONMENT_REQUEST_VALIDATOR.to_resource_path(path)

func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return Array(value).duplicate(true)
	return []

func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	return {}

func _dictionary_from_request_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	if value != null and value.has_method("to_dict"):
		var dict_value: Variant = value.to_dict()
		if dict_value is Dictionary:
			return Dictionary(dict_value).duplicate(true)
	return {}
