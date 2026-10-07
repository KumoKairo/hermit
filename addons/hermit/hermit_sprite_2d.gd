@tool
class_name HermitSprite2D
extends Sprite2D

signal finished

const DECODE_SHADER := preload("res://addons/hermit/hermit_decode.gdshader")
const HIDDEN_PROPERTIES := ["texture", "hframes", "vframes", "frame", "frame_coords"]

@export var flipbook: HermitFlipbook:
	set(value):
		flipbook = value
		_setup()

@export var flipbook_frame := 0:
	set(value):
		flipbook_frame = value
		_show_frame()

@export var playing := true
@export var speed_scale := 1.0

var _decoder: SubViewport
var _material: ShaderMaterial
var _index_img: Image
var _index_tex: ImageTexture
var _shown_unique := -1
var _elapsed := 0.0

func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = DECODE_SHADER
	var display := ColorRect.new()
	display.material = _material
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decoder = SubViewport.new()
	_decoder.disable_3d = true
	_decoder.transparent_bg = true
	_decoder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_decoder.add_child(display)
	add_child(_decoder, false, INTERNAL_MODE_FRONT)
	texture = _decoder.get_texture()

func _ready() -> void:
	texture = _decoder.get_texture()
	
func _validate_property(property: Dictionary) -> void:
	if property.name in HIDDEN_PROPERTIES:
		property.usage = PROPERTY_USAGE_NONE
		
func _process(delta: float) -> void:
	# TODO check speed_scale here too maybe
	if flipbook == null or not playing or Engine.is_editor_hint() or flipbook.fps <= 0.0:
		return
	_elapsed += delta * speed_scale
	var step := 1.0 / flipbook.fps
	if _elapsed < step:
		return
	# frame catch-up if the game froze and we have to skip more than one frame of the animation
	var advance := int(_elapsed / step)
	_elapsed -= advance * step
	var count := flipbook.get_frame_count()
	var next := flipbook_frame + advance
	if flipbook.loop:
		flipbook_frame = posmod(next, count)
	elif next >= count - 1:
		flipbook_frame = count -1
		playing = false
		finished.emit()
	else:
		flipbook_frame = next
		
func _setup() -> void:
	_shown_unique = -1
	_index_img = null
	_index_tex = null
	if flipbook == null:
		return
	flipbook.prepare()
	_decoder.size = flipbook.frame_size
	_material.set_shader_parameter("palette", flipbook.get_palette_texture())
	_material.set_shader_parameter("frame_size", flipbook.frame_size)
	_show_frame()
	
func _show_frame() -> void:
	if flipbook == null or flipbook.get_frame_count() == 0:
		return
	var f := clampi(flipbook_frame, 0, flipbook.get_frame_count() - 1)
	var unique := flipbook.get_unique_frame(f)
	if unique == _shown_unique:
		return
	_shown_unique = unique
	var g := flipbook.grid_size
	var bytes := flipbook.get_index_bytes(unique)
	if _index_tex == null:
		_index_img = Image.create_from_data(g.x, g.y, false, flipbook.get_index_format(), bytes)
		_index_tex = ImageTexture.create_from_image(_index_img)
		_material.set_shader_parameter("indices", _index_tex)
	else:
		_index_img.set_data(g.x, g.y, false, flipbook.get_index_format(), bytes)
		_index_tex.update(_index_img)
	_decoder.render_target_update_mode = SubViewport.UPDATE_ONCE
	
