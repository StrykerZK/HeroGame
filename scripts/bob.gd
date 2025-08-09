extends Node3D


@onready var anim_player: AnimationPlayer = $AnimationPlayer

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
