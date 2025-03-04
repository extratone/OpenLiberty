extends Node

@onready var sun = $sun
@onready var moon = $moon
@onready var sky = $WorldEnvironment
var car := preload("res://scenes/car.tscn")
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
	sky.environment = load("res://scenes/world/day.tres")
	moon.visible = not moon.visible

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("spawn"):
			var car_node := car.instantiate()
			add_child(car_node)
			car_node.global_position = get_viewport().get_camera_3d().global_position

func _input(event):
	if Input.is_action_just_pressed("full_screen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	#else:
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if Input.is_action_just_pressed("night_toggle"):
		sky.environment = load("res://scenes/world/night.tres")
		sun.visible = not sun.visible
		moon.visible = not moon.visible
		#if sun.visible = true
			#sky.environment = load("res://scenes/world/day.tres")
