extends RefCounted

const SIMPLE_YAML_PARSER_SCRIPT = preload("AeroSimpleYamlParser.gd")

const TYPE_TO_KIND := {
	"image_background": "image",
	"video_background": "video",
	"glb_environment": "glb",
	"splat": "splat",
}

const PREFERRED_ENVIRONMENT_ROLE := "preferred"
const FALLBACK_ENVIRONMENT_ROLE := "fallback"

var _parser: RefCounted = SIMPLE_YAML_PARSER_SCRIPT.new()

func inspect_workout_package(yaml_path: String) -> Dictionary:
	var package_result: Dictionary = _resolve_package_root(yaml_path)
	if not package_result.get("ok", false):
		return package_result
	var package_dir := String(package_result.get("package_dir", ""))
	var workout_path := String(package_result.get("workout_path", ""))
	var workout_record := _load_yaml(workout_path)
	if workout_record.is_empty():
		return _error("invalid_workout_yaml", "Workout YAML could not be loaded: %s" % workout_path, false)

	var set_order_result := _validate_set_order(workout_record)
	if not set_order_result.get("ok", false):
		return set_order_result
	var set_order: Array = Array(set_order_result.get("set_order", [])).duplicate()
	var sets: Array[Dictionary] = []
	for index in range(set_order.size()):
		var descriptor_result := _resolve_set_descriptor(package_dir, workout_path, workout_record, String(set_order[index]), index)
		if not descriptor_result.get("ok", false):
			return descriptor_result
		sets.append(Dictionary(descriptor_result.get("set", {})).duplicate(true))

	return {
		"ok": true,
		"package_dir": package_dir,
		"workout_path": workout_path,
		"workout_id": String(workout_record.get("workoutId", "")),
		"workout_name": String(workout_record.get("workoutName", "")),
		"set_order": set_order,
		"sets": sets,
	}

func build_request_from_workout_yaml(yaml_path: String, context: Dictionary = {}) -> Dictionary:
	return build_request_from_workout_set(yaml_path, 0, context)

func build_request_from_workout_set(yaml_path: String, set_reference: Variant, context: Dictionary = {}) -> Dictionary:
	var package_result: Dictionary = inspect_workout_package(yaml_path)
	if not package_result.get("ok", false):
		return package_result
	var set_result: Dictionary = _select_set_descriptor(package_result, set_reference)
	if not set_result.get("ok", false):
		return set_result
	return _build_request_from_set_descriptor(package_result, Dictionary(set_result.get("set", {})), context)

