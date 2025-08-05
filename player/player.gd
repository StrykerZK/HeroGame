extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_group("Movement")
@export var base_speed := 40.0
var move_speed := 8.0
@export var acceleration := 1000.0
@export var sprint_mult := 2.0
@export var rotation_speed := 12.0
@export var min_jump_impulse := 30.0
@export var max_jump_impulse := 100.0
@export var jump_charge_time := 3.0
@export var base_fov := 75.0

@export var poof_effect_scene: PackedScene = preload("res://assets/vfx/poof.tscn")

var speed_mult := 1.0
var is_charging_jump := false
var current_jump_charge := 0.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -70.0

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera
@onready var _skin: SophiaSkin = %SophiaSkin


func _ready():
	_camera.fov = base_fov
	move_speed = base_speed

func _input(event):
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("run"):
		speed_mult *= sprint_mult
	if event.is_action_released("run"):
		speed_mult /= sprint_mult
	if event.is_action_pressed("skill_1") and %SpeedTimer.is_stopped():
		speed_up(15.0)

func _unhandled_input(event):
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

func _physics_process(delta):
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
	if not is_charging_jump:
		var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var forward := _camera.global_basis.z
		var right := _camera.global_basis.x
	
		var move_direction := forward * raw_input.y + right * raw_input.x
		move_direction.y = 0.0
		move_direction = move_direction.normalized()
	
		# Check speed mult
		if speed_mult > 1.0: move_speed = base_speed * speed_mult
		elif speed_mult == 1.0: move_speed = base_speed
		elif speed_mult < 1.0: speed_mult = 1.0
		
		var y_velocity := velocity.y
		velocity.y = 0.0
		velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
		velocity.y = y_velocity + _gravity * delta
		
		if move_direction.length() > 0.2:
			_last_movement_direction = move_direction
		var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
		_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	
	# Charging Jump
	if is_starting_jump:
		velocity = Vector3.ZERO
		is_charging_jump = true
		current_jump_charge = 0.0
		
	if Input.is_action_pressed("jump") and is_charging_jump:
		current_jump_charge += delta / jump_charge_time
		current_jump_charge = min(current_jump_charge, 1.0)
		
	if Input.is_action_just_released("jump") and is_charging_jump:
		var jump_impulse = lerp(min_jump_impulse, max_jump_impulse, current_jump_charge)
		velocity.y = jump_impulse
		
		# Poof effect
		var poof = poof_effect_scene.instantiate()
		get_tree().root.add_child(poof)
		poof.global_position = %Marker3D.global_position
		poof.emitting = true
		poof.finished.connect(poof.queue_free)
		
		# Reset Charging
		is_charging_jump = false
		current_jump_charge = 0.0
	
	move_and_slide()
	
	
	
	# Dynamic FOV
	var target_fov = base_fov + (move_speed * 0.15)
	if target_fov > 120.0: target_fov = 120.0
	_camera.fov = lerp(_camera.fov, target_fov, delta * 5.0)
	
	# Sophia Animations
	if Input.is_action_just_released("jump") and velocity.y > 0:
		_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		_skin.fall()
	elif is_on_floor():
		var ground_speed := velocity.length()
		if ground_speed > 0.0:
			_skin.move()
		else:
			_skin.idle()

func speed_up(new_mult):
	var temp_mult = speed_mult
	speed_mult = new_mult
	%SpeedTimer.start()
	await %SpeedTimer.timeout
	speed_mult = temp_mult
