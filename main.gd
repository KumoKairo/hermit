extends Node2D

@export var flipbook: HermitFlipbook

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
	if flipbook == null:
		push_error("assign a flipbook")
		return
	flipbook.prepare()
	
	var g := flipbook.grid_size
	index_img = Image.create_from_data(g.x, g.y, false, flipbook.get_index_format(), flipbook.get_index_bytes(0))
	index_tex = ImageTexture.create_from_image(index_img)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://addons/hermit/hermit_decode.gdshader")
	mat.set_shader_parameter("palette", flipbook.get_palette_texture())
	mat.set_shader_parameter("indices", index_tex)
	mat.set_shader_parameter("frame_size", flipbook.frame_size)
	display.material = mat
	display.size = Vector2(flipbook.frame_size)
	
	decoder.size = flipbook.frame_size
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
