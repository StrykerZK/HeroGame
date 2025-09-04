class_name RoadData
extends Node3D

enum RoadType {
	UNASSIGNED,
	MAJOR_STRAIGHT, MAJOR_INTERSECTION,
	MINOR_STRAIGHT, MINOR_INTERSECTION, MINOR_CORNER, MINOR_END
}

@onready var type: RoadType = RoadType.UNASSIGNED
@onready var size: Vector2i = Vector2i(1, 1)
@onready var grid_position: Vector2i = Vector2i.ZERO
@onready var direction: Vector2i = Vector2i.UP
@onready var current_lod_level: int = -1
@onready var lod0_node: Node3D
@onready var lod1_node: Node3D
@onready var lod2_node: Node3D
@onready var road_filler_scene: PackedScene = load("res://scenes/roads/road_filler.tscn")
@onready var major_intersection_corner_scene: PackedScene = load("res://scenes/roads/major_intersection_corner.tscn")

func _ready():	
	set_lod_level(2)

func generate_intersection(incoming_size: Vector2i):
	size = incoming_size
	type = RoadType.MAJOR_INTERSECTION
	
	var cells_to_occupy = size.x * size.x
	var corner_value = 0
	if size.x % 2 == 0:
		corner_value = 10 + (20 * ((size.x-2)/2))
	else:
		corner_value = 20 * ((size.x-1)/2)
	var top_left_corner = Vector3(corner_value, 0, corner_value)
	var top_right_corner = Vector3(-corner_value, 0, corner_value)
	var bottom_left_corner = Vector3(corner_value, 0, -corner_value)
	var bottom_right_corner = Vector3(-corner_value, 0, -corner_value)
	
	var current_pos = top_left_corner
	var row = 1; var column = 0
	
	while cells_to_occupy != 0:
		var instance
		match current_pos:
			top_left_corner:
				instance = major_intersection_corner_scene.instantiate()
				instance.position = current_pos
				instance.rotation.y = PI
			top_right_corner:
				instance = major_intersection_corner_scene.instantiate()
				instance.position = current_pos
				instance.rotation.y = PI/2
			bottom_left_corner:
				instance = major_intersection_corner_scene.instantiate()
				instance.position = current_pos
				instance.rotation.y = -PI/2
			bottom_right_corner:
				instance = major_intersection_corner_scene.instantiate()
				instance.position = current_pos
			_:
				instance = road_filler_scene.instantiate()
				instance.position = current_pos
		if is_instance_valid(instance):
			add_child(instance)
			extract_collision_shapes(instance)
		cells_to_occupy -= 1
		
		if column != size.x:
			if row != size.x:
				current_pos.x -= 20.0
				row += 1
			else:
				current_pos.x = top_left_corner.x
				current_pos.z -= 20.0
				row = 1
				column += 1

func generate_major_road():
	pass

func generate_minor_road():
	pass

func extract_collision_shapes(instance):
	for shape_node in instance.find_children("*", "CollisionShape3D", true, false):
		if shape_node.is_in_group("road_collision"):
			shape_node.reparent(self)

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
