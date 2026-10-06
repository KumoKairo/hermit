extends Node2D

const PER_ROW = 256
var reference: TextureRect

func _ready():
	var frame := Image.load_from_file(ProjectSettings.globalize_path("res://frames/bg.png"))
	frame.convert(Image.FORMAT_RGBA8)
	var frame_size := frame.get_size()
	var grid := (frame_size + Vector2i(3, 3)) / 4
	var src := frame.duplicate() as Image
	src.crop(grid.x * 4, grid.y * 4)
	
	var data := src.get_data()
	var stride := src.get_width() * 4
	var block_ids := {}
	var block_origins: Array[Vector2i] = []
	var ids := PackedInt32Array()
	ids.resize(grid.x * grid.y)
	
	for block_y in grid.y:
		for block_x in grid.x: 
			var offset := block_y * 4 * stride + block_x * 16
			var key := data.slice(offset, offset + 16)
			key.append_array(data.slice(offset + stride, offset + stride + 16))
			key.append_array(data.slice(offset + stride * 2, offset + stride * 2 + 16))
			key.append_array(data.slice(offset + stride * 3, offset + stride * 3 + 16))
			
			var id: int = block_ids.get(key, -1)
			if id < 0:
				# size is the number of unique blocks
				# if we don't have this block on our palette yet,
				# we store it as a new one
				id = block_origins.size() 
				block_ids[key] = id
				block_origins.append(Vector2i(block_x, block_y) * 4)
			# we store the id of the block anyway to reconstruct the image later
			# it's what the image itself boils down to
			ids[block_y * grid.x + block_x] = id
				
	print("blocks: ", grid.x * grid.y, "  unique: ", block_origins.size())
	
	var rows := ceili(float(block_origins.size()) / PER_ROW)
	var palette := Image.create_empty(PER_ROW * 4, rows * 4, false, Image.FORMAT_RGBA8)
	for id in block_origins.size():
		var dst := Vector2i(id % PER_ROW, id / PER_ROW) * 4
		palette.blit_rect(src, Rect2i(block_origins[id], Vector2i(4, 4)), dst)
	palette.save_png("user://palette.png")
	
	var index_img := Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RGBA8, ids.to_byte_array())
	# optional data saving technique
	# if we have enough bytes to store the whole image
	# skip the Alpha part of the bit
	# see shader code for more reconstruction
	if block_origins.size() < 65536:
		index_img.convert(Image.FORMAT_RG8)
	# ask me about why we don't care about FORMAT_RGB8 here for a bedtime story
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://hermit/hermit_decode.gdshader")
	mat.set_shader_parameter("palette", ImageTexture.create_from_image(palette))
	mat.set_shader_parameter("indices", ImageTexture.create_from_image(index_img))
	mat.set_shader_parameter("frame_size", frame_size)
	$Display.material = mat
	$Display.size = Vector2(frame_size)
	
	reference = TextureRect.new()
	reference.texture = ImageTexture.create_from_image(frame)
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.visible = false
	add_child(reference)
	
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		reference.visible = not reference.visible
		$Display.visible = not reference.visible
		get_window().title = "original" if reference.visible else "decoded"
