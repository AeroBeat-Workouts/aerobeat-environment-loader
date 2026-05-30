extends Node

const FIXTURE_WORKOUT_YAML_PATH := "res://fixtures/workout_yaml_valid_all_kinds/workout.yaml"

@onready var environment_loader = $AeroEnvironmentLoader
@onready var world_root: Node3D = $WorldRoot
@onready var status_log: RichTextLabel = %StatusLog
@onready var workout_yaml_edit: LineEdit = %WorkoutYamlEdit
@onready var current_workout_label: Label = %CurrentWorkoutLabel
@onready var current_path_label: Label = %CurrentPathLabel
@onready var unload_workout_button: Button = %UnloadWorkoutButton
@onready var set_buttons_container: VBoxContainer = %SetButtonsContainer
@onready var config_path_edit: LineEdit = %ConfigPathEdit
@onready var file_dialog: FileDialog = %WorkoutFileDialog

var _loaded_workout: Dictionary = {}

func _ready() -> void:
	environment_loader.canvas_root_path = NodePath("../CanvasLayer/CanvasRoot")
	environment_loader.world_root_path = NodePath("../WorldRoot")
	environment_loader.environment_load_started.connect(_on_environment_load_started)
	environment_loader.environment_load_progress.connect(_on_environment_load_progress)
	environment_loader.environment_load_succeeded.connect(_on_environment_load_succeeded)
	environment_loader.environment_load_failed.connect(_on_environment_load_failed)
	environment_loader.environment_cleared.connect(_on_environment_cleared)
	workout_yaml_edit.text = _default_workout_entry_path()
	workout_yaml_edit.placeholder_text = "Absolute package dir or workout.yaml path"
	_refresh_workout_ui()

func _default_workout_entry_path() -> String:
	var fixture_absolute := ProjectSettings.globalize_path(FIXTURE_WORKOUT_YAML_PATH)
	if FileAccess.file_exists(fixture_absolute):
		return fixture_absolute
	return FIXTURE_WORKOUT_YAML_PATH

func _selected_display_mode() -> String:
	return "cover"

func _current_workout_path() -> String:
	return String(_loaded_workout.get("workout_path", workout_yaml_edit.text)).strip_edges()

func _refresh_workout_ui() -> void:
	var workout_loaded := not _loaded_workout.is_empty()
	unload_workout_button.disabled = not workout_loaded
	current_workout_label.text = "Current workout: %s" % (_current_workout_path() if workout_loaded else "(none)")
	if not workout_loaded:
		_clear_set_buttons()

func _clear_set_buttons() -> void:
	for child in set_buttons_container.get_children():
		set_buttons_container.remove_child(child)
		child.queue_free()

func _resolve_picker_seed(path_text: String) -> Dictionary:
	var trimmed := path_text.strip_edges()
	if trimmed.is_empty():
		return {}
	if DirAccess.dir_exists_absolute(trimmed):
		return {
			"dir": trimmed,
			"file": "workout.yaml",
		}
	if FileAccess.file_exists(trimmed):
		return {
			"dir": trimmed.get_base_dir(),
			"file": trimmed.get_file(),
		}
	return {
		"dir": trimmed.get_base_dir(),
		"file": trimmed.get_file(),
	}

func _open_workout_picker() -> void:
	var picker_seed := _resolve_picker_seed(workout_yaml_edit.text)
	var initial_dir := String(picker_seed.get("dir", "")).strip_edges()
	var initial_file := String(picker_seed.get("file", "")).strip_edges()
	if not initial_dir.is_empty():
		file_dialog.current_dir = initial_dir
	if not initial_file.is_empty():
		file_dialog.current_file = initial_file
	file_dialog.popup_centered_ratio(0.8)

func _load_workout_package(path_text: String) -> void:
	var workout_path := path_text.strip_edges()
	var inspection: Dictionary = environment_loader.inspect_workout_package(workout_path)
	if not inspection.get("ok", false):
		_append_status("WORKOUT ERROR %s: %s" % [inspection.get("error_code", "invalid_workout_yaml"), inspection.get("message", "Workout package could not be loaded.")])
		return
	if not _loaded_workout.is_empty():
		environment_loader.clear_environment()
	_clear_set_buttons()
	_loaded_workout = inspection.duplicate(true)
	workout_yaml_edit.text = String(_loaded_workout.get("workout_path", workout_path))
	_rebuild_set_buttons()
	_refresh_workout_ui()
	_append_status("WORKOUT LOADED %s (%d sets)" % [String(_loaded_workout.get("workout_name", _loaded_workout.get("workout_id", "(unnamed workout)"))), Array(_loaded_workout.get("sets", [])).size()])

func _rebuild_set_buttons() -> void:
	_clear_set_buttons()
	var sets: Array = Array(_loaded_workout.get("sets", []))
	for index in range(sets.size()):
		if not (sets[index] is Dictionary):
			continue
		var set_descriptor := Dictionary(sets[index]).duplicate(true)
		var button := Button.new()
		button.text = "Load Set %d" % (index + 1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s • %s • %s" % [
			String(set_descriptor.get("set_name", set_descriptor.get("set_id", ""))),
			String(set_descriptor.get("kind", "")),
			String(set_descriptor.get("asset_path", "")),
		]
		button.pressed.connect(func() -> void:
			_load_workout_set(set_descriptor)
		)
		set_buttons_container.add_child(button)

