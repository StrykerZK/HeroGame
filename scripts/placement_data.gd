# PlacementData.gd
# This script defines a custom resource to hold a scene and its placement limit.
class_name PlacementData
extends Resource

@export var scene: PackedScene
@export var limit := -1 # A limit of -1 means infinite placements are allowed.
