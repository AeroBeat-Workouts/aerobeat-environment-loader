extends RefCounted

const SIMPLE_YAML_PARSER_SCRIPT = preload("AeroSimpleYamlParser.gd")

const TYPE_TO_KIND := {
	"image_background": "image",
	"video_background": "video",
	"glb_environment": "glb",
	"splat": "splat",
}

var _parser: RefCounted = SIMPLE_YAML_PARSER_SCRIPT.new()

func build_request_from_workout_yaml(yaml_path: String, context: Dictionary = {}) -> Dictionary:
	var package_result: Dictionary = _resolve_package_root(yaml_path)
	if not package_result.get("ok", false):
		return package_result
	var package_dir := String(package_result.get("package_dir", ""))
	var workout_path := String(package_result.get("workout_path", ""))
	var workout_record := _load_yaml(workout_path)
	if workout_record.is_empty():
		return _error("invalid_workout_yaml", "Workout YAML could not be loaded: %s" % workout_path, false)

	var set_order_value: Variant = workout_record.get("setOrder", [])
	if not (set_order_value is Array) or set_order_value.is_empty():
		return _error("invalid_workout_yaml", "Workout YAML is missing a usable setOrder list.", false)
	var set_order: Array = Array(set_order_value)
	var first_set_id := String(set_order[0]).strip_edges()
	if first_set_id.is_empty():
		return _error("invalid_workout_yaml", "Workout YAML contains an empty setOrder entry.", false)

	var set_result: Dictionary = _find_yaml_record_by_id(package_dir.path_join("sets"), "setId", first_set_id)
	if not set_result.get("ok", false):
		return set_result
	var set_record: Dictionary = set_result.get("record", {})
	var environment_id := String(set_record.get("environmentId", "")).strip_edges()
	if environment_id.is_empty():
		return _error("invalid_workout_yaml", "Resolved set is missing environmentId.", false)

	var environment_result: Dictionary = _find_yaml_record_by_id(package_dir.path_join("environments"), "environmentId", environment_id)
	if not environment_result.get("ok", false):
		return environment_result
	var environment_record: Dictionary = environment_result.get("record", {})
	var environment_type := String(environment_record.get("type", "")).strip_edges()
	var kind := String(TYPE_TO_KIND.get(environment_type, ""))
	if kind.is_empty():
		return _error("invalid_environment_type", "Environment type '%s' is not supported by AeroBeat Tool Environment." % environment_type, false)

	var resource_path := String(environment_record.get("resourcePath", "")).strip_edges()
	if resource_path.is_empty():
		return _error("invalid_environment_record", "Environment record is missing resourcePath.", false)
	var asset_path := package_dir.path_join(resource_path).simplify_path()

	var metadata: Dictionary = {}
	var context_metadata: Variant = context.get("metadata", {})
	if context_metadata is Dictionary:
		metadata.merge(Dictionary(context_metadata), true)
	metadata.merge({
		"source": "workout_yaml",
		"package_dir": package_dir,
		"workout_path": workout_path,
		"workout_id": String(workout_record.get("workoutId", "")),
		"set_id": first_set_id,
		"environment_id": environment_id,
		"environment_name": String(environment_record.get("environmentName", "")),
		"environment_record_path": String(environment_result.get("path", "")),
	}, true)

	var request := {
		"request_id": String(context.get("request_id", "")).strip_edges(),
		"kind": kind,
		"asset_path": asset_path,
		"config_path": String(context.get("config_path", "")).strip_edges(),
		"display_mode": String(context.get("display_mode", "cover")).strip_edges(),
		"context": context.duplicate(true),
		"metadata": metadata,
	}
	return {
		"ok": true,
		"request": request,
	}

func _resolve_package_root(yaml_path: String) -> Dictionary:
	var normalized := yaml_path.strip_edges()
	if normalized.is_empty():
		return _error("invalid_workout_yaml", "No workout YAML path was provided.", false)
	if DirAccess.dir_exists_absolute(normalized):
		var workout_path := normalized.path_join("workout.yaml")
		if FileAccess.file_exists(workout_path):
			return {"ok": true, "package_dir": normalized, "workout_path": workout_path}
		return _error("invalid_workout_yaml", "Package directory does not contain workout.yaml: %s" % normalized, false)
	if FileAccess.file_exists(normalized):
		return {
			"ok": true,
			"package_dir": normalized.get_base_dir(),
			"workout_path": normalized,
		}
	return _error("invalid_workout_yaml", "Workout YAML path does not exist: %s" % normalized, false)

func _find_yaml_record_by_id(directory_path: String, id_key: String, record_id: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(directory_path):
		return _error("invalid_workout_yaml", "YAML directory does not exist: %s" % directory_path, false)
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return _error("invalid_workout_yaml", "YAML directory could not be opened: %s" % directory_path, false)
	var file_names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if file_name.ends_with(".yaml") or file_name.ends_with(".yml"):
			file_names.append(file_name)
	dir.list_dir_end()
	file_names.sort()
	for file_name in file_names:
		var absolute_path := directory_path.path_join(file_name)
		var record: Dictionary = _load_yaml(absolute_path)
		if String(record.get(id_key, "")).strip_edges() == record_id:
			return {
				"ok": true,
				"path": absolute_path,
				"record": record,
			}
	return _error("missing_environment_ref", "Could not resolve %s '%s' under %s." % [id_key, record_id, directory_path], false)

func _load_yaml(path: String) -> Dictionary:
	var parsed: Variant = _parser.parse_file(path)
	return parsed if parsed is Dictionary else {}

func _error(error_code: String, message: String, recoverable: bool) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"message": message,
		"recoverable": recoverable,
	}
