@tool
extends EditorPlugin

const ImportPlugin := preload("res://addons/hermit/editor/hermit_import_plugin.gd")

var import_plugin: EditorImportPlugin

func _enter_tree() -> void:
	import_plugin = ImportPlugin.new()
	add_import_plugin(import_plugin)
	
func _exit_tree() -> void:
	remove_import_plugin(import_plugin)
	import_plugin = null
