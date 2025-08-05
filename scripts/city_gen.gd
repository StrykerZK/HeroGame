class_name TerrainGeneration
extends Node

var mesh: MeshInstance3D
@export_group("Mesh Properties")
@export var size_depth: int = 100
@export var size_width: int = 100
@export var mesh_resolution: int = 2

func _ready():
	generate()

func generate():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(size_width, size_depth)
	plane_mesh.subdivide_depth = size_depth * mesh_resolution
	plane_mesh.subdivide_width = size_width * mesh_resolution
	plane_mesh.material = preload("res://assets/materials/city_gen_material.tres")
	
	var surface = SurfaceTool.new()
	surface.create_from(plane_mesh, 0)
	
	mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.create_trimesh_collision()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_to_group("NavSource")
	add_child(mesh)
