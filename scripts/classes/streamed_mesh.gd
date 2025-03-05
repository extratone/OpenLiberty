class_name StreamedMesh
extends MeshInstance3D

# LoD System Constants
const DRAW_DISTANCE_FACTOR = 1.5
const MAGIC_LOD_DISTANCE = 330.0
const VEHICLE_LOD_DISTANCE = 70.0
const VEHICLE_DRAW_DISTANCE = 280.0

var _idef: ItemDef
var _thread := Thread.new()
var _mesh_buf: Array[Mesh] = [] # Array to store different LoD meshes
var _current_lod_level: int = -1 # Current LoD level being displayed
var _lod_nodes: Array[MeshInstance3D] = [] # Child nodes for LoD models

func _init(idef: ItemDef):
	_idef = idef
	
	# Create child nodes for each LoD level
	if _idef.num_lods > 0:
		for i in range(_idef.num_lods):
			var lod_node := MeshInstance3D.new()
			lod_node.name = "LOD_" + str(i)
			lod_node.visible = false
			add_child(lod_node)
			_lod_nodes.append(lod_node)
			_mesh_buf.append(null)
	else:
		# Default mesh buffer for base model
		_mesh_buf.append(null)

func _exit_tree():
	if _thread.is_alive():
		_thread.wait_to_finish()

func _process(delta: float) -> void:
	if get_viewport().get_camera_3d() == null:
		return
		
	# Calculate distance to camera
	var camera_pos = get_viewport().get_camera_3d().global_position
	var raw_distance = camera_pos.distance_to(global_position)
	var distance = raw_distance / DRAW_DISTANCE_FACTOR
	
	# Select appropriate LoD level based on distance
	var selected_lod = _select_lod_level(distance)
	
	# If LoD level changed or mesh not loaded, load the appropriate mesh
	if selected_lod != _current_lod_level or (selected_lod >= 0 and _get_active_mesh() == null):
		_current_lod_level = selected_lod
		
		# Hide all LoD nodes first
		for node in _lod_nodes:
			node.visible = false
		mesh = null
		
		# If object is too far, don't show anything
		if selected_lod < 0:
			return
			
		# If we need to load a mesh but haven't yet
		if _thread.is_started() == false and _mesh_buf[selected_lod] == null:
			_thread.start(Callable(_load_mesh).bind(selected_lod))
			while _thread.is_alive():
				await get_tree().process_frame
			_thread.wait_to_finish()
		
		# Show the appropriate mesh
		if selected_lod == 0:
			# Base model goes on the main instance
			mesh = _mesh_buf[0]
		elif selected_lod < _lod_nodes.size() + 1:
			# LoD models go on child nodes
			_lod_nodes[selected_lod - 1].mesh = _mesh_buf[selected_lod]
			_lod_nodes[selected_lod - 1].visible = true

func _select_lod_level(distance: float) -> int:
	# Special handling for big buildings
	if _idef.is_big_building:
		if distance < MAGIC_LOD_DISTANCE and _idef.related_model != null:
			return 0 # Show detailed model
		return -1 # Too far, don't show
	
	# Normal LoD selection
	if _idef.lod_distances.size() > 0:
		# Check against each LoD distance threshold
		for i in range(_idef.lod_distances.size()):
			if distance < _idef.lod_distances[i]:
				return i # Return the appropriate LoD level
		
		# Object is too far away, don't render
		return -1
	else:
		# No LoD information, use simple visibility range
		return 0 if distance < _idef.render_distance else -1

func _get_active_mesh() -> Mesh:
	if _current_lod_level == 0:
		return mesh
	elif _current_lod_level > 0 and _current_lod_level <= _lod_nodes.size():
		return _lod_nodes[_current_lod_level - 1].mesh
	return null

func _get_lod_model_name(lod_level: int) -> String:
	var base_name = _idef.model_name
	if lod_level == 0:
		return base_name
	else:
		return base_name + "_l" + str(lod_level)

func _load_mesh(lod_level: int) -> void:
	AssetLoader.mutex.lock()
	if _idef.flags & 0x40:
		AssetLoader.mutex.unlock()
		return
	
	# Get model name with appropriate LoD suffix
	var model_name = _get_lod_model_name(lod_level)
	
	# Try to open the asset file
	var access = AssetLoader.open_asset(model_name + ".dff")
	if access == null:
		# If the specific LoD model doesn't exist, fall back to the base model
		if lod_level > 0:
			access = AssetLoader.open_asset(_idef.model_name + ".dff")
		
		# If still no model, exit
		if access == null:
			AssetLoader.mutex.unlock()
			return
	
	# Load the mesh geometry
	var glist := RWClump.new(access).geometry_list
	for geometry in glist.geometries:
		_mesh_buf[lod_level] = geometry.mesh
		for surf_id in _mesh_buf[lod_level].get_surface_count():
			var material := _mesh_buf[lod_level].surface_get_material(surf_id) as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if _idef.flags & 0x08:
				material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if material.has_meta("texture_name"):
				var txd := RWTextureDict.new(AssetLoader.open_asset(_idef.txd_name + ".txd"))
				var texture_name = material.get_meta("texture_name")
				for raster in txd.textures:
					if texture_name.matchn(raster.name):
						material.albedo_texture = ImageTexture.create_from_image(raster.image)
						if raster.has_alpha:
							material.transparency = (
								BaseMaterial3D.TRANSPARENCY_ALPHA_HASH if _idef.flags & 0x04 and not _idef.flags & 0x08
								else BaseMaterial3D.TRANSPARENCY_ALPHA )
						break
			_mesh_buf[lod_level].surface_set_material(surf_id, material)
	AssetLoader.mutex.unlock()
