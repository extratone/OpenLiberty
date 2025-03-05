extends Node

var suzanne := preload("res://prefabs/suzanne.tscn")
var map_loader: MapLoader

func _ready() -> void:
	map_loader = MapLoader.new()
	add_child(map_loader)
	
	# Connect signals for progress updates
	map_loader.loading_progress.connect(_on_loading_progress)
	
	# TODO: Implement a proper loading screen before enabling threaded loading
	# For now, load the map directly
	var map := map_loader.load_map()
	add_child(map)

func _on_loading_progress(progress: float) -> void:
	print("Loading: %d%%" % int(progress * 100))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.physical_keycode == KEY_SPACE and event.pressed:
			var node := suzanne.instantiate() as RigidBody3D
			add_child(node)
			node.global_position = get_viewport().get_camera_3d().global_position
