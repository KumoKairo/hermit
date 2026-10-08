extends Node

const VARIANTS: Dictionary[String, String] = {
	"empty": "res://harness/empty.tscn",
	"baseline_lossless": "res://harness/baseline_lossless.tscn",
	"baseline_compressed": "res://harness/baseline_compressed.tscn",
	"hermit": "res://harness/hermit.tscn",
	"hermit-compressed": "res://harness/hermit-compressed.tscn"
}
const RESULTS_PATH := "user://hermit_harness.jsonl"

@export var default_variant := "hermit"
@export var settle_seconds := 3.0
@export var sample_seconds := 5.0
@export var quit_when_done := false

var _variant := ""
var _load_msec := 0
var _time := 0.0
var _reported := false
var _peak_texture := 0
var _peak_video := 0
var _peak_static := 0
var _label: Label

func _ready() -> void:
	_variant = default_variant
	for key in VARIANTS:
		if OS.has_feature(key):
			_variant = key
	for arg in OS.get_cmdline_user_args():
		if VARIANTS.has(arg):
			_variant = arg
	
	var start := Time.get_ticks_msec()
	var packed: PackedScene = load(VARIANTS[_variant])
	add_child(packed.instantiate())
	_load_msec = Time.get_ticks_msec() - start
	
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 16)
	layer.add_child(_label)
	add_child(layer)
	
func _process(delta: float) -> void:
	_time += delta
	var texture_mem := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var video_mem := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var static_mem := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	if _time >= settle_seconds:
		_peak_texture = maxi(_peak_texture, texture_mem)
		_peak_video = maxi(_peak_video, video_mem)
		_peak_static = maxi(_peak_static, static_mem)
	_label.text = "%s\nVRAM textures %s\nVRAM total %s\nRAM %s" % [
		_variant, 
		String.humanize_size(texture_mem),
		String.humanize_size(video_mem),
		String.humanize_size(static_mem)
	]
	
	if not _reported and _time >= settle_seconds + sample_seconds:
		_reported = true
		_report()
		
func _report() -> void:
	var row := {
		"variant": _variant,
		"vram_texture_bytes": _peak_texture,
		"vram_total_bytes": _peak_video,
		"ram_static_bytes": _peak_static,
		"load_msec": _load_msec,
		"time": Time.get_datetime_dict_from_system()
	}
	var line := JSON.stringify(row)
	print(line)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(RESULTS_PATH) else FileAccess.WRITE
	var file := FileAccess.open(RESULTS_PATH, mode)
	file.seek_end()
	file.store_line(line)
	file.close()
	if quit_when_done:
		get_tree().quit()
