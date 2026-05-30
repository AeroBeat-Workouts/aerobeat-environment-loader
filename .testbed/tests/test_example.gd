extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const ADDONS_MANIFEST_PATH := "addons.jsonc"
const EXPECTED_PLUGIN_NAME := "AeroBeat Environment Loader"
const EXPECTED_PLUGIN_DESCRIPTION := "Environment loader/orchestrator package for AeroBeat. Consumes aerobeat-environment-core contracts, fulfills image through the shared AeroImageLoader facade, fulfills GLB through the shared AeroGLTFLoader facade, fulfills video through AeroVideoPlayerManager, and keeps workout YAML bridging."
const EXPECTED_MANIFEST_ADDON_KEYS := [
	"aerobeat-environment-loader",
	"aerobeat-environment-core",
	"aerobeat-tool-core",
	"aerobeat-tool-video-player",
	"aerobeat-vendor-godot-video",
	"aerobeat-tool-image-loader",
	"aerobeat-vendor-godot-image",
	"aerobeat-tool-gltf-loader",
	"aerobeat-tool-device-detection",
	"aerobeat-vendor-godot-gltf",
	"gut",
]

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_describes_environment_loader_boundary() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("shared **environment loader/orchestrator package**"), "README should describe the environment loader role")
	assert_true(readme_text.contains("aerobeat-environment-core"), "README should point at the shared environment contract package")
	assert_true(readme_text.contains("public `AeroEnvironmentLoader.gd` entrypoint"), "README should document the renamed loader entrypoint")
	assert_true(readme_text.contains("AeroImageLoader"), "README should document the shared image facade dependency")
	assert_true(readme_text.contains("AeroVideoPlayerManager"), "README should document the shared video facade dependency")
	assert_true(readme_text.contains("AeroGLTFLoader"), "README should document the shared GLTF facade dependency")
	assert_true(readme_text.contains("swappable"), "README should describe the backend boundary as swappable")
	assert_true(readme_text.contains("image fulfillment composed through the shared `AeroImageLoader` facade"), "README should keep the image ownership boundary explicit")
	assert_true(readme_text.contains("GLB fulfillment orchestrated through the shared `AeroGLTFLoader` facade"), "README should describe the GLB boundary through the shared facade")
	assert_true(readme_text.contains("workout/YAML bridge"), "README should keep the workout YAML bridge in the loader lane")
	assert_true(readme_text.contains("preferredEnvironmentId"), "README should document the preferred environment contract")
	assert_true(readme_text.contains("fallbackEnvironmentId"), "README should document the fallback environment contract")
	assert_true(readme_text.contains("loader-owned runtime logic"), "README should keep device policy ownership out of workout YAML")
	assert_true(readme_text.contains("assets/unsupported_device_policy.yaml"), "README should document the loader-owned unsupported-device policy asset")
	assert_true(readme_text.contains("AeroDeviceDetection"), "README should document the device-detection runtime seam")

func test_plugin_cfg_description_matches_environment_loader_scope() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK, "plugin.cfg should parse cleanly")
	assert_eq(config.get_value("plugin", "name", ""), EXPECTED_PLUGIN_NAME, "plugin.cfg name should reflect the environment loader role")
	assert_eq(
		config.get_value("plugin", "description", ""),
		EXPECTED_PLUGIN_DESCRIPTION,
		"plugin.cfg description should reflect the environment loader contract boundary"
	)

func _manifest_addon_keys(manifest_text: String) -> Array:
	var addon_keys: Array = []
	var in_addons_block := false
	for raw_line in manifest_text.split("\n"):
		var line := String(raw_line)
		var comment_index := line.find("//")
		if comment_index >= 0:
			line = line.substr(0, comment_index)
		var trimmed := line.strip_edges()
		if trimmed == '"addons": {':
			in_addons_block = true
			continue
		if not in_addons_block:
			continue
		if trimmed == "}":
			break
		if not trimmed.begins_with('"'):
			continue
		if not trimmed.ends_with("{"):
			continue
		var quote_end := trimmed.find('"', 1)
		assert_true(quote_end > 1, "addons manifest addon entries should keep quoted addon keys")
		addon_keys.append(trimmed.substr(1, quote_end - 1))
	addon_keys.sort()
	return addon_keys

func test_addons_manifest_keeps_expected_dependencies_only() -> void:
	var manifest_text := _read_repo_file(ADDONS_MANIFEST_PATH)
	assert_true(manifest_text.contains('"aerobeat-environment-core"'), "addons manifest should pin aerobeat-environment-core")
	assert_true(manifest_text.contains('"aerobeat-tool-image-loader"'), "addons manifest should pin aerobeat-tool-image-loader for the shared image facade")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-image"'), "addons manifest should pin aerobeat-vendor-godot-image for the Godot image backend")
	assert_true(manifest_text.contains('"aerobeat-tool-core"'), "addons manifest should pin aerobeat-tool-core for the shared video contract")
	assert_true(manifest_text.contains('"aerobeat-tool-video-player"'), "addons manifest should pin aerobeat-tool-video-player for the shared playback facade")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-video"'), "addons manifest should pin aerobeat-vendor-godot-video for the Godot backend")
	assert_true(manifest_text.contains('"aerobeat-tool-gltf-loader"'), "addons manifest should pin aerobeat-tool-gltf-loader for the shared GLTF facade")
	assert_true(manifest_text.contains('"aerobeat-tool-device-detection"'), "addons manifest should pin aerobeat-tool-device-detection for runtime hardware routing")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-gltf"'), "addons manifest should pin aerobeat-vendor-godot-gltf for the GLTF runtime backend")
	assert_true(manifest_text.contains('"gut"'), "addons manifest should pin gut for repo-local tests")
	assert_false(manifest_text.contains('"aerobeat-core"'), "addons manifest should not reintroduce stale aerobeat-core drift")
	var expected_keys := EXPECTED_MANIFEST_ADDON_KEYS.duplicate()
	expected_keys.sort()
	assert_eq(_manifest_addon_keys(manifest_text), expected_keys, "addons manifest should stay an explicit exact dependency surface so transitive drift cannot hide behind stale installs")

func test_project_autoloads_public_runtime_seams() -> void:
	assert_eq(str(ProjectSettings.get_setting("autoload/AeroImageLoader", "")), "*res://addons/aerobeat-tool-image-loader/src/AeroImageLoader.gd", "Testbed should expose the public image-loader singleton through autoload")
	assert_eq(str(ProjectSettings.get_setting("autoload/AeroDeviceDetection", "")), "*res://addons/aerobeat-tool-device-detection/src/AeroDeviceDetection.gd", "Testbed should keep device detection autoloaded for runtime routing proof")
