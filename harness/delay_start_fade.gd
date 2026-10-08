extends AnimatedSprite2D

@export var delay_start_by := 1.0
@export var hold_by := 3.0

func _ready() -> void:
	await get_tree().create_timer(delay_start_by).timeout
	play_backwards("fade")
	await animation_finished
	visible = false
	await get_tree().create_timer(hold_by).timeout
	visible = true
	play("fade")
	await animation_finished
