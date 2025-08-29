class_name BuildingData
extends Node3D

@export_group("Settings")
@export_subgroup("Scene Settings")
@export var size := Vector2i(1, 1) # 3x2 would be Vector2i(3, 2)

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
	set_lod_level(2)

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
