@tool
extends RefCounted

const PER_ROW := 256
const BITS_IN_TWO_BYTES = 65536

var frame_size := Vector2i.ZERO
var grid := Vector2i.ZERO
var block_ids := {}
var frame_digests := {}
var unique_frames: Array[PackedInt32Array] = []
var frame_map := PackedInt32Array()
var index_frames: Array[PackedByteArray] = []
var index_format := Image.FORMAT_RG8

static func list_frames(dir: String) -> PackedStringArray:
	var abs_dir := ProjectSettings.globalize_path(dir)
	var names := Array(DirAccess.get_files_at(abs_dir)).filter(
		# TODO: check for other image formats too
		func(n: String) -> bool: return n.get_extension().to_lower() == "png"
	)
	# natural compare puts 'frame10' after 'frame2'
	# my examples use proper naming, but this comparison is too easy to use to skip here
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var paths := PackedStringArray()
	for n: String in names:
		paths.append(abs_dir.path_join(n))
	return paths

func build_flipbook(fps: float, loop: bool) -> HermitFlipbook:
	var fb := HermitFlipbook.new()
	fb.fps = fps
	fb.loop = loop
	fb.frame_size = frame_size
	fb.grid_size = grid
	fb.frame_map = frame_map
	fb.palette_data = build_palette().save_webp_to_buffer(false)
	fb.index_bytes = 4 if block_ids.size() > BITS_IN_TWO_BYTES else 2
	var all := PackedByteArray()
	for bytes in index_frames:
		all.append_array(bytes)
	fb.index_raw_size = all.size()
	fb.index_data = all.compress(FileAccess.COMPRESSION_ZSTD)
	return fb

func load_frame(path: String) -> Image:
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
	
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	var digest := ctx.finish()
	var known_frame: int = frame_digests.get(digest, -1)
	if known_frame >= 0:
		frame_map.append(known_frame)
		return
	
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
	
	var unique_frames_size := unique_frames.size()
	frame_digests[digest] = unique_frames_size
	frame_map.append(unique_frames_size)
	unique_frames.append(ids)

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
	for ids in unique_frames:
		var img := Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RGBA8, ids.to_byte_array())
		img.convert(index_format)
		index_frames.append(img.get_data())
