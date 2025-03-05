class_name MapLoader
extends Node

signal loading_progress(progress_percent: float)

var _items: Dictionary[int, ItemDef]
var _itemchilds: Array[TDFX]
var _placements: Array[ItemPlacement]
var _collisions: Array[ColFile]
var _parsed := false

func _ready() -> void:
	pass

func _read_ide_line(section: String, tokens: Array[String]):
	var item := ItemDef.new()
	var id := tokens[0].to_int()
	match section:
		"objs":
			item.model_name = tokens[1]
			item.txd_name = tokens[2]
			
			# Parse LoD information
			var num_lods = tokens[3].to_int()
			item.num_lods = num_lods
			
			# Set render distance for the base model
			item.render_distance = tokens[4].to_float()
			
			# Parse LoD distances if available
			for i in range(num_lods):
				if 4 + i < tokens.size() - 1:  # Avoid reading flags as LoD distance
					var lod_distance = tokens[4 + i].to_float()
					item.lod_distances.append(lod_distance)
			
			# Check if this is a big building (based on research notes)
			if item.lod_distances.size() > 0 and item.lod_distances[0] > 300.0 and num_lods < 3:
				item.is_big_building = true
				# Note: related model association will be done after all models are loaded
			
			item.flags = tokens[tokens.size() - 1].to_int()
			_items[id] = item
		"tobj":
			# TODO: Timed objects
			item.model_name = tokens[1]
			item.txd_name = tokens[2]
			
			# Parse LoD information for timed objects too
			if tokens.size() > 4:
				var num_lods = tokens[3].to_int()
				item.num_lods = num_lods
				
				# Set render distance for the base model
				item.render_distance = tokens[4].to_float()
				
				# Parse LoD distances if available
				for i in range(num_lods):
					if 4 + i < tokens.size() - 1:  # Avoid reading flags as LoD distance
						var lod_distance = tokens[4 + i].to_float()
						item.lod_distances.append(lod_distance)
			
			_items[id] = item
		"2dfx":
			var parent := tokens[0].to_int()
			# Convert GTA to Godot coordinate system
			var position := Vector3(
				tokens[1].to_float(),
				tokens[3].to_float(),
				-tokens[2].to_float() )
			var color := Color(
				tokens[4].to_float() / 255,
				tokens[5].to_float() / 255,
				tokens[6].to_float() / 255 )
			match tokens[8].to_int():
				0:
					var lightdef := TDFXLight.new()
					lightdef.parent = parent
					lightdef.position = position
					lightdef.color = color
					lightdef.render_distance = tokens[11].to_float()
					lightdef.range = tokens[12].to_float()
					lightdef.shadow_intensity = tokens[15].to_int()
					_itemchilds.append(lightdef)
				var type:
					push_warning("implement 2DFX type %d" % type)

func _read_ipl_line(section: String, tokens: Array[String]):
	match section:
		"inst":
			var placement := ItemPlacement.new()
			placement.id = tokens[0].to_int()
			placement.model_name = tokens[1].to_lower()
			# Convert GTA to Godot coordinate system
			placement.position = Vector3(
				tokens[2].to_float(),
				tokens[4].to_float(),
				-tokens[3].to_float(), )
			# Scale conversion follows the same pattern
			placement.scale = Vector3(
				tokens[5].to_float(),
				tokens[7].to_float(),
				tokens[6].to_float(), )
			# Quaternion conversion requires negating components
			placement.rotation = Quaternion(
				-tokens[8].to_float(),
				-tokens[10].to_float(),
				-tokens[9].to_float(),
				tokens[11].to_float(), )
			_placements.append(placement)

func _read_map_data(path: String, line_handler: Callable) -> void:
	var file := AssetLoader.open(path)
	assert(file != null, "%d" % FileAccess.get_open_error() )
	var section: String
	while not file.eof_reached():
		var line := file.get_line()
		if line.length() == 0 or line.begins_with("#"):
			continue
		var tokens := line.replace(" ", "").split(",", false)
		if tokens.size() == 1:
			section = tokens[0]
		else:
			line_handler.call(section, tokens)

func _find_related_models() -> void:
	# Associate big buildings with their related low-detail models
	# Based on the research notes, big buildings follow specific naming patterns
	# For example, "LODxxx" is matched with "HDRxxx"
	
	var lod_models := {}
	var hd_models := {}
	
	# First, collect all potential LOD and HD models by naming convention
	for id in _items:
		var item := _items[id] as ItemDef
		var model_name := item.model_name.to_lower()
		
		if model_name.begins_with("lod"):
			lod_models[model_name.substr(3)] = id
		elif model_name.begins_with("hdr"):
			hd_models[model_name.substr(3)] = id
	
	# Now associate the related models
	for suffix in lod_models:
		if suffix in hd_models:
			var lod_id = lod_models[suffix]
			var hd_id = hd_models[suffix]
			
			# Associate the HD model with its LOD model
			if _items[hd_id].is_big_building:
				_items[hd_id].related_model = _items[lod_id]
			
			# Also check for other naming patterns if needed
			# (Add more patterns based on GTA3 specific conventions)

