extends Node

signal environment_load_started(request: Dictionary)
signal environment_load_progress(progress: Dictionary)
signal environment_load_succeeded(result: Dictionary)
signal environment_load_failed(error: Dictionary)
signal environment_cleared()

const VERSION: String = "0.1.0"
const WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT = preload("AeroWorkoutYamlEnvironmentBridge.gd")

const KIND_IMAGE := "image"
const KIND_VIDEO := "video"
const KIND_GLB := "glb"
const KIND_SPLAT := "splat"
const DISPLAY_MODE_COVER := "cover"
const DISPLAY_MODE_CONTAIN := "contain"
const ERROR_FILE_MISSING := "file_missing"
const ERROR_UNSUPPORTED_FORMAT := "unsupported_format"
const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_INVALID_CONFIG := "invalid_config"
const ERROR_LOADER_FAILED := "loader_failed"
const STATUS_RESOLVING := "resolving"
const STATUS_LOADING := "loading"
const STATUS_DECODING := "decoding"
const STATUS_INSTANTIATING := "instantiating"
const STATUS_APPLYING_CONFIG := "applying_config"
const STATUS_READY := "ready"
const OFFICIAL_FORMATS := {
	KIND_IMAGE: ".png",
	KIND_VIDEO: ".ogv",
	KIND_GLB: ".glb",
	KIND_SPLAT: ".compressed.ply",
}
const TEXTURE_RECT_STRETCH_COVER := 6
const TEXTURE_RECT_STRETCH_CONTAIN := 5

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

func _ready() -> void:
	_bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	_ensure_roots()

func load_environment(request: Dictionary) -> void:
	if not is_active:
		_emit_failure(_request_stub(request), ERROR_LOADER_FAILED, "AeroToolManager is inactive.", true)
		return
	var normalized_result := _normalize_request(request)
	if not normalized_result.get("ok", false):
		var failed_request: Dictionary = normalized_result.get("request", _request_stub(request))
		_emit_failure(
			failed_request,
			String(normalized_result.get("error_code", ERROR_INVALID_REQUEST)),
			String(normalized_result.get("message", "Invalid environment request.")),
			bool(normalized_result.get("recoverable", true))
		)
		return
	var normalized_request: Dictionary = normalized_result.get("request", {})
	_active_request = normalized_request.duplicate(true)
	environment_load_started.emit(_active_request.duplicate(true))
	_emit_progress(_active_request, STATUS_RESOLVING, 0.0, "Resolving environment request...")
	call_deferred("_perform_load", _active_request.duplicate(true))

func load_environment_from_workout_yaml(yaml_path: String, context: Dictionary = {}) -> void:
	if _bridge == null:
		_bridge = WORKOUT_YAML_ENVIRONMENT_BRIDGE_SCRIPT.new()
	var bridge_result: Dictionary = _bridge.build_request_from_workout_yaml(yaml_path, context)
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

func clear_environment() -> void:
	_clear_current_environment(true)

func get_current_environment() -> Dictionary:
	return _current_environment.duplicate(true)

func supports_kind(kind: String) -> bool:
	return OFFICIAL_FORMATS.has(kind.strip_edges().to_lower())

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
	var resource_path := _to_resource_path(String(request.get("asset_path", "")))
	if resource_path.is_empty():
		_emit_failure(request, ERROR_FILE_MISSING, "Video environment must live inside the Godot project so it can be imported: %s" % request.get("asset_path", ""), true)
		return
	var video_stream: Variant = load(resource_path)
	if video_stream == null:
		_emit_failure(request, ERROR_LOADER_FAILED, "Video stream could not be loaded: %s" % resource_path, true)
		return
	_emit_progress(request, STATUS_INSTANTIATING, 0.55, "Instantiating video environment...")
	var player := VideoStreamPlayer.new()
	player.name = "EnvironmentVideo"
	player.stream = video_stream
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.offset_left = 0.0
	player.offset_top = 0.0
	player.offset_right = 0.0
	player.offset_bottom = 0.0
	_canvas_root.add_child(player)
	player.play()
	_finalize_success(request, player, {
		"format": OFFICIAL_FORMATS[KIND_VIDEO],
		"config_path": "",
		"config_applied": false,
	})

