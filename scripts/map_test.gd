extends Node

var suzanne := preload("res://prefabs/suzanne.tscn")
var map_loader: MapLoader

func _ready() -> void:
	map_loader = MapLoader.new()
	add_child(map_loader)
	
	# Connect signals for progress updates
	map_loader.loading_progress.connect(_on_loading_progress)
	map_loader.loading_completed.connect(_on_loading_completed)
	
	# Start loading the map
	await map_loader.load_map()

func _on_loading_progress(progress: float) -> void:
	print("Loading: %d%%" % int(progress * 100))
	
func _on_loading_completed(world_node: Node3D) -> void:
	add_child(world_node)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.physical_keycode == KEY_SPACE and event.pressed:
			var node := suzanne.instantiate() as RigidBody3D
			add_child(node)
			node.global_position = get_viewport().get_camera_3d().global_position