func parse_map_data() -> void:
	if _parsed:
		return
		
	var file := FileAccess.open(GameManager.gta_path + "data/gta3.dat", FileAccess.READ)
	assert(file != null, "%d" % FileAccess.get_open_error())

	print("Loading map data...")
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("#"):
			var tokens := line.split(" ", false)
			if tokens.size() > 0:
				match tokens[0]:
					"IDE":
						_read_map_data(tokens[1], _read_ide_line)
					"COLFILE":
						var colfile := AssetLoader.open(GameManager.gta_path + tokens[2])
						
						while colfile.get_position() < colfile.get_length():
							_collisions.append(ColFile.new(colfile))
					"IPL":
						_read_map_data(tokens[1], _read_ipl_line)
					"CDIMAGE":
						AssetLoader.load_cd_image(tokens[1])
					_:
						push_warning("implement %s" % tokens[0])
	for child in _itemchilds:
		_items[child.parent].childs.append(child)
	for colfile in _collisions:
		if colfile.model_id in _items:
			_items[colfile.model_id].colfile = colfile
		else:
			for k in _items:
				var item := _items[k] as ItemDef
				if item.model_name.matchn(colfile.model_name):
					_items[k].colfile = colfile
	
	# Find and associate related models for big buildings
	_find_related_models()
	
	_parsed = true

func load_map() -> Node3D:
	# Make sure map data is parsed
	parse_map_data()
	
	var map := Node3D.new()
	
	var start_t := Time.get_ticks_msec()
	var target = _placements.size()
	var count := 0
	
	print("Loading map...")
	for ipl in _placements:
		map.add_child(spawn_placement(ipl))
		count += 1
		
		# No await statement - calculate and emit progress, but don't yield
		var progress = float(count) / float(target)
		call_deferred("emit_signal", "loading_progress", progress)
	
	print("Map load completed in %f seconds" % ((Time.get_ticks_msec() - start_t) / 1000.0))
	return map

func spawn_placement(ipl: ItemPlacement) -> Node3D:
	return spawn(ipl.id, ipl.model_name, ipl.position, ipl.scale, ipl.rotation)

func spawn(id: int, model_name: String, position: Vector3, scale: Vector3, rotation: Quaternion) -> Node3D:
	var item := _items[id] as ItemDef
	if item.flags & 0x40:
		return Node3D.new()
		
	# Create a Node3D container for big buildings with related models
	var container: Node3D
	
	if item.is_big_building and item.related_model != null:
		# For big buildings, create a container node
		container = Node3D.new()
		container.name = "BigBuilding_" + str(id)
		container.position = position
		container.scale = scale
		container.quaternion = rotation
		
		# Create the high-detail model
		var high_detail := StreamedMesh.new(item)
		high_detail.name = "HighDetail"
		container.add_child(high_detail)
		
		# Create the low-detail model using the related model definition
		if item.related_model != null:
			var low_detail := StreamedMesh.new(item.related_model)
			low_detail.name = "LowDetail"
			container.add_child(low_detail)
			
			# Add a script to handle switching between high and low detail
			# (The StreamedMesh already handles this via _select_lod_level)
	else:
		# For regular models
		container = StreamedMesh.new(item)
		container.position = position
		container.scale = scale
		container.quaternion = rotation
		
		# Add effects and child objects
		for child in item.childs:
			if child is TDFXLight:
				var light := OmniLight3D.new()
				light.position = child.position
				light.light_color = child.color
				light.distance_fade_enabled = true
				light.distance_fade_begin = child.render_distance
				light.omni_range = child.range
				light.light_energy = float(child.shadow_intensity) / 20.0
				light.shadow_enabled = true
				container.add_child(light)
		
		# Add collision
		var sb := StaticBody3D.new()
		if item.colfile != null:
			for collision in item.colfile.collisions:
				var colshape := CollisionShape3D.new()
				if collision is ColFile.TBox:
					var aabb := AABB()
					# Get min and max positions from collision box
					var min_pos := collision.min as Vector3
					var max_pos := collision.max as Vector3
					
					# Ensure AABB has positive size by sorting min/max for each axis
					aabb.position = Vector3(
						min(min_pos.x, max_pos.x),
						min(min_pos.y, max_pos.y),
						min(min_pos.z, max_pos.z)
					)
					aabb.end = Vector3(
						max(min_pos.x, max_pos.x),
						max(min_pos.y, max_pos.y),
						max(min_pos.z, max_pos.z)
					)
					
					# Only create the shape if size is valid
					if aabb.size.x > 0 and aabb.size.y > 0 and aabb.size.z > 0:
						var shape := BoxShape3D.new()
						shape.size = aabb.size
						colshape.shape = shape
						colshape.position = aabb.get_center()
						sb.add_child(colshape)
				else:
					sb.add_child(colshape)
			if item.colfile.vertices.size() > 0:
				var colshape := CollisionShape3D.new()
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(item.colfile.vertices)
				colshape.shape = shape
				sb.add_child(colshape)
			container.add_child(sb)
			
	return container
