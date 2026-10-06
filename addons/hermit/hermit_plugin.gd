@tool
extends EditorPlugin

const ImportPlugin := preload("res://addons/hermit/editor/hermit_import_plugin.gd")
const ContextMenu := preload("res://addons/hermit/editor/hermit_context_menu.gd")

var import_plugin: EditorImportPlugin
var context_menu: EditorContextMenuPlugin

func _enter_tree() -> void:
	import_plugin = ImportPlugin.new()
	add_import_plugin(import_plugin)
	context_menu = ContextMenu.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, context_menu)
	
func _exit_tree() -> void:
	remove_import_plugin(import_plugin)
	remove_context_menu_plugin(context_menu)
	import_plugin = null
	context_menu = null
