@tool
extends EditorContextMenuPlugin

const Encoder := preload("res://addons/hermit/editor/hermit_encoder.gd")

func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() != 1 or paths[0] == "res://":
		return
	var dir := paths[0].trim_suffix("/")
	if not DirAccess.dir_exists_absolute(dir):
		return
	if Encoder.list_frames(dir).is_empty():
		return
		
	var icon := EditorInterface.get_editor_theme().get_icon("AnimatedTexture", "EditorIcons")
	add_context_menu_item("Create Hermit Flipbook", _create, icon)
	
func _create(paths: Array) -> void:
	var dir := String(paths[0].trim_suffix("/"))
	var manifest := FileAccess.open(dir + ".hermit", FileAccess.WRITE)
	manifest.store_line(JSON.stringify({"source": dir.get_file(), "fps": 12, "loop": true}))
	manifest.close()
	# TODO optional ignoring the "hermified" folder
	# frames themselves are not needed after baking
	# and should not be shipped or edited in the engine
	FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE).close()
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".import"):
			DirAccess.remove_absolute(dir.path_join(file_name))
	EditorInterface.get_resource_filesystem().scan()