func _load_workout_set(set_descriptor: Dictionary) -> void:
	var set_id := String(set_descriptor.get("set_id", "")).strip_edges()
	if set_id.is_empty():
		_append_status("SET ERROR invalid_workout_yaml: Resolved set is missing set_id.")
		return
	environment_loader.load_environment_from_workout_set(_current_workout_path(), set_id, {
		"request_id": "workout-set-%s" % set_id,
		"display_mode": _selected_display_mode(),
		"config_path": config_path_edit.text,
		"context": {
			"source": "environment_testbed",
			"mode": "workout_set",
		},
		"metadata": {
			"sample": true,
			"requested_set_index": int(set_descriptor.get("set_index", -1)),
		},
	})

func _unload_workout() -> void:
	_loaded_workout = {}
	_clear_set_buttons()
	config_path_edit.text = ""
	environment_loader.clear_environment()
	_refresh_workout_ui()
	_append_status("WORKOUT UNLOADED")

func _on_pick_workout_pressed() -> void:
	_open_workout_picker()

func _on_load_workout_pressed() -> void:
	_load_workout_package(workout_yaml_edit.text)

func _on_unload_workout_pressed() -> void:
	_unload_workout()

func _on_save_current_config_pressed() -> void:
	var current: Dictionary = environment_loader.get_current_environment()
	var target := world_root.get_child(0) if world_root.get_child_count() > 0 else null
	if current.is_empty() or target == null or not (target is Node3D):
		_append_status("No 3D environment is active; nothing to save.")
		return
	var config_path := String(current.get("config_path", "")).strip_edges()
	if config_path.is_empty():
		config_path = String(config_path_edit.text).strip_edges()
	if config_path.is_empty():
		_append_status("No config path is available for the active environment.")
		return
	var node := target as Node3D
	var config := {
		"position": [node.position.x, node.position.y, node.position.z],
		"rotation_degrees": [node.rotation_degrees.x, node.rotation_degrees.y, node.rotation_degrees.z],
		"scale": [node.scale.x, node.scale.y, node.scale.z],
	}
	var absolute_path := ProjectSettings.globalize_path(config_path)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_append_status("Could not open config for writing: %s" % config_path)
		return
	file.store_string(JSON.stringify(config, "  "))
	file.close()
	config_path_edit.text = config_path
	_append_status("Saved environment config to %s" % config_path)

func _on_apply_current_config_pressed() -> void:
	var current: Dictionary = environment_loader.get_current_environment()
	if current.is_empty():
		_append_status("No active environment to reload.")
		return
	var request := {
		"request_id": "%s-reload" % String(current.get("kind", "environment")),
		"kind": current.get("kind", ""),
		"asset_path": current.get("asset_path", ""),
		"config_path": config_path_edit.text,
		"display_mode": _selected_display_mode(),
		"context": {
			"source": "environment_testbed",
			"mode": "reload_with_config",
		},
		"metadata": current.get("metadata", {}),
	}
	environment_loader.load_environment(request)

func _on_workout_file_dialog_file_selected(path: String) -> void:
	workout_yaml_edit.text = path
	_load_workout_package(path)

func _on_environment_load_started(request: Dictionary) -> void:
	current_path_label.text = "Current asset: %s" % String(request.get("asset_path", ""))
	_append_status("START %s %s" % [request.get("kind", ""), request.get("asset_path", "")])

func _on_environment_load_progress(progress: Dictionary) -> void:
	_append_status("PROGRESS %s %.2f %s" % [progress.get("status", ""), float(progress.get("progress", 0.0)), progress.get("message", "")])

func _on_environment_load_succeeded(result: Dictionary) -> void:
	current_path_label.text = "Current asset: %s" % String(result.get("asset_path", ""))
	config_path_edit.text = String(result.get("config_path", config_path_edit.text))
	var metadata := Dictionary(result.get("metadata", {}))
	var routing := Dictionary(metadata.get("device_routing", {}))
	var route_suffix := ""
	if not routing.is_empty():
		var device := Dictionary(routing.get("device", {}))
		route_suffix = " • role=%s reason=%s gpu=%s" % [
			String(metadata.get("selected_environment_role", routing.get("selected_role", ""))),
			String(routing.get("reason", "")),
			String(device.get("gpu_name", "unknown")),
		]
	_append_status("SUCCESS %s %s%s" % [result.get("kind", ""), result.get("asset_path", ""), route_suffix])

func _on_environment_load_failed(error: Dictionary) -> void:
	_append_status("ERROR %s: %s" % [error.get("error_code", "loader_failed"), error.get("message", "")])

func _on_environment_cleared() -> void:
	current_path_label.text = "Current asset: (none)"
	config_path_edit.text = ""
	_append_status("CLEARED")

func _append_status(line: String) -> void:
	status_log.append_text("%s\n" % line)
