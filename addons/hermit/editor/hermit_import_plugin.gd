@tool
extends EditorImportPlugin

const Encoder := preload("res://addons/hermit/editor/hermit_encoder.gd")

func _get_importer_name() -> String:
	return "hermit.flipbook"
	
func _get_visible_name() -> String:
	return "Hermit Flipbook"
	
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["hermit"])
	
func _get_save_extension() -> String:
	return "res"
	
func _get_resource_type() -> String:
	return "Resource"
	
func _get_priority() -> float:
	return 1.0
	
func _get_import_order() -> int:
	return 0
	
func _get_format_version() -> int:
	return 1
	
func _get_preset_count() -> int:
	return 1
	
func _get_preset_name(preset_index: int) -> String:
	return "Default"
	
func _can_import_threaded() -> bool:
	return false
	
func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{"name": "fps", "default_value": 12.0, "property_hint": PROPERTY_HINT_RANGE, "hint_string": "1, 120, 0.001"},
		{"name": "loop", "default_value": true}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true
	
func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var text := FileAccess.get_file_as_string(source_file).strip_edges()
	var manifest: Variant = JSON.parse_string(text) if not text.is_empty() else {}
	if not manifest is Dictionary:
		push_error("Hermit: %s is not a JSON object" % source_file)
		return ERR_PARSE_ERROR
	var source_dir: String = manifest.get("source", source_file.get_file().get_basename())
	var frames_dir := source_file.get_base_dir().path_join(source_dir)
	var files := Encoder.list_frames(frames_dir)
	if files.is_empty():
		push_error("Hermit: no PNG frames found in %s. If using other formats, either convert to PNG or edit plugin's source code." % frames_dir)
		return ERR_FILE_NOT_FOUND
		
	var encoder := Encoder.new()
	for path in files:
		encoder.add_frame(encoder.load_frame(path))
	encoder.build_index_frames()
	var flipbook := encoder.build_flipbook(options["fps"], options["loop"])
	print("Hermit: %s %d frames (%d unique), %d blocks" % [
		source_file.get_file(), encoder.frame_map.size(), encoder.unique_frames.size(), encoder.block_ids.size()
	])
	return ResourceSaver.save(flipbook, "%s.%s" % [save_path, _get_save_extension()])
