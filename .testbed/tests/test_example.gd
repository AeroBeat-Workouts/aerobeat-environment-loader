extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const ADDONS_MANIFEST_PATH := "addons.jsonc"
const EXPECTED_PLUGIN_NAME := "AeroBeat Environment Loader"
const EXPECTED_PLUGIN_DESCRIPTION := "Environment loader/orchestrator package for AeroBeat. Consumes aerobeat-environment-core contracts, fulfills GLB through the shared AeroGLTFTool facade, fulfills video through AeroVideoPlayerManager, and keeps image fulfillment plus workout YAML bridging."

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
	assert_true(readme_text.contains("AeroVideoPlayerManager"), "README should document the shared video facade dependency")
	assert_true(readme_text.contains("AeroGLTFTool"), "README should document the shared GLTF facade dependency")
	assert_true(readme_text.contains("swappable"), "README should describe the backend boundary as swappable")
	assert_true(readme_text.contains("built-in image fulfillment"), "README should keep image ownership explicit")
	assert_true(readme_text.contains("GLB fulfillment orchestrated through the shared `AeroGLTFTool` facade"), "README should describe the GLB boundary through the shared facade")
	assert_true(readme_text.contains("workout/YAML bridge"), "README should keep the workout YAML bridge in the loader lane")

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

func test_addons_manifest_keeps_expected_dependencies_only() -> void:
	var manifest_text := _read_repo_file(ADDONS_MANIFEST_PATH)
	assert_true(manifest_text.contains('"aerobeat-environment-core"'), "addons manifest should pin aerobeat-environment-core")
	assert_true(manifest_text.contains('"aerobeat-tool-core"'), "addons manifest should pin aerobeat-tool-core for the shared video contract")
	assert_true(manifest_text.contains('"aerobeat-tool-video-player"'), "addons manifest should pin aerobeat-tool-video-player for the shared playback facade")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-video"'), "addons manifest should pin aerobeat-vendor-godot-video for the Godot backend")
	assert_true(manifest_text.contains('"aerobeat-tool-gltf"'), "addons manifest should pin aerobeat-tool-gltf for the shared GLTF facade")
	assert_true(manifest_text.contains('"aerobeat-vendor-godot-gltf"'), "addons manifest should pin aerobeat-vendor-godot-gltf for the GLTF runtime backend")
	assert_true(manifest_text.contains('"gut"'), "addons manifest should pin gut for repo-local tests")
	assert_false(manifest_text.contains('"aerobeat-core"'), "addons manifest should not reintroduce stale aerobeat-core drift")
