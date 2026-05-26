extends Node

const EXTERNAL_WORKOUT_EXAMPLE_PATH := "/home/derrick/Documents/temp/test-workout/workout.yaml"
const FIXTURE_WORKOUT_YAML_PATH := "res://fixtures/workout_yaml_valid_image/workout.yaml"

@onready var environment_loader = $AeroEnvironmentLoader
@onready var canvas_root: Control = $CanvasLayer/CanvasRoot
@onready var world_root: Node3D = $WorldRoot
@onready var status_log: RichTextLabel = $CanvasLayer/Ui/Panel/Margin/VBox/StatusLog
@onready var asset_path_edit: LineEdit = $CanvasLayer/Ui/Panel/Margin/VBox/AssetPathEdit
@onready var config_path_edit: LineEdit = $CanvasLayer/Ui/Panel/Margin/VBox/ConfigPathEdit
@onready var workout_yaml_edit: LineEdit = $CanvasLayer/Ui/Panel/Margin/VBox/WorkoutYamlEdit
@onready var current_path_label: Label = $CanvasLayer/Ui/Panel/Margin/VBox/CurrentPathLabel
@onready var display_mode_option: OptionButton = $CanvasLayer/Ui/Panel/Margin/VBox/DisplayModeOption

func _ready() -> void:
	display_mode_option.select(0)
	environment_loader.canvas_root_path = NodePath("../CanvasLayer/CanvasRoot")
	environment_loader.world_root_path = NodePath("../WorldRoot")
	environment_loader.environment_load_started.connect(_on_environment_load_started)
	environment_loader.environment_load_progress.connect(_on_environment_load_progress)
	environment_loader.environment_load_succeeded.connect(_on_environment_load_succeeded)
	environment_loader.environment_load_failed.connect(_on_environment_load_failed)
	environment_loader.environment_cleared.connect(_on_environment_cleared)
	_set_sample_image()
	workout_yaml_edit.text = _default_workout_entry_path()
	workout_yaml_edit.placeholder_text = "Absolute package dir or workout.yaml path"
	_append_status("Environment testbed ready.")
	_append_status("Workout package input accepts an absolute package root or workout.yaml outside res://.")
	_append_status("Example external path: %s" % EXTERNAL_WORKOUT_EXAMPLE_PATH)

func _default_workout_entry_path() -> String:
	if FileAccess.file_exists(EXTERNAL_WORKOUT_EXAMPLE_PATH):
		return EXTERNAL_WORKOUT_EXAMPLE_PATH
	var fixture_absolute := ProjectSettings.globalize_path(FIXTURE_WORKOUT_YAML_PATH)
	if FileAccess.file_exists(fixture_absolute):
		return fixture_absolute
	return EXTERNAL_WORKOUT_EXAMPLE_PATH

func _set_sample_image() -> void:
	asset_path_edit.text = "res://assets/images/perfect-hue-may-14-2026.png"
	config_path_edit.text = ""

func _set_sample_video() -> void:
	asset_path_edit.text = "res://assets/videos/calm_blue_sea_1.ogv"
	config_path_edit.text = ""

func _set_sample_glb() -> void:
	asset_path_edit.text = "res://assets/models/alien-planet.glb"
	config_path_edit.text = "res://assets/models/alien-planet.json"

func _set_sample_splat() -> void:
	asset_path_edit.text = "res://assets/splats/CountrySide farm.compressed.ply"
	config_path_edit.text = "res://assets/splats/CountrySide farm.json"

func _selected_display_mode() -> String:
	return "contain" if display_mode_option.selected == 1 else "cover"

func _load_kind(kind: String) -> void:
	environment_loader.load_environment({
		"request_id": "%s-demo" % kind,
		"kind": kind,
		"asset_path": asset_path_edit.text,
		"config_path": config_path_edit.text,
		"display_mode": _selected_display_mode(),
		"context": {
			"source": "environment_testbed",
		},
		"metadata": {
			"sample": true,
		},
	})

func _on_load_image_pressed() -> void:
	_set_sample_image()
	_load_kind("image")

func _on_load_video_pressed() -> void:
	_set_sample_video()
	_load_kind("video")

func _on_load_glb_pressed() -> void:
	_set_sample_glb()
	_load_kind("glb")

func _on_load_splat_pressed() -> void:
	_set_sample_splat()
	_load_kind("splat")

func _on_load_from_workout_yaml_pressed() -> void:
	environment_loader.load_environment_from_workout_yaml(workout_yaml_edit.text, {
		"request_id": "workout-yaml-demo",
		"display_mode": _selected_display_mode(),
		"context": {
			"source": "environment_testbed",
			"mode": "workout_yaml",
		},
		"metadata": {
			"sample": true,
		},
	})

func _on_clear_pressed() -> void:
	environment_loader.clear_environment()

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

func _on_environment_load_started(request: Dictionary) -> void:
	current_path_label.text = "Current asset: %s" % String(request.get("asset_path", ""))
	_append_status("START %s %s" % [request.get("kind", ""), request.get("asset_path", "")])

func _on_environment_load_progress(progress: Dictionary) -> void:
	_append_status("PROGRESS %s %.2f %s" % [progress.get("status", ""), float(progress.get("progress", 0.0)), progress.get("message", "")])

func _on_environment_load_succeeded(result: Dictionary) -> void:
	current_path_label.text = "Current asset: %s" % String(result.get("asset_path", ""))
	config_path_edit.text = String(result.get("config_path", config_path_edit.text))
	_append_status("SUCCESS %s %s" % [result.get("kind", ""), result.get("asset_path", "")])

func _on_environment_load_failed(error: Dictionary) -> void:
	_append_status("ERROR %s: %s" % [error.get("error_code", "loader_failed"), error.get("message", "")])

func _on_environment_cleared() -> void:
	current_path_label.text = "Current asset: (none)"
	_append_status("CLEARED")

func _append_status(line: String) -> void:
	status_log.append_text("%s\n" % line)
