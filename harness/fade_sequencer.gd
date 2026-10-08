extends Node

@export var delay_start_by := 1.0
@export var hold_by := 3.0

@onready var sprite: HermitSprite2D = get_parent()

func _ready() -> void:
	sprite.pause()
	await get_tree().create_timer(delay_start_by).timeout
	sprite.play_backwards()
	await sprite.animation_finished
	sprite.visible = false
	print("animation finished")
	await get_tree().create_timer(hold_by).timeout
	sprite.visible = true
	sprite.play()
