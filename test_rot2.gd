extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/Player.tscn")
	var player = packed.instantiate()
	get_root().add_child(player)
	
	var ev = InputEventMouseMotion.new()
	ev.relative = Vector2(50, 20)
	
	# Test directly what lines 116-121 do
	player.rotate_y(-ev.relative.x * player.mouse_sensitivity)
	player.head.rotate_x(-ev.relative.y * player.mouse_sensitivity)
	print("Player rot: ", player.rotation)
	print("Head rot: ", player.head.rotation)
	quit()
