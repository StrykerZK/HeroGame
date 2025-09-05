class_name RoadData
extends Node3D

var road_info: Dictionary = {}
var lod0_node: Node3D
var current_lod_level: int = -1

@export var lod1_node: Node3D
@export var lod2_node: Node3D

func _ready():
	# This function is kept for cases where the scene might be used
	# outside of the city generator, but our main setup logic is now
	# entirely within generate_scene() to ensure thread safety.
	pass

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
	
	# --- Get Node References Manually ---
	# We fetch nodes by name now instead of using @onready. This is thread-safe.
	var modules_node: Node3D = get_node_or_null("%Modules")
	if not is_instance_valid(modules_node):
		push_error("Road scene instance is missing its '%Modules' child node.")
		return

	# --- Module Selection Logic ---
	var road_node: Node3D
	var node_name_to_find: String

	if road_info.is_major: # Major Scene Assignment
		match road_info.major_road_type:
			Enums.MajorRoadType.T_JUNCTION:
				node_name_to_find = "MajorRoadTShape2Width" if road_info.major_road_width == 2 else "MajorRoadTShape"
			Enums.MajorRoadType.INTERSECTION_CORNER:
				node_name_to_find = "MajorIntersectionCorner"
			Enums.MajorRoadType.STRAIGHT:
				if road_info.major_road_width == 2:
					node_name_to_find = "MajorRoadStraight2Width"
				else:
					match road_info.major_road_lane_type:
						Enums.MajorRoadLaneType.EDGE: node_name_to_find = "MajorRoadEdge"
						Enums.MajorRoadLaneType.MIDDLE: node_name_to_find = "MajorRoadMiddle"
						Enums.MajorRoadLaneType.ODD_CENTER: node_name_to_find = "MajorRoadOddCenter"
						Enums.MajorRoadLaneType.EVEN_CENTER: node_name_to_find = "MajorRoadEvenCenter"
			_:
				node_name_to_find = "RoadFiller"
	else: # Minor Roads
		match road_info.road_type:
			Enums.RoadType.STRAIGHT: node_name_to_find = "RoadStraight"
			Enums.RoadType.CORNER: node_name_to_find = "RoadCorner"
			Enums.RoadType.T_JUNCTION: node_name_to_find = "RoadTShape"
			Enums.RoadType.INTERSECTION: node_name_to_find = "RoadIntersection"
			Enums.RoadType.END: node_name_to_find = "RoadEnd"
			_:
				node_name_to_find = "RoadFiller"

	if node_name_to_find:
		road_node = modules_node.get_node_or_null(node_name_to_find)

	# --- Crucial Null Check ---
	# This prevents the crash by ensuring road_node is valid.
	if not is_instance_valid(road_node):
		push_error("Could not find a road module named '", node_name_to_find, "'. Using fallback.")
		road_node = modules_node.get_node_or_null("RoadFiller")
		if not is_instance_valid(road_node):
			push_error("CRITICAL: Fallback 'RoadFiller' module also missing. Aborting generation for this piece.")
			modules_node.queue_free()
			return

	# --- Finalize Scene Setup ---
	self.rotation_degrees.y = road_info.scene_rotation
	_cleanup_modules(road_node, modules_node)
	road_node.name = "LOD0" # This line is now safe
	road_node.show()
	lod0_node = road_node
	
	# Set the initial LOD state now that setup is complete
	set_lod_level(2)

func extract_collision_shapes(instance) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	for shape_node in instance.find_children("*", "CollisionShape3D", true, false):
		if shape_node.is_in_group("road_collision"):
			shapes.append(shape_node)
	return shapes

func configure_for_junction(junction_node, decor_type: String, forced_direction: Vector2i):
	var stop_sign_node: Node3D = get_node_or_null("%StopSign")
	var small_traffic_node: Node3D = get_node_or_null("%SmallTraffic")
	var large_traffic_node: Node3D = get_node_or_null("%LargeTraffic")
	var crosswalk_model = lod0_node.find_child("CrosswalkModel", false)
	var crosswalk_flipped_model = lod0_node.find_child("CrosswalkModelFlipped", false)
	var main_model = lod0_node.find_child("MainModel", false)
	
	var is_flipped = false
	
	match decor_type:
		"Stop":
			stop_sign_node.visible = true
		"SmallTraffic":
			small_traffic_node.visible = true
		"LargeTraffic":
			large_traffic_node.visible = true
	
	match forced_direction:
		Vector2i.UP:
			self.rotation_degrees.y = 0
			if road_info["traffic_flow"] == Vector2i.UP: is_flipped = true
		Vector2i.DOWN:
			self.rotation_degrees.y = 180
			if road_info["traffic_flow"] == Vector2i.DOWN: is_flipped = true
		Vector2i.LEFT:
			self.rotation_degrees.y = 90
			if road_info["traffic_flow"] == Vector2i.LEFT: is_flipped = true
		Vector2i.RIGHT:
			self.rotation_degrees.y = 270
			if road_info["traffic_flow"] == Vector2i.RIGHT: is_flipped = true
	
	if is_instance_valid(crosswalk_model):
		main_model.visible = false
		if is_flipped:
			crosswalk_flipped_model.visible = true
		else:
			crosswalk_model.visible = true


func _cleanup_modules(chosen_module: Node3D, modules_container: Node3D):
	if not is_instance_valid(modules_container):
		push_warning("Missing 'Modules' Container reference in _cleanup_modules.")
		return
		
	if is_instance_valid(chosen_module) and chosen_module.get_parent() == modules_container:
		chosen_module.owner = null
		modules_container.remove_child(chosen_module)
		add_child(chosen_module)
	else:
		var module_name = chosen_module.name if is_instance_valid(chosen_module) else "null"
		push_warning("Chosen module '", module_name, "' is not a valid child of the 'Modules' container.")

	modules_container.queue_free()

func set_lod_level(level: int):
	if level == current_lod_level: # Return if same level
		return
	
	# Hide all LOD nodes first to ensure clean switch.
	if is_instance_valid(lod0_node): lod0_node.hide()
	if is_instance_valid(lod1_node): lod1_node.hide()
	if is_instance_valid(lod2_node): lod2_node.hide()
	
	match level:
		0: # High detail
			if is_instance_valid(lod0_node): lod0_node.show()
		1: # Medium detail
			if is_instance_valid(lod1_node): lod1_node.show()
		2: # Low detail
			if is_instance_valid(lod2_node): lod2_node.show()
	
	current_lod_level = level
