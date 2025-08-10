extends Skeleton3D

@export var linear_spring_stiffness:= 100
@export var linear_spring_dampness:= 10
@export var angular_spring_stiffness:= 50
@export var angular_spring_damping:= 20

@onready var physics_sim := %PhysicalBoneSimulator3D

var physics_bones

func _ready():
	physics_bones = physics_sim.get_children().filter(func(x): return x is PhysicalBone3D)
	setup_parameters()

func setup_parameters():
	for b in physics_bones:
		pass
