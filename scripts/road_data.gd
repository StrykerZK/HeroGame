class_name RoadData
extends Node3D

@onready var grid_position: Vector2i = Vector2i.ZERO
@onready var traffic_flow: Vector2i = Vector2i.ZERO
@onready var current_lod_level: int = -1
@onready var lod0_node: Node3D
@export var lod1_node: Node3D
@export var lod2_node: Node3D

func _ready():	
	set_lod_level(2)

func generate_scene(data: Dictionary, target_collision_body: StaticBody3D):
	# -- Data Keys -- 
	# GENERAL: grid_pos, is_major, connections
	# MAJOR KEYS: major_road_type, rotation, lane_index, traffic_flow, major_road_width, major_road_lane_type
	# MINOR KEYS: type, rotation
	
	# Unpack the data with default values for safety
	grid_position = data.get("grid_pos", Vector2i.ZERO)
	var road_type = data.get("type", Enums.RoadType.UNKNOWN) # For Minor Roads
	var scene_rotation = data.get("rotation", 0)
	var connections = data.get("connections", [])
	var is_major = data.get("is_major", false)
	
	# Major road specific data
	var major_road_type = data.get("major_road_type", Enums.MajorRoadType.UNKNOWN)
	var major_road_lane_type = data.get("major_road_lane_type", Enums.MajorRoadLaneType.MIDDLE)
	var lane_index = data.get("lane_index", 0)
	var road_width = data.get("major_road_width", 2)
	traffic_flow = data.get("traffic_flow", Vector2i.ZERO)
	
	
	# --- YOUR LOGIC GOES HERE ---
	# You now have all the information to choose the correct module.
	var road_node = $RoadFiller #: Node3D = null
	
	
	
	# Apply the visual rotation
	self.rotation_degrees.y = scene_rotation
	lod0_node = road_node
	extract_collision_shapes(lod0_node, target_collision_body)
	
	# You can also store the connection data for later use by your AI systems
	# set_meta("pathfinding_connections", connections)
	
	print("Generated a road piece with data: ", data)

func extract_collision_shapes(instance, target_collision_body):
	for shape_node in instance.find_children("*", "CollisionShape3D", true, false):
		if shape_node.is_in_group("road_collision"):
			shape_node.set_owner(null)
			shape_node.reparent(target_collision_body)

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
