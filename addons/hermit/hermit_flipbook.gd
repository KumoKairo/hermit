@tool
class_name HermitFlipbook
extends Resource

@export_dir var source_dir := ""
@export var fps := 12.0
@export var loop := true
@export_tool_button("Bake") var bake_action = bake

@export_storage var frame_size := Vector2i.ZERO
@export_storage var grid_size := Vector2i.ZERO
@export_storage var frame_map := PackedInt32Array()
@export_storage var palette_data := PackedByteArray()
@export_storage var index_bytes := 2
@export_storage var index_raw_size := 0
@export_storage var index_data := PackedByteArray()

# TODO consider splitting the frame data into arrays ahead of time to avoid copying
# var _frames: Array[PackedByteArray] = []
var _palette_texture: Texture2D
var _indices := PackedByteArray()

func get_frame_count() -> int:
	return frame_map.size()
	
func get_unique_frame(frame: int) -> int:
	return frame_map[frame]
	
func get_palette_texture() -> Texture2D:
	if _palette_texture == null:
		var img := Image.new()
		# can switch to png if needed
		# shouldn't be any problem with WebP here
		img.load_webp_from_buffer(palette_data)
		_palette_texture = ImageTexture.create_from_image(img)
	return _palette_texture
	
func get_index_format() -> Image.Format:
	return Image.FORMAT_RG8 if index_bytes == 2 else Image.FORMAT_RGBA8
	
func get_index_bytes(unique_frame: int) -> PackedByteArray:
	if _indices.is_empty():
		_indices = index_data.decompress(index_raw_size, FileAccess.COMPRESSION_ZSTD)
	var size := grid_size.x * grid_size.y * index_bytes
	return _indices.slice(unique_frame * size, (unique_frame + 1) * size)
	
func prepare() -> void:
	get_palette_texture()
	if _indices.is_empty():
		_indices = index_data.decompress(index_raw_size, FileAccess.COMPRESSION_ZSTD)
		
func release() -> void:
	_palette_texture = null
	_indices = PackedByteArray()
	
# TODO this is a convenience Bake button and Fully in-Godot UX
# that trade usability for storing baked data in source control
# also no scripting hints
# and calling editor code from gameplay code which kinda smells to me
# if you have better ideas - please help yourself
# ---
# check commit history for the original way to handle custom format import
# it's a bit less usable in terms of UX, but cleaner code and less smell imo
func bake() -> void:
	var encoder_script = load("res://addons/hermit/editor/hermit_encoder.gd")
	var files: PackedStringArray = encoder_script.list_frames(source_dir)
	if files.is_empty():
		push_error("Hermit: no PNG frames found in %s. If using other formats, either convert to PNG or edit plugin's source code." % source_dir)
		return
	var encoder = encoder_script.new()
	for path in files:
		encoder.add_frame(encoder.load_frame(path))
	encoder.build_index_frames()
	encoder.fill(self)
	release() # clearning possible previous bake, marking dirty
	emit_changed()
	if not resource_path.is_empty():
		ResourceSaver.save(self, resource_path)
	print("Hermit: baked %s %d frames (%d unique), %d blocks" % [
		resource_path.get_file(), frame_map.size(), encoder.unique_frames.size(), encoder.block_ids.size()
	])
