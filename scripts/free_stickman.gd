extends Node3D

@onready var anim_player = $AnimationPlayer

func idle():
	anim_player.play("Armature_001|Armature_001|mixamo_com|Layer0")

func run():
	anim_player.play("Armature_001|Armature_002|mixamo_com|Layer0")
