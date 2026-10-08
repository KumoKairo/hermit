@tool
class_name HermitFlipbook
extends Resource

enum PaletteFormat { LOSSLESS, DXT, BC7 }

@export var fps := 12.0
@export var loop := true

@export_storage var palette_format := PaletteFormat.LOSSLESS
@export_storage var palette_size := Vector2i.ZERO
@export_storage var palette_image_format = Image.FORMAT_RGBA8
@export_storage var palette_raw_size := 0

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
		var img: Image
		if palette_format == PaletteFormat.LOSSLESS:
			img = Image.new()
			# can switch to png if needed
			# shouldn't be any problem with WebP here
			img.load_webp_from_buffer(palette_data)
		else:
			var raw := palette_data.decompress(palette_raw_size, FileAccess.COMPRESSION_ZSTD)
			img = Image.create_from_data(palette_size.x, palette_size.y, false, palette_image_format, raw)
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
