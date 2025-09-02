extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var base_fov := 75.0

@export_group("Movement")
@export_subgroup("Ground")
@export var base_speed := 8.0
var move_speed := 8.0
@export var acceleration := 100.0
@export var sprint_mult := 2.0
@export var sneak_mult := 2.0
@export var rotation_speed := 12.0
@export var min_jump_impulse := 12.0
@export var max_jump_impulse := 50.0
@export var jump_charge_time := 3.0
@export_subgroup("Flying")
@export var flying_mult := 6.0
@export var super_mult := 10.0
@export var flying_acceleration_mult := 0.6
@export var super_acceleration_mult := 8.0
@export var ascend_descend_speed := 40.0
@export var flight_turn_speed := 50.0
@export var air_brake_deceleration := 400.0
@export_subgroup("Misc")
@export var max_step_height := 0.5
@export var step_check_distance := 0.8
@export var base_gravity := -70.0

# -- States --
enum State {
	GROUNDED, RUNNING, SNEAKING, CHARGING_JUMP,
	IN_AIR, FLIGHT, SUPER_FLIGHT
	}
var current_state = State.GROUNDED
var last_state = State.GROUNDED
var can_move := true # THIS MEANS CAN PHYSICALLY MOVE
var can_fly := true
var air_brake := false
var speed_mult := 1.0
var current_jump_charge := 0.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -70.0
var click_count := 0

# -- Scene assignment --
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera
@onready var _camera_spring: SpringArm3D = %CameraSpring
@onready var _stickman := %Bob
@onready var double_click_timer := %DoubleClickTimer
@onready var step_up_cast := %StepUpCast
@onready var sonic_boom_vfx := %SonicBoomFX

@onready var poof_effect_scene: PackedScene = preload("res://assets/vfx/poof.tscn")
@onready var projectile_scene: PackedScene = preload("res://temp_scenes/test_projectile.tscn")

func _ready():
	LODManager.register_player(self)
	
	_camera.fov = base_fov
	move_speed = base_speed
	_gravity = base_gravity
	


func _input(event):
	# Hide and show cursor
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# SHIFT Logic
	if event.is_action_pressed("sprint"):
		match current_state:
			State.FLIGHT:
				current_state = State.SUPER_FLIGHT
				air_brake = false
				speed_mult *= (sprint_mult * 2)
				sonic_boom_vfx.emitting = true
			State.GROUNDED:
				current_state = State.RUNNING
				speed_mult *= sprint_mult
	if event.is_action_released("sprint"):
		match current_state:
			State.SUPER_FLIGHT:
				current_state = State.FLIGHT
				speed_mult /= (sprint_mult * 2)
				air_brake = true
			State.RUNNING:
				current_state = State.GROUNDED
				speed_mult /= sprint_mult
	
	# CTRL Logic
	if event.is_action_pressed("crouch"):
		match current_state:
			State.FLIGHT:
				velocity.y = -ascend_descend_speed
			State.GROUNDED:
				current_state = State.SNEAKING
				speed_mult /= sneak_mult
	if event.is_action_released("crouch"):
		match current_state:
			State.FLIGHT:
				velocity.y = 0.0
			State.SNEAKING:
				current_state = State.GROUNDED
				speed_mult *= sneak_mult

	
	# SPACE logic
	if event.is_action_pressed("jump") and not is_on_floor():
		match current_state:
			State.IN_AIR:
				if can_fly: fly()
			State.FLIGHT, State.SUPER_FLIGHT:
				click_count += 1
				if click_count == 1: double_click_timer.start()
				elif click_count == 2:
					fly()
					double_click_timer.stop()
					return
				if current_state == State.FLIGHT:
					velocity.y = ascend_descend_speed
	if event.is_action_released("jump"):
		if current_state == State.FLIGHT:
			if velocity.y > 0.0:
				velocity.y = 0.0
	
	# Skill 1 Logic (Default 'Q')
	if event.is_action_pressed("skill_1") and %SpeedTimer.is_stopped():
		speed_up(15.0)
	
	# Skill 2 Logic (Default 'E')
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
	# Check state
	if current_state != last_state:
		print("State: " + str(current_state))
		last_state = current_state
	
	# Resetting conditions
	if is_on_floor():
		match current_state:
			State.IN_AIR: current_state = State.GROUNDED
			State.FLIGHT, State.SUPER_FLIGHT:
				fly()
				current_state = State.GROUNDED
		if can_fly == false: can_fly = true
	elif not is_on_floor():
		if current_state != State.FLIGHT and current_state != State.SUPER_FLIGHT and current_state != State.IN_AIR:
			current_state =  State.IN_AIR
	
	# Camera control
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 3.0, PI / 2.001)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
	# Ground or Flight state movement
	match current_state:
		State.FLIGHT, State.SUPER_FLIGHT:
			flight_movement(delta)
		_:
			ground_movement(delta)
	
	if can_move:
		move_and_slide()
	
	# Dynamic FOV
	var target_fov = base_fov + (move_speed * 0.15)
	if target_fov > 120.0: target_fov = 120.0
	_camera.fov = lerp(_camera.fov, target_fov, delta * 5.0)
	if current_state == State.SUPER_FLIGHT:
		_camera_spring.spring_length = lerp(_camera_spring.spring_length, 2.5, delta * 5.0)
	elif _camera_spring.spring_length != 8.0:
		_camera_spring.spring_length = lerp(_camera_spring.spring_length, 8.0, delta * 10.0)

	
	# Stickman Animations
	handle_animations()
	

