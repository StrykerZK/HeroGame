# BuildingData.gd
# Attach this to the root Node3D of every building scene.
class_name BuildingData
extends Node3D

# The footprint of this building in grid cells.
# For a single-cell building, this should be Vector2i(1, 1).
# For a 3x2 building, this should be Vector2i(3, 2).
@export var size := Vector2i(1, 1)

var grid_position: Vector2i

@export_group("Generator Settings")
# If true, this building is treated as a primary landmark for its zone.
@export var is_landmark := false
# The maximum number of times this scene can be placed across the ENTIRE map. -1 for unlimited.
@export var global_limit := -1
# The maximum number of times this scene can be placed PER DISTRICT. -1 for unlimited.
@export var local_limit := -1