func _load_glb(request: Dictionary) -> void:
	_emit_progress(request, STATUS_LOADING, 0.1, "Loading GLB environment...")
	var resource_path := _to_resource_path(String(request.get("asset_path", "")))
	if resource_path.is_empty():
		_emit_failure(request, ERROR_FILE_MISSING, "GLB environment must live inside the Godot project so it can be imported: %s" % request.get("asset_path", ""), true)
		return
	var packed_scene: Variant = load(resource_path)
	if packed_scene == null or not (packed_scene is PackedScene):
		_emit_failure(request, ERROR_LOADER_FAILED, "GLB scene could not be loaded: %s" % resource_path, true)
		return
	_emit_progress(request, STATUS_INSTANTIATING, 0.55, "Instantiating GLB environment...")
	var scene_instance: Node = (packed_scene as PackedScene).instantiate()
	if scene_instance == null:
		_emit_failure(request, ERROR_LOADER_FAILED, "GLB scene could not be instantiated: %s" % resource_path, true)
		return
	_world_root.add_child(scene_instance)
	var config_result: Dictionary = _apply_config_if_present(request, scene_instance)
	if not config_result.get("ok", false):
		scene_instance.queue_free()
		_emit_failure(request, ERROR_INVALID_CONFIG, String(config_result.get("message", "GLB config could not be applied.")), true)
		return
	_finalize_success(request, scene_instance, {
		"format": OFFICIAL_FORMATS[KIND_GLB],
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
	if _current_display_node != null and is_instance_valid(_current_display_node):
		if _current_display_node is VideoStreamPlayer:
			(_current_display_node as VideoStreamPlayer).stop()
		_current_display_node.queue_free()
	_current_display_node = null
	_current_environment = {}
	_active_request = {}
	if emit_signal:
		environment_cleared.emit()

func _normalize_request(request: Dictionary) -> Dictionary:
	var kind := String(request.get("kind", "")).strip_edges().to_lower()
	var asset_path := String(request.get("asset_path", "")).strip_edges()
	var normalized_request := {
		"request_id": String(request.get("request_id", "")).strip_edges(),
		"kind": kind,
		"asset_path": asset_path,
		"config_path": String(request.get("config_path", "")).strip_edges(),
		"display_mode": _normalize_display_mode(String(request.get("display_mode", DISPLAY_MODE_COVER)).strip_edges()),
		"context": request.get("context", {}),
		"metadata": Dictionary(request.get("metadata", {})) if request.get("metadata", {}) is Dictionary else {},
	}
	if kind.is_empty():
		return _invalid_request(normalized_request, "Environment request is missing kind.")
	if not supports_kind(kind):
		return {
			"ok": false,
			"request": normalized_request,
			"error_code": ERROR_UNSUPPORTED_FORMAT,
			"message": "Environment kind '%s' is not supported." % kind,
			"recoverable": true,
		}
	if asset_path.is_empty():
		return _invalid_request(normalized_request, "Environment request is missing asset_path.")
	var format := _detect_format(asset_path)
	if format != String(OFFICIAL_FORMATS.get(kind, "")):
		return {
			"ok": false,
			"request": normalized_request,
			"error_code": ERROR_UNSUPPORTED_FORMAT,
			"message": "Environment kind '%s' requires %s assets, got %s." % [kind, OFFICIAL_FORMATS.get(kind, ""), format],
			"recoverable": true,
		}
	if normalized_request["config_path"].is_empty() and (kind == KIND_GLB or kind == KIND_SPLAT):
		var preferred_config_path := _preferred_config_path(asset_path)
		if FileAccess.file_exists(_to_absolute_path(preferred_config_path)):
			normalized_request["config_path"] = preferred_config_path
	return {
		"ok": true,
		"request": normalized_request,
	}

func _invalid_request(request: Dictionary, message: String) -> Dictionary:
	return {
		"ok": false,
		"request": request,
		"error_code": ERROR_INVALID_REQUEST,
		"message": message,
		"recoverable": true,
	}

func _normalize_display_mode(display_mode: String) -> String:
	return DISPLAY_MODE_CONTAIN if display_mode.to_lower() == DISPLAY_MODE_CONTAIN else DISPLAY_MODE_COVER

func _preferred_config_path(asset_path: String) -> String:
	var normalized := asset_path.strip_edges()
	if normalized.to_lower().ends_with(OFFICIAL_FORMATS[KIND_SPLAT]):
		return normalized.substr(0, normalized.length() - OFFICIAL_FORMATS[KIND_SPLAT].length()) + ".json"
	if normalized.to_lower().ends_with(OFFICIAL_FORMATS[KIND_GLB]):
		return normalized.substr(0, normalized.length() - OFFICIAL_FORMATS[KIND_GLB].length()) + ".json"
	return normalized + ".json"

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
	var apply_result: Dictionary = _apply_environment_transform(config, target)
	if not apply_result.get("ok", false):
		return apply_result
	return {
		"ok": true,
		"config_applied": true,
		"config_path": config_path,
		"config": config,
	}

func _apply_environment_transform(config: Dictionary, target: Node) -> Dictionary:
	if not (target is Node3D):
		return {
			"ok": false,
			"message": "Environment config can only be applied to Node3D content.",
		}
	var node_3d := target as Node3D
	node_3d.position = _variant_to_vector3(config.get("position", Vector3.ZERO), Vector3.ZERO)
	node_3d.rotation_degrees = _variant_to_vector3(config.get("rotation_degrees", Vector3.ZERO), Vector3.ZERO)
	node_3d.scale = _variant_to_vector3(config.get("scale", Vector3.ONE), Vector3.ONE)
	return {"ok": true}

func _variant_to_vector3(value: Variant, default_value: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array:
		var array_value: Array = value
		if array_value.size() >= 3:
			return Vector3(float(array_value[0]), float(array_value[1]), float(array_value[2]))
	if value is Dictionary:
		var dict_value: Dictionary = value
		return Vector3(
			float(dict_value.get("x", default_value.x)),
			float(dict_value.get("y", default_value.y)),
			float(dict_value.get("z", default_value.z))
		)
	return default_value

func _finalize_success(request: Dictionary, node: Node, extra: Dictionary = {}) -> void:
	_current_display_node = node
	_emit_progress(request, STATUS_READY, 1.0, "Environment ready.")
	var result := {
		"ok": true,
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"config_path": String(extra.get("config_path", String(request.get("config_path", "")))),
		"format": String(extra.get("format", _detect_format(String(request.get("asset_path", ""))))),
		"config_applied": bool(extra.get("config_applied", false)),
		"metadata": Dictionary(request.get("metadata", {})).duplicate(true),
	}
	for key in extra.keys():
		result[key] = extra[key]
	_current_environment = result.duplicate(true)
	_active_request = {}
	environment_load_succeeded.emit(result)

func _emit_failure(request: Dictionary, error_code: String, message: String, recoverable: bool) -> void:
	var error := {
		"ok": false,
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"error_code": error_code,
		"message": message,
		"recoverable": recoverable,
	}
	_active_request = {}
	environment_load_failed.emit(error)

func _emit_progress(request: Dictionary, status: String, progress: float, message: String) -> void:
	var payload := {
		"request_id": String(request.get("request_id", "")),
		"kind": String(request.get("kind", "")),
		"asset_path": String(request.get("asset_path", "")),
		"status": status,
		"progress": clampf(progress, 0.0, 1.0),
		"message": message,
	}
	environment_load_progress.emit(payload)

func _request_stub(request: Dictionary) -> Dictionary:
	return {
		"request_id": String(request.get("request_id", "")).strip_edges(),
		"kind": String(request.get("kind", "")).strip_edges().to_lower(),
		"asset_path": String(request.get("asset_path", "")).strip_edges(),
	}

func _detect_format(asset_path: String) -> String:
	var lower := asset_path.strip_edges().to_lower()
	for format in OFFICIAL_FORMATS.values():
		if lower.ends_with(String(format)):
			return String(format)
	var extension := lower.get_extension()
	return ".%s" % extension if not extension.is_empty() else ""

func _to_absolute_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized.simplify_path() if normalized.is_absolute_path() else ProjectSettings.globalize_path(normalized)

func _to_resource_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return normalized
	if not normalized.is_absolute_path():
		return ProjectSettings.localize_path(ProjectSettings.globalize_path(normalized))
	var project_root := ProjectSettings.globalize_path("res://")
	if normalized.begins_with(project_root):
		return ProjectSettings.localize_path(normalized)
	return ""
