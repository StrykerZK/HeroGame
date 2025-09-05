class_name RoadData
extends Node3D

var road_info: Dictionary = {}
@onready var current_lod_level: int = -1
@onready var lod0_node: Node3D
@export var lod1_node: Node3D
@export var lod2_node: Node3D

# --- Scene Assignments ---
@onready var modules_node: Node3D = %Modules

# Minor Road Modules
@onready var road_filler = %RoadFiller
@onready var road_straight = %RoadStraight
@onready var road_corner = %RoadCorner
@onready var road_t_shape = %RoadTShape
@onready var road_intersection = %RoadIntersection
@onready var road_end = %RoadEnd

# Major Road Modules
@onready var major_road_t_shape_2_width = %MajorRoadTShape2Width
@onready var major_road_t_shape = %MajorRoadTShape
@onready var major_intersection_corner = %MajorIntersectionCorner
@onready var major_road_straight_2_width = %MajorRoadStraight2Width
@onready var major_road_edge = %MajorRoadEdge
@onready var major_road_middle = %MajorRoadMiddle
@onready var major_road_odd_center = %MajorRoadOddCenter
@onready var major_road_even_center = %MajorRoadEvenCenter

func _ready():	
	set_lod_level(2)

func generate_scene(data: Dictionary):
	# -- Data Keys -- 
	# GENERAL: grid_pos, is_major, connections
	# MAJOR KEYS: major_road_type, rotation, lane_index, traffic_flow, major_road_width, major_road_lane_type
	# MINOR KEYS: type, rotation
	
	# Unpack the data with default values for safety
	road_info["grid_position"] = data.get("grid_pos", Vector2i.ZERO)
	road_info["road_type"] = data.get("type", Enums.RoadType.UNKNOWN) # For Minor Roads
	road_info["scene_rotation"] = data.get("rotation", 0)
	road_info["connections"] = data.get("connections", [])
	road_info["is_major"] = data.get("is_major", false)
	
	# Major road specific data
	road_info["major_road_type"] = data.get("major_road_type", Enums.MajorRoadType.UNKNOWN)
	road_info["major_road_lane_type"] = data.get("major_road_lane_type", Enums.MajorRoadLaneType.MIDDLE)
	road_info["lane_index"] = data.get("lane_index", 0)
	road_info["major_road_width"] = data.get("major_road_width", 2)
	road_info["traffic_flow"] = data.get("traffic_flow", Vector2i.ZERO)
	
	
	# --- YOUR LOGIC GOES HERE ---
	# You now have all the information to choose the correct module.
	var road_node = road_filler
	
	if road_info.is_major: # Major Scene Assignment
		match road_info.major_road_type:
			Enums.MajorRoadType.T_JUNCTION:
				if road_info.major_road_width == 2: road_node = major_road_t_shape_2_width
				else: road_node = major_road_t_shape
			Enums.MajorRoadType.INTERSECTION_CORNER: road_node = major_intersection_corner
			Enums.MajorRoadType.INTERSECTION_FILLER, Enums.MajorRoadType.UNKNOWN: road_node = road_filler
			Enums.MajorRoadType.STRAIGHT: # Straight Road Modules
				if road_info.major_road_width == 2: road_node = major_road_straight_2_width
				else:
					match road_info.major_road_lane_type:
						Enums.MajorRoadLaneType.EDGE: road_node = major_road_edge
						Enums.MajorRoadLaneType.MIDDLE: road_node = major_road_middle
						Enums.MajorRoadLaneType.ODD_CENTER: road_node = major_road_odd_center
						Enums.MajorRoadLaneType.EVEN_CENTER: road_node = major_road_even_center
	else: # Minor Roads
		match road_info.road_type:
			Enums.RoadType.STRAIGHT: road_node = road_straight
			Enums.RoadType.CORNER: road_node = road_corner
			Enums.RoadType.T_JUNCTION: road_node = road_t_shape
			Enums.RoadType.INTERSECTION: road_node = road_intersection
			Enums.RoadType.END: road_node = road_end
	
	# Finalize
	self.rotation_degrees.y = road_info.scene_rotation
	_cleanup_modules(road_node)
	road_node.name = "LOD0"
	lod0_node = road_node
	
	# You can also store the connection data for later use by your AI systems
	# set_meta("pathfinding_connections", connections)

func extract_collision_shapes(instance) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	for shape_node in instance.find_children("*", "CollisionShape3D", true, false):
		if shape_node.is_in_group("road_collision"):
			shapes.append(shape_node)
	return shapes

func configure_for_junction(junction_node, has_traffic: bool):
	var stop_sign_mesh = lod0_node.get_child(0).find_child("StopSign", false)
	var traffic_light_mesh = lod0_node.get_child(0).find_child("TrafficLight", false)
	var crosswalk_mesh = lod0_node.get_child(0).find_child("Crosswalk", false)
	
	if has_traffic:
		if is_instance_valid(traffic_light_mesh): traffic_light_mesh.visible = true
	else:
		if is_instance_valid(stop_sign_mesh): stop_sign_mesh.visible = true
	
	if is_instance_valid(crosswalk_mesh): crosswalk_mesh.visible = true


func _cleanup_modules(chosen_module: Node3D):
	if not is_instance_valid(modules_node):
		push_warning("Missing 'Modules' Container")
		return
		
	if is_instance_valid(chosen_module) and chosen_module.get_parent() == modules_node:
		chosen_module.owner = null
		modules_node.remove_child(chosen_module)
		add_child(chosen_module)
	else:
		var module_name = chosen_module.name if is_instance_valid(chosen_module) else "null"
		push_warning("Chosen module '", module_name, "' is not a valid child of the 'Modules' container.")
	modules_node.queue_free()

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