func handle_animations():
	match current_state:
		State.FLIGHT:
			%StandardCollision.disabled = false
			%FlyCollision.disabled = true
			_stickman.update_animation("hover")
		State.SUPER_FLIGHT:
			%StandardCollision.disabled = true
			%FlyCollision.disabled = false
			if velocity.y < 0.0:
				_stickman.update_animation("fly_down")
			elif velocity.y > 0.0:
				_stickman.update_animation("fly_up")
			else:
				_stickman.update_animation("fly")
		State.IN_AIR:
			%StandardCollision.disabled = false
			%FlyCollision.disabled = true
			if velocity.y > 0:
				_stickman.update_animation("rise")
			elif velocity.y < 0:
				_stickman.update_animation("fall")
		State.GROUNDED:
			%StandardCollision.disabled = false
			%FlyCollision.disabled = true
			var ground_speed := velocity.length()
			if ground_speed > 0.0: _stickman.update_animation("walk")
			else: _stickman.update_animation("idle")
		State.RUNNING:
			_stickman.update_animation("run")
		State.CHARGING_JUMP:
			if Input.is_action_just_pressed("jump"):
				_stickman.update_animation("charge_jump")

func default_state():
	can_move = true
	can_fly = true
	move_speed = base_speed
	speed_mult = 1.0
	current_jump_charge = 0.0

func ground_movement(delta):
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
		if current_state == State.SNEAKING: move_speed = base_speed * speed_mult
		else: speed_mult = 1.0
	
	# Handle gravity
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
	
	# Rotate to movement direction
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_stickman.global_rotation.y = lerp_angle(_stickman.rotation.y, target_angle, rotation_speed * delta)
	$SpawnPivot.global_rotation.y = lerp_angle($SpawnPivot.rotation.y, target_angle, rotation_speed * delta)
	
	# Handle Step-Up
	if is_on_floor() and move_direction.length() > 0:
		var step_height = _get_step_height(move_direction)
		if step_height > 0.0:
			global_position.y += step_height + 0.05
			velocity.y = 0
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		current_state = State.CHARGING_JUMP
		velocity = Vector3.ZERO
		can_move = false
		can_fly = false
		current_jump_charge = 0.0
	
	if current_state == State.CHARGING_JUMP:
		if Input.is_action_pressed("jump"):
			current_jump_charge += delta / jump_charge_time
			current_jump_charge = min(current_jump_charge, 1.0)
			move_speed -= current_jump_charge * 60 # FOV effect
		if Input.is_action_just_released("jump"):
			current_state = State.IN_AIR
			if current_jump_charge >= 0.5: can_fly = true
			var jump_impulse = lerp(min_jump_impulse, max_jump_impulse, current_jump_charge)
			velocity.y = jump_impulse
			
			# Poof effect
			var poof = poof_effect_scene.instantiate()
			get_tree().root.add_child(poof)
			poof.global_position = %Marker3D.global_position
			poof.emitting = true
			poof.finished.connect(poof.queue_free)
			
			# Reset Charging
			current_jump_charge = 0.0
			can_move = true


