extends Node2D

const FLIPBOOK_PATH := "res://char-loop.res"
var flipbook: HermitFlipbook

const PER_ROW := 256
const FRAMES_DIR := "res://frames/char-loop"
const FPS := 12.0

const BITS_IN_TWO_BYTES = 65536

var files := PackedStringArray()
var frame_size := Vector2i.ZERO
var grid := Vector2i.ZERO
var block_ids := {}
var frames: Array[PackedInt32Array] = []

var index_frames: Array[PackedByteArray] = []
var index_format := Image.FORMAT_RG8
var index_img : Image
var index_tex : ImageTexture
var current_frame := 0
var elapsed := 0.0

@onready var decoder: SubViewport = $Decoder
@onready var display: ColorRect = $Decoder/Display
@onready var sprite: Sprite2D = $Sprite
var playing := true

func _ready():
	if not ResourceLoader.exists(FLIPBOOK_PATH):
		encode_and_save()
	flipbook = load(FLIPBOOK_PATH)
	
	var g := flipbook.grid_size
	index_img = Image.create_from_data(g.x, g.y, false, flipbook.get_index_format(), flipbook.get_index_bytes(0))
	index_tex = ImageTexture.create_from_image(index_img)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://addons/hermit/hermit_decode.gdshader")
	mat.set_shader_parameter("palette", flipbook.get_palette_texture())
	mat.set_shader_parameter("indices", index_tex)
	mat.set_shader_parameter("frame_size", frame_size)
	display.material = mat
	display.size = Vector2(frame_size)
	
	decoder.size = frame_size
	decoder.transparent_bg = true
	decoder.disable_3d = true
	decoder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	sprite.texture = decoder.get_texture()
	sprite.position = get_viewport_rect().size / 2.0
	show_frame(0)
	
func _process(delta: float) -> void:
	elapsed += delta
	var one_over_fps = 1.0 / flipbook.fps
	if elapsed >= one_over_fps:
		elapsed -= one_over_fps
		show_frame((current_frame + 1) % flipbook.get_frame_count())

func show_frame(f: int) -> void:
	current_frame = f
	
	var g := flipbook.grid_size
	index_img.set_data(g.x, g.y, false, flipbook.get_index_format(), flipbook.get_index_bytes(f))
	index_tex.update(index_img)
	decoder.render_target_update_mode = SubViewport.UPDATE_ONCE

func list_frames(dir: String) -> PackedStringArray:
	var abs_dir := ProjectSettings.globalize_path(dir)
	var names := Array(DirAccess.get_files_at(abs_dir)).filter(
		func(n: String) -> bool: return n.get_extension().to_lower() == "png"
	)
	# natural compare puts 'frame10' after 'frame2'
	# my examples use proper naming, but this comparison is too easy to use to skip here
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var paths := PackedStringArray()
	for n: String in names:
		paths.append(abs_dir.path_join(n))
	return paths

func load_frame_global(path: String) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var clean := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	# the trick here is to normalize pixels where alpha is zero
	# without it, fully transparent pixels can hold color info, even though we don't see anything but transparency
	# which ruins our de-dupe process (transparent pixels can land on different IDs, even though they look the same)
	# the transparent pixel color values depend on the CC app, but again, it's too easy to just normalize it here
	clean.blit_rect_mask(img, img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return clean
	
func add_frame(img: Image) -> void:
	if frame_size == Vector2i.ZERO:
		frame_size = img.get_size()
		grid = (frame_size + Vector2i(3, 3)) / 4
	elif img.get_size() != frame_size:
		push_error("frame sizes are not consistent")
		return
	var src := img.duplicate() as Image
	src.crop(grid.x * 4, grid.y * 4)
	var data := src.get_data()
	
	# can optionally HASH_SHA256 here on the src to detect duplicate frames
	# frames become unique_frames
	# --- hashing code and uniqueness checks
	# --- return found frame if any
	
	var stride := grid.x * 16
	var ids := PackedInt32Array()
	ids.resize(grid.x * grid.y)
	for by in grid.y: # block_x
		for bx in grid.x: # block_y
			var o := by * 4 * stride + bx * 16 # offset
			var key := data.slice(o, o + 16)
			key.append_array(data.slice(o + stride, o + stride + 16))
			key.append_array(data.slice(o + stride * 2, o + stride * 2 + 16))
			key.append_array(data.slice(o + stride * 3, o + stride * 3 + 16))
			var id: int = block_ids.get(key, -1)
			if id < 0:
				# size is the number of unique blocks
				# if we don't have this block on our palette yet,
				# we store it as a new one
				id = block_ids.size() 
				block_ids[key] = id
			# we store the id of the block anyway to reconstruct the image later
			# it's what the image itself boils down to
			ids[by * grid.x + bx] = id
	
	frames.append(ids)
			
func build_palette() -> Image:
	var keys := block_ids.keys()
	var rows := ceili(float(keys.size()) / PER_ROW)
	var palette := Image.create_empty(PER_ROW * 4, rows * 4, false, Image.FORMAT_RGBA8)
	for id in keys.size():
		var tile := Image.create_from_data(4, 4, false, Image.FORMAT_RGBA8, keys[id])
		palette.blit_rect(tile, Rect2i(0, 0, 4, 4), Vector2i(id % PER_ROW, id / PER_ROW) * 4)
	return palette
	
func build_index_frames() -> void:
	var wide := block_ids.size() > BITS_IN_TWO_BYTES
	# ask me about why we don't care about FORMAT_RGB8 here for a bedtime story
	index_format = Image.FORMAT_RGBA8 if wide else Image.FORMAT_RG8
	for ids in frames:
		var img := Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RGBA8, ids.to_byte_array())
		img.convert(index_format)
		index_frames.append(img.get_data())
		
func build_flipbook() -> HermitFlipbook:
	var fb := HermitFlipbook.new()
	fb.fps = FPS
	fb.frame_size = frame_size
	fb.grid_size = grid
	fb.frame_map = frames
	fb.palette_data = build_palette().save_webp_to_buffer(false)
	fb.index_bytes = 4 if block_ids.size() > BITS_IN_TWO_BYTES else 2
	var all := PackedByteArray()
	for bytes in index_frames:
		all.append_array(bytes)
	fb.index_raw_size = all.size()
	fb.index_data = all.compress(FileAccess.COMPRESSION_ZSTD)
	return fb
	
func encode_and_save() -> void:
	files = list_frames(FRAMES_DIR)
	for path in files:
		add_frame(load_frame_global(path))
	build_index_frames()
	var fb := build_flipbook()
	print("palette %d B, indices %d B (raw %d B)" % [
		fb.palette_data.size(), fb.index_data.size(), fb.index_raw_size
	])
	var err := ResourceSaver.save(fb, FLIPBOOK_PATH)
	if err != OK:
		push_error("failed saving: %s" % error_string(err))
