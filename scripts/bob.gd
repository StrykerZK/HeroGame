extends Node3D


@onready var anim_player: AnimationPlayer = %AnimationPlayer
@onready var anim_tree: AnimationTree = %AnimationTree

var anim_state_machine

func _ready():
	anim_state_machine = anim_tree.get("parameters/playback")

func update_animation(state: String):
	anim_state_machine.travel(state)


func idle():
	anim_player.play("idle")

func walk():
	anim_player.play("walk")

func run():
	anim_player.play("run")

func rise():
	anim_player.play("rise")

func fall():
	anim_player.play("fall")

func charge():
	anim_player.play("charge_jump")

func charging(charge_anim):
	if charge_anim == "charge_jump":
		anim_player.play("charging_jump")
	else: return

func fly():
	anim_player.play("fly")

func fly_up():
	anim_player.play("fly_up")

func fly_down():
	anim_player.play("fly_down")

func hover():
	anim_player.play("hover")