func _build_request_from_set_descriptor(package_result: Dictionary, set_descriptor: Dictionary, context: Dictionary) -> Dictionary:
	var metadata: Dictionary = {}
	var context_metadata: Variant = context.get("metadata", {})
	if context_metadata is Dictionary:
		metadata.merge(Dictionary(context_metadata), true)
	var preferred_candidate: Dictionary = Dictionary(set_descriptor.get("preferred_environment", {})).duplicate(true)
	var fallback_candidate: Dictionary = Dictionary(set_descriptor.get("fallback_environment", {})).duplicate(true)
	metadata.merge({
		"source": "workout_yaml",
		"package_dir": String(package_result.get("package_dir", "")),
		"workout_path": String(package_result.get("workout_path", "")),
		"workout_id": String(package_result.get("workout_id", "")),
		"workout_name": String(package_result.get("workout_name", "")),
		"set_order": Array(package_result.get("set_order", [])).duplicate(),
		"set_index": int(set_descriptor.get("set_index", 0)),
		"set_id": String(set_descriptor.get("set_id", "")),
		"set_name": String(set_descriptor.get("set_name", "")),
		"environment_id": String(preferred_candidate.get("environment_id", "")),
		"environment_name": String(preferred_candidate.get("environment_name", "")),
		"environment_record_path": String(preferred_candidate.get("environment_record_path", "")),
		"environment_type": String(preferred_candidate.get("environment_type", "")),
		"resource_path": String(preferred_candidate.get("resource_path", "")),
		"preferred_environment_id": String(preferred_candidate.get("environment_id", "")),
		"preferred_environment_name": String(preferred_candidate.get("environment_name", "")),
		"preferred_environment_record_path": String(preferred_candidate.get("environment_record_path", "")),
		"preferred_environment_type": String(preferred_candidate.get("environment_type", "")),
		"preferred_resource_path": String(preferred_candidate.get("resource_path", "")),
		"preferred_asset_path": String(preferred_candidate.get("asset_path", "")),
		"preferred_kind": String(preferred_candidate.get("kind", "")),
		"fallback_environment_id": String(fallback_candidate.get("environment_id", "")),
		"fallback_environment_name": String(fallback_candidate.get("environment_name", "")),
		"fallback_environment_record_path": String(fallback_candidate.get("environment_record_path", "")),
		"fallback_environment_type": String(fallback_candidate.get("environment_type", "")),
		"fallback_resource_path": String(fallback_candidate.get("resource_path", "")),
		"fallback_asset_path": String(fallback_candidate.get("asset_path", "")),
		"fallback_kind": String(fallback_candidate.get("kind", "")),
		"environment_candidates": {
			PREFERRED_ENVIRONMENT_ROLE: preferred_candidate,
			FALLBACK_ENVIRONMENT_ROLE: fallback_candidate,
		},
		"selected_environment_role": PREFERRED_ENVIRONMENT_ROLE,
	}, true)

	var request := {
		"request_id": String(context.get("request_id", "")).strip_edges(),
		"kind": String(preferred_candidate.get("kind", "")).strip_edges(),
		"asset_path": String(preferred_candidate.get("asset_path", "")).strip_edges(),
		"config_path": String(preferred_candidate.get("config_path", context.get("config_path", ""))).strip_edges(),
		"fit_mode": String(context.get("fit_mode", "cover")).strip_edges(),
		"context": context.duplicate(true),
		"metadata": metadata,
	}
	return {
		"ok": true,
		"request": request,
	}

func _validate_set_order(workout_record: Dictionary) -> Dictionary:
	var set_order_value: Variant = workout_record.get("setOrder", [])
	if not (set_order_value is Array) or set_order_value.is_empty():
		return _error("invalid_workout_yaml", "Workout YAML is missing a usable setOrder list.", false)
	var set_order: Array = []
	for entry in Array(set_order_value):
		var set_id := String(entry).strip_edges()
		if set_id.is_empty():
			return _error("invalid_workout_yaml", "Workout YAML contains an empty setOrder entry.", false)
		set_order.append(set_id)
	return {
		"ok": true,
		"set_order": set_order,
	}

