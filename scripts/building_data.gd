class_name BuildingData
extends Node3D

enum BuildingType {
	UNASSIGNED, HOUSING, APARTMENT, DOWNTOWN, INDUSTRIAL, OFFICE
}

@export_group("Settings")
@export_subgroup("Scene Settings")
@export var size := Vector2i(1, 1) # 3x2 would be Vector2i(3, 2)
@export var building_type: BuildingType

@export_group("Level of Detail")
@export_subgroup("LOD Node Containers")
@export var lod0_node: Node3D  # High-detail mesh
@export var lod1_node: Node3D  # Medium-detail mesh
@export var lod2_node: Node3D  # Low-detail mesh

@export_group("Generator Settings")
@export var is_landmark := false
@export var global_limit := -1
@export var local_limit := -1

var grid_position: Vector2i
var current_lod_level: int = -1

func _ready():
	assign_scene()
	set_lod_level(2)

func assign_scene():
	match size:
		Vector2i(1,1): # Small Buildings
			match building_type:
				BuildingType.HOUSING:
					var number = count_files_in_dir("res://assets/3d_models/city_buildings/housing/")
					var random = randi_range(1, number)
					var glb_path: String = "res://assets/3d_models/city_buildings/housing/building-" + str(random) + ".glb"
					process_glb(glb_path)
				BuildingType.APARTMENT:
					var number = count_files_in_dir("res://assets/3d_models/city_buildings/apartment/")
					var random = randi_range(1, number)
					var glb_path: String = "res://assets/3d_models/city_buildings/apartment/building-" + str(random) + ".glb"
					process_glb(glb_path)
				BuildingType.OFFICE:
					var number = count_files_in_dir("res://assets/3d_models/city_buildings/office/")
					var random = randi_range(1, number)
					var glb_path: String = "res://assets/3d_models/city_buildings/office/building-" + str(random) + ".glb"
					process_glb(glb_path)
				BuildingType.DOWNTOWN:
					var number = count_files_in_dir("res://assets/3d_models/city_buildings/downtown/")
					var random = randi_range(1, number)
					var glb_path: String = "res://assets/3d_models/city_buildings/downtown/building-" + str(random) + ".glb"
					process_glb(glb_path)
				_: pass
		Vector2i(2,1): # 2x1 Buildings
			match building_type:
				BuildingType.OFFICE:
					var number = count_files_in_dir("res://assets/3d_models/city_buildings/office/2x1/")
					var random = randi_range(1, number)
					var glb_path: String = "res://assets/3d_models/city_buildings/office/2x1/building-" + str(random) + ".glb"
					process_glb(glb_path)
				_: pass

func set_lod_level(level: int):
	if level == current_lod_level: # Return if same level
		return
	
	# Hide all LOD nodes first to ensure clean switch.
	if lod0_node: lod0_node.hide()
	if lod1_node: lod1_node.hide()
	if lod2_node: lod2_node.hide()
	
	match level:
		0: # High detail
			if lod0_node: lod0_node.show()
		1: # Medium detail
			if lod1_node: lod1_node.show()
		2: # Low detail
			if lod2_node: lod2_node.show()
	
	current_lod_level = level

func process_glb(glb_path: String):
	var glb_scene = load(glb_path)
	if not glb_scene:
		push_error("Failed to load GLB file at path: ", glb_path)
		return
	
	var container = glb_scene.instantiate()
	add_child(container)
	container.owner = self
	container.name = "LOD0"
	lod0_node = container
	container.scale = Vector3.ONE * 10
	container.position.y = 0.74
	
	var mesh_instance = container.get_child(0)
	mesh_instance.create_trimesh_collision()
	var collision_body = mesh_instance.get_child(0).get_child(0)
	collision_body.reparent(self)
	mesh_instance.get_child(0).queue_free()
	
	collision_body.owner = self
	collision_body.name = "BuildingCollision"
	collision_body.add_to_group("collision_for_chunking")
	

func count_files_in_dir(dir_path) -> int:
	var file_count = 0
	
	var dir = DirAccess.open(dir_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				if not file_name.ends_with(".import"):
					file_count += 1
			file_name = dir.get_next()
	else:
		push_error("Failed to access directory path: ", dir_path)
		return 0
	
	return file_count

func get_building_type() -> String:
	match building_type:
		BuildingType.HOUSING: return "Housing"
		BuildingType.UNASSIGNED: return "Unassigned"
		BuildingType.APARTMENT: return "Apartment"
		BuildingType.DOWNTOWN: return "Downtown"
		BuildingType.INDUSTRIAL: return "Industrial"
		_: return "NULL"
