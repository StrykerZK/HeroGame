extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_group("Movement")
@export var base_speed := 8.0
var move_speed := 8.0
@export var acceleration := 50.0
@export var sprint_mult := 2.0
@export var flying_mult := 4.0
@export var flying_acceleration_mult := 10.0
@export var flying_ascend_descend_speed := 20.0
@export var rotation_speed := 12.0
@export var min_jump_impulse := 12.0
@export var max_jump_impulse := 50.0
@export var jump_charge_time := 3.0
@export var base_fov := 75.0

var can_move:= true
var is_running:= false
var is_crouching:= false
var is_flying:= false
var is_boosting:= false
var is_ascending:= false
var is_descending:= false
var is_jumping:= false
var is_charging_jump := false
var is_jump_charged:= false
var speed_mult := 1.0
var current_jump_charge := 0.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -70.0
var click_count := 0

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera
@onready var _stickman := %Bob
@onready var double_click_timer := %DoubleClickTimer
@onready var speed_lines_vfx := %SpeedLinesVFX

@onready var poof_effect_scene: PackedScene = preload("res://assets/vfx/poof.tscn")
@onready var projectile_scene: PackedScene = preload("res://temp_scenes/test_projectile.tscn")

func _ready():
	_camera.fov = base_fov
	move_speed = base_speed
	
	speed_lines_vfx.emitting = false


func _input(event):
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("sprint"):
		if is_flying and not is_boosting:
			is_boosting = true
			speed_mult *= (sprint_mult * 4)
			speedlines()
		elif is_on_floor() and not is_running:
			is_running = true
			speed_mult *= sprint_mult
	if event.is_action_released("sprint"):
		if is_flying and is_boosting:
			is_boosting = false
			speed_mult /= (sprint_mult * 4)
			speedlines()
		elif is_on_floor() and is_running:
				is_running = false
				speed_mult /= sprint_mult
	if event.is_action_pressed("crouch"):
		if is_on_floor() and not is_crouching:
			is_crouching = true
			speed_mult /= 2
		elif is_flying:
			is_descending = true
			velocity.y = -flying_ascend_descend_speed
	if event.is_action_released("crouch"):
		if is_on_floor() and is_crouching:
			is_crouching = false
			speed_mult *= 2
		elif is_flying:
			is_descending = false
			velocity.y = 0.0
	if event.is_action_pressed("jump") and not is_on_floor():
		if not is_flying:
			if is_jumping and not is_jump_charged:
				pass
			else:
				fly()
				if is_jump_charged: is_jump_charged = false
				if is_jumping: is_jumping = false
		else:
			click_count += 1
			if click_count == 1: double_click_timer.start()
			elif click_count == 2:
				fly()
				double_click_timer.stop()
				return
			is_ascending = true
			velocity.y = flying_ascend_descend_speed
	if event.is_action_released("jump") and is_flying:
		if velocity.y > 0.0:
			is_ascending = false
			velocity.y = 0.0
	if event.is_action_pressed("skill_1") and %SpeedTimer.is_stopped():
		speed_up(15.0)
	if event.is_action_pressed("skill_2"):
		spawn_projectile()

func _unhandled_input(event):
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

func _physics_process(delta):
	# Resetting conditions
	if is_on_floor():
		if is_jumping: is_jumping = false
	
	# Camera control
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
	# Movement data
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	
	# Check speed mult
	if speed_mult > 1.0: move_speed = base_speed * speed_mult
	elif speed_mult == 1.0: move_speed = base_speed
	elif speed_mult < 1.0:
		if is_crouching: move_speed = base_speed * speed_mult
		else: speed_mult = 1.0
	
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
		
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_stickman.global_rotation.y = lerp_angle(_stickman.rotation.y, target_angle, rotation_speed * delta)
	speed_lines_vfx.global_rotation.y = lerp_angle(speed_lines_vfx.rotation.y, target_angle, rotation_speed * delta)
	%FlyCollision.global_rotation.y = lerp_angle(%FlyCollision.rotation.y, target_angle, rotation_speed * delta)
	$SpawnPivot.global_rotation.y = lerp_angle($SpawnPivot.rotation.y, target_angle, rotation_speed * delta)

	
	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	
	# Charging Jump
	if is_starting_jump:
		velocity = Vector3.ZERO
		can_move = false
		is_charging_jump = true
		current_jump_charge = 0.0
		
	if Input.is_action_pressed("jump") and is_charging_jump:
		current_jump_charge += delta / jump_charge_time
		current_jump_charge = min(current_jump_charge, 1.0)
		move_speed -= current_jump_charge * 60 # FOV effect
		if current_jump_charge >= 0.5 and not is_jump_charged:
			is_jump_charged = true
		
	if Input.is_action_just_released("jump") and is_charging_jump:
		is_jumping = true
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
		can_move = true
	
	if not is_charging_jump:
		move_and_slide()
	
	
	# Dynamic FOV
	var target_fov = base_fov + (move_speed * 0.15)
	if target_fov > 120.0: target_fov = 120.0
	_camera.fov = lerp(_camera.fov, target_fov, delta * 5.0)
	
	# Stickman Animations
	if not is_on_floor():
		if is_flying:
			%StandardCollision.disabled = true
			%FlyCollision.disabled = false
			if is_descending:
				_stickman.update_animation("fly_down")
			elif is_ascending:
				_stickman.update_animation("fly_up")
			else:
				if velocity.length() > 0.0:
					_stickman.update_animation("fly")
				else:
					_stickman.update_animation("hover")
					%StandardCollision.disabled = false
					%FlyCollision.disabled = true
		else:
			%StandardCollision.disabled = false
			%FlyCollision.disabled = true
			if velocity.y > 0:
				_stickman.update_animation("rise")
			elif velocity.y < 0:
				_stickman.update_animation("fall")
	elif is_on_floor():
		%StandardCollision.disabled = false
		%FlyCollision.disabled = true
		var ground_speed := velocity.length()
		if is_charging_jump:
			if Input.is_action_just_pressed("jump"):
				_stickman.update_animation("charge_jump")
			else: return
		else:
			if ground_speed > 0.0:
				if not is_running: _stickman.update_animation("walk")
				else: _stickman.update_animation("run")
			else: _stickman.update_animation("idle")
	
	# Stop flying if hit ground
	if is_flying and is_on_floor():
		fly()

func speed_up(new_mult):
	var temp_mult = speed_mult
	speed_mult = new_mult
	%SpeedTimer.start()
	await %SpeedTimer.timeout
	speed_mult = temp_mult

func fly():
	if not is_flying:
		is_flying = true
		_gravity = 0
		velocity.y = 0.0
		speed_mult *= flying_mult
		acceleration *= flying_acceleration_mult
		can_move = true
	else:
		velocity = Vector3.ZERO
		is_flying = false
		if is_boosting:
			is_boosting = false
			speed_mult /= (speed_mult * 4)
		is_ascending = false
		is_descending = false
		_gravity = -70.0
		speed_mult /= flying_mult
		acceleration /= flying_acceleration_mult

func spawn_projectile():
	var ball = projectile_scene.instantiate()
	ball.global_transform = %BallSpawn.global_transform
	get_tree().root.add_child(ball)

func speedlines():
	if not speed_lines_vfx.emitting:
		speed_lines_vfx.emitting = true
	else:
		speed_lines_vfx.emitting = false


func _on_double_click_timer_timeout() -> void:
	click_count = 0
