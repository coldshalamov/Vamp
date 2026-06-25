## test_visual_assets.gd — cheap regression proof for the authored character atlas pass.
##
## The screenshot gate catches framing and FPS. These unit checks catch the easier-to-break wiring:
## material triplets must load, their texture dimensions must agree, and EntityRenderer must still
## instantiate the authored atlas renderer rather than drifting back to procedural rigs.
extends GutTest

const CHARACTER_IDS := [
	"hero", "civilian", "thug", "cop", "hunter",
	"swat", "gunner", "elder", "thrall", "rat",
]
const MATERIAL_DIR := "res://assets/visual/materials/characters"
const METRICS_PATH := "res://docs/evidence/visual_revamp/asset_metrics.json"
const ENTITY_RENDERER_PATH := "res://src/present/EntityRenderer.gd"


func test_character_canvas_texture_triplets_load() -> void:
	for id in CHARACTER_IDS:
		var path := "%s/%s.tres" % [MATERIAL_DIR, id]
		assert_true(ResourceLoader.exists(path), "%s material exists" % id)
		var material = load(path)
		assert_not_null(material, "%s material loads" % id)
		var diffuse: Texture2D = material.diffuse_texture
		var normal: Texture2D = material.normal_texture
		var specular: Texture2D = material.specular_texture
		assert_not_null(diffuse, "%s diffuse texture loads" % id)
		assert_not_null(normal, "%s normal texture loads" % id)
		assert_not_null(specular, "%s specular texture loads" % id)
		assert_gt(diffuse.get_width(), 0, "%s diffuse has width" % id)
		assert_gt(normal.get_width(), 0, "%s normal has width" % id)
		assert_gt(specular.get_width(), 0, "%s specular has width" % id)
		assert_gte(diffuse.get_width(), normal.get_width(), "%s diffuse resolution covers normal map" % id)
		assert_gte(normal.get_width(), specular.get_width(), "%s normal resolution covers specular map" % id)
		assert_eq(diffuse.get_width() * normal.get_height(), diffuse.get_height() * normal.get_width(), "%s normal keeps diffuse aspect" % id)
		assert_eq(diffuse.get_width() * specular.get_height(), diffuse.get_height() * specular.get_width(), "%s specular keeps diffuse aspect" % id)


func test_visual_asset_metrics_cover_the_runtime_materials() -> void:
	assert_true(FileAccess.file_exists(METRICS_PATH), "visual asset metrics exist")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(METRICS_PATH))
	assert_true(parsed is Dictionary, "metrics parse as JSON object")
	var metrics: Dictionary = parsed
	assert_eq((metrics.get("errors", []) as Array).size(), 0, "visual asset generator reported no errors")
	assert_gte(int(metrics.get("production_files", 0)), 49, "production visual file count did not shrink")
	var chars: Dictionary = metrics.get("characters", {})
	for id in CHARACTER_IDS:
		assert_true(chars.has(id), "%s appears in metrics" % id)
		var rec: Dictionary = chars[id]
		assert_eq(int(rec.get("frames", 0)), 128, "%s keeps the 128-frame atlas contract" % id)
		assert_gt(int(rec.get("compressed_bytes", 0)), 0, "%s has compressed atlas bytes" % id)


func test_entity_renderer_uses_authored_atlas_renderer() -> void:
	var source := FileAccess.get_file_as_string(ENTITY_RENDERER_PATH)
	assert_true(source.find("res://src/present/CharacterAtlas2D.gd") != -1, "EntityRenderer preloads CharacterAtlas2D")
	assert_true(source.find("CharacterRig2D.gd") == -1, "EntityRenderer did not drift back to procedural CharacterRig2D")