func flight_movement(delta):
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Check speed mult
	if speed_mult > 1.0: move_speed = base_speed * speed_mult
	elif speed_mult == 1.0: move_speed = base_speed
	elif speed_mult < 1.0:
		speed_mult = 1.0
	
	match current_state:
		State.FLIGHT:
			if air_brake:
				velocity = velocity.move_toward(Vector3.ZERO, air_brake_deceleration * delta)
				
				if velocity.length() < 0.1:
					velocity = Vector3.ZERO
					air_brake = false
			else:
				# Movement data
				var forward := _camera.global_basis.z
				var right := _camera.global_basis.x
				
				var move_direction := forward * raw_input.y + right * raw_input.x
				move_direction.y = 0.0
				move_direction = move_direction.normalized()
				
				# Handle gravity
				var y_velocity := velocity.y
				velocity.y = 0.0
				velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
				velocity.y = y_velocity + _gravity * delta
				
				# Rotate to movement direction
				if move_direction.length() > 0.2:
					_last_movement_direction = move_direction
				
				var target_basis = Transform3D().looking_at(-_last_movement_direction, Vector3.UP).basis
				var turn_speed = rotation_speed
				_stickman.global_transform.basis = _stickman.global_transform.basis.orthonormalized().slerp(target_basis, turn_speed * delta)
				
				# Sync other nodes to the stickman's rotation
				$SpawnPivot.global_transform.basis = _stickman.global_transform.basis

		State.SUPER_FLIGHT:
			var direction := -_camera.global_transform.basis.z.normalized()
			
			var current_acceleration := acceleration * super_acceleration_mult

			var target_velocity := direction * move_speed
			
			velocity = velocity.move_toward(target_velocity, current_acceleration * delta)
			
			# Rotate the character model to face the direction of travel.
			if velocity.length_squared() > 0.01:
				var target_basis := Transform3D().looking_at(-velocity.normalized(), Vector3.UP).basis
				_stickman.global_transform.basis = _stickman.global_transform.basis.orthonormalized().slerp(target_basis, flight_turn_speed * delta)
				%FlyCollision.global_transform.basis = _stickman.global_transform.basis
				%FlyCollision.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

func speed_up(new_mult):
	var temp_mult = speed_mult
	speed_mult = new_mult
	%SpeedTimer.start()
	await %SpeedTimer.timeout
	speed_mult = temp_mult

func fly():
	if current_state == State.SUPER_FLIGHT:
		current_state = State.IN_AIR
		speed_mult /= (speed_mult * 4)
		_gravity = base_gravity
	elif current_state  == State.FLIGHT:
		current_state = State.IN_AIR
		speed_mult /= flying_mult
		acceleration /= flying_acceleration_mult
		_gravity = base_gravity
	else:
		current_state = State.FLIGHT
		velocity.y = 0.0
		_gravity = 0.0
		speed_mult *= flying_mult
		acceleration *= flying_acceleration_mult
		can_move = true

func spawn_projectile():
	var ball = projectile_scene.instantiate()
	ball.global_transform = %BallSpawn.global_transform
	get_tree().root.add_child(ball)

func _get_step_height(move_direction: Vector3) -> float:
	# Position the shapecast slightly in front of the character and at the max step height
	var cast_origin = Vector3.UP * (max_step_height + 0.1)
	var cast_forward = move_direction.normalized() * step_check_distance
	step_up_cast.global_position = global_position + cast_origin + cast_forward
	
	# Force the shapecast to update its collision information
	step_up_cast.force_shapecast_update()
	
	# Check if the shapecast hit something below it
	if step_up_cast.is_colliding():
		# Get the vertical distance to the collision point
		var step_height = step_up_cast.get_collision_point(0).y - global_position.y
		
		# Check if the step is within a valid range (not too high, and not a ramp/floor)
		if step_height > 0.01 and step_height <= max_step_height:
			# Return the height of the valid step
			return step_height
	
	# If no valid step is found, return 0.0
	return 0.0

func _on_double_click_timer_timeout() -> void:
	click_count = 0