func _resolve_set_descriptor(package_dir: String, workout_path: String, workout_record: Dictionary, set_id: String, set_index: int) -> Dictionary:
	var set_result: Dictionary = _find_yaml_record_by_id(package_dir.path_join("sets"), "setId", set_id)
	if not set_result.get("ok", false):
		return set_result
	var set_record: Dictionary = Dictionary(set_result.get("record", {}))
	var preferred_environment_id := String(set_record.get("preferredEnvironmentId", "")).strip_edges()
	if preferred_environment_id.is_empty():
		return _error("invalid_workout_yaml", "Resolved set is missing preferredEnvironmentId.", false)
	var fallback_environment_id := String(set_record.get("fallbackEnvironmentId", "")).strip_edges()
	if fallback_environment_id.is_empty():
		return _error("invalid_workout_yaml", "Resolved set is missing fallbackEnvironmentId.", false)

	var preferred_environment_result := _find_yaml_record_by_id(package_dir.path_join("environments"), "environmentId", preferred_environment_id)
	if not preferred_environment_result.get("ok", false):
		return preferred_environment_result
	var fallback_environment_result := _find_yaml_record_by_id(package_dir.path_join("environments"), "environmentId", fallback_environment_id)
	if not fallback_environment_result.get("ok", false):
		return fallback_environment_result

	var preferred_candidate_result := _build_environment_candidate(package_dir, Dictionary(preferred_environment_result.get("record", {})), String(preferred_environment_result.get("path", "")))
	if not preferred_candidate_result.get("ok", false):
		return preferred_candidate_result
	var fallback_candidate_result := _build_environment_candidate(package_dir, Dictionary(fallback_environment_result.get("record", {})), String(fallback_environment_result.get("path", "")))
	if not fallback_candidate_result.get("ok", false):
		return fallback_candidate_result

	var preferred_candidate := Dictionary(preferred_candidate_result.get("candidate", {})).duplicate(true)
	var fallback_candidate := Dictionary(fallback_candidate_result.get("candidate", {})).duplicate(true)

	return {
		"ok": true,
		"set": {
			"set_index": set_index,
			"set_id": set_id,
			"set_name": String(set_record.get("setName", "")),
			"set_record_path": String(set_result.get("path", "")),
			"environment_id": String(preferred_candidate.get("environment_id", "")),
			"environment_name": String(preferred_candidate.get("environment_name", "")),
			"environment_record_path": String(preferred_candidate.get("environment_record_path", "")),
			"environment_type": String(preferred_candidate.get("environment_type", "")),
			"kind": String(preferred_candidate.get("kind", "")),
			"resource_path": String(preferred_candidate.get("resource_path", "")),
			"asset_path": String(preferred_candidate.get("asset_path", "")),
			"preferred_environment_id": preferred_environment_id,
			"fallback_environment_id": fallback_environment_id,
			"preferred_environment": preferred_candidate,
			"fallback_environment": fallback_candidate,
			"environment_candidates": {
				PREFERRED_ENVIRONMENT_ROLE: preferred_candidate,
				FALLBACK_ENVIRONMENT_ROLE: fallback_candidate,
			},
			"workout_id": String(workout_record.get("workoutId", "")),
			"workout_name": String(workout_record.get("workoutName", "")),
			"workout_path": workout_path,
			"package_dir": package_dir,
		},
	}

func _build_environment_candidate(package_dir: String, environment_record: Dictionary, environment_record_path: String) -> Dictionary:
	var environment_type := String(environment_record.get("type", "")).strip_edges()
	var kind := String(TYPE_TO_KIND.get(environment_type, ""))
	if kind.is_empty():
		return _error("invalid_environment_type", "Environment type '%s' is not supported by AeroBeat Tool Environment." % environment_type, false)

	var resource_path := String(environment_record.get("resourcePath", "")).strip_edges()
	if resource_path.is_empty():
		return _error("invalid_environment_record", "Environment record is missing resourcePath.", false)
	var asset_path := package_dir.path_join(resource_path).simplify_path()
	var config_path := String(environment_record.get("configPath", "")).strip_edges()
	var resolved_config_path := package_dir.path_join(config_path).simplify_path() if not config_path.is_empty() else ""

	return {
		"ok": true,
		"candidate": {
			"environment_id": String(environment_record.get("environmentId", "")),
			"environment_name": String(environment_record.get("environmentName", "")),
			"environment_record_path": environment_record_path,
			"environment_type": environment_type,
			"kind": kind,
			"resource_path": resource_path,
			"asset_path": asset_path,
			"config_path": resolved_config_path,
			"configPath": resolved_config_path,
		},
	}

func _select_set_descriptor(package_result: Dictionary, set_reference: Variant) -> Dictionary:
	var sets: Array = Array(package_result.get("sets", []))
	if sets.is_empty():
		return _error("invalid_workout_yaml", "Workout package does not expose any sets.", false)

	if set_reference is int:
		var set_index := int(set_reference)
		if set_index < 0 or set_index >= sets.size():
			return _error("missing_set_ref", "Workout set index %d is out of range." % set_index, false)
		return {
			"ok": true,
			"set": Dictionary(sets[set_index]).duplicate(true),
		}

	var set_id := String(set_reference).strip_edges()
	if set_id.is_empty():
		return _error("missing_set_ref", "Workout set reference is empty.", false)
	for set_descriptor_variant in sets:
		if not (set_descriptor_variant is Dictionary):
			continue
		var set_descriptor := Dictionary(set_descriptor_variant)
		if String(set_descriptor.get("set_id", "")) == set_id:
			return {
				"ok": true,
				"set": set_descriptor.duplicate(true),
			}
	return _error("missing_set_ref", "Could not resolve workout set '%s'." % set_id, false)

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
