extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var base_mouse_sensitivity := 0.20
var mouse_sensitivity := base_mouse_sensitivity
@export var base_fov := 75.0

@export_group("Aiming")
@export var aim_fov := 40.0
@export var aim_speed := 10.0
@export var aim_mouse_sensitivity_mult := 0.5
var is_aiming := false

@export_group("Movement")
@export_subgroup("Ground")
@export var base_speed := 8.0
var move_speed := base_speed
var speed_mult := 1.0
@export var acceleration := 100.0
@export var sprint_mult := 2.0
@export var sneak_mult := 0.4
@export var rotation_speed := 12.0
@export var min_jump_impulse := 15.0
@export var max_jump_impulse := 150.0
@export var jump_charge_time := 3.0
@export_subgroup("Flying")
@export var flying_mult := 6.0
@export var super_mult := 30.0
@export var flying_acceleration_mult := 0.8
@export var super_acceleration_mult := 10.0
@export var ascend_descend_speed := 40.0
@export var flight_turn_speed := 20.0
@export var air_brake_deceleration := 600.0
@export var max_landing_deceleration := 300.0
@export var landing_curve: Curve # The curve for the slide deceleration.
@export_subgroup("Misc")
@export var max_step_height := 0.5
@export var step_check_distance := 0.8
@export var base_gravity := -70.0

@export_group("Stats")
@export var base_health := 100.0
var current_health := base_health
@export var global_dmg_scale := 1.0
@export var defense := 4.0
@export var speed_modifier := 1.0 # Multiplier for external effects (buffs/debuffs)

# -- States --
enum State {
	GROUNDED, RUNNING, SNEAKING, CHARGING_JUMP, LANDING,
	IN_AIR, FLIGHT, SUPER_FLIGHT
	}
var current_state = State.GROUNDED
var last_state = State.GROUNDED
var can_move := true # THIS MEANS CAN PHYSICALLY MOVE
var can_fly := true
var air_brake := false
var shoulder_side := 1
var current_jump_charge := 0.0
var landing_initial_velocity := Vector3.ZERO
var landing_initial_speed := 0.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -70.0
var click_count := 0

# -- Node assignment --
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera
@onready var _camera_spring: SpringArm3D = %CameraSpring
@onready var _shoulder_pivot: Node3D = %ShoulderPivot
@onready var _camera_animation: AnimationPlayer = %CameraPivotAnimation
@onready var _stickman := %Bob
@onready var double_click_timer := %DoubleClickTimer
@onready var step_up_cast := %StepUpCast
@onready var sonic_boom_vfx := %SonicBoomFX
@onready var fx_player := %FXPlayer

# -- Scene assignment --
@export_group("Scenes")
@export var world_environment_node: WorldEnvironment
@onready var poof_effect_scene: PackedScene = preload("res://assets/vfx/poof.tscn")
@onready var projectile_scene: PackedScene = preload("res://temp_scenes/test_projectile.tscn")

func _ready():
	if is_instance_valid(LODManager):
		LODManager.register_player(self)
	
	if is_multiplayer_authority():
		_setup_local_player_fog()
	
	_camera.fov = base_fov
	_gravity = base_gravity
	


func _input(event):
	# Hide and show cursor
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Aiming Logic (Right Click)
	if event.is_action_pressed("aim"):
		is_aiming = true
		mouse_sensitivity = base_mouse_sensitivity * aim_mouse_sensitivity_mult
	if event.is_action_released("aim"):
		is_aiming = false
		mouse_sensitivity = base_mouse_sensitivity

	# SHIFT Logic
	if event.is_action_pressed("sprint"):
		match current_state:
			State.FLIGHT:
				if air_brake == true: return
				current_state = State.SUPER_FLIGHT
				air_brake = false
				mouse_sensitivity *= 0.4
				make_sonic_boom()
			State.GROUNDED:
				current_state = State.RUNNING
	if event.is_action_released("sprint"):
		match current_state:
			State.SUPER_FLIGHT:
				current_state = State.FLIGHT
				mouse_sensitivity /= 0.4
				make_sonic_boom()
				air_brake = true
			State.RUNNING:
				current_state = State.GROUNDED
	
	# CTRL Logic
	if event.is_action_pressed("crouch"):
		match current_state:
			State.FLIGHT:
				velocity.y = -ascend_descend_speed
			State.GROUNDED:
				current_state = State.SNEAKING
	if event.is_action_released("crouch"):
		match current_state:
			State.FLIGHT:
				velocity.y = 0.0
			State.SNEAKING:
				current_state = State.GROUNDED
	
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
					click_count = 0
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
	
	# Shoulder Switch Logic (Default 'Middle Mouse')
	if event.is_action_pressed("switch_shoulders"):
		switch_shoulders()

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
	
	# State transition logic
	if is_on_floor():
		match current_state:
			State.IN_AIR: 
				current_state = State.LANDING
				landing_initial_velocity = velocity
				landing_initial_velocity.y = 0
				landing_initial_speed = landing_initial_velocity.length()
			State.FLIGHT, State.SUPER_FLIGHT:
				fly()
				current_state = State.LANDING
				landing_initial_velocity = velocity
				landing_initial_velocity.y = 0
				landing_initial_speed = landing_initial_velocity.length()
		if can_fly == false and current_state != State.CHARGING_JUMP: can_fly = true
	elif not is_on_floor():
		if current_state != State.FLIGHT and current_state != State.SUPER_FLIGHT and current_state != State.IN_AIR:
			current_state =  State.IN_AIR
	
	# Camera control
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 3.0, PI / 2.001)
	_shoulder_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
	# Ground or Flight state movement
	match current_state:
		State.FLIGHT, State.SUPER_FLIGHT:
			flight_movement(delta)
		State.LANDING:
			landing_movement(delta)
		_:
			ground_movement(delta)
	
	if can_move:
		move_and_slide()
	
	handle_rotation(delta)
	handle_camera_zoom(delta)
	
	# Spring Arm length logic
	if current_state == State.SUPER_FLIGHT:
		_camera_spring.spring_length = lerp(_camera_spring.spring_length, 2.0, delta * 5.0)
	elif _camera_spring.spring_length != 4.0:
		_camera_spring.spring_length = lerp(_camera_spring.spring_length, 4.0, delta * 10.0)

	
	# Stickman Animations
	handle_animations()
	

func handle_animations():
	match current_state:
		State.LANDING:
			_stickman.update_animation("hover")
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
			if velocity.length() > 0.0: _stickman.update_animation("run")
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
	
	# Determine current target speed based on state
	var target_speed = base_speed
	if current_state == State.RUNNING:
		target_speed *= sprint_mult
	elif current_state == State.SNEAKING:
		target_speed *= sneak_mult
	
	# Handle gravity
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * target_speed * speed_modifier, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
	
	# Store last movement direction for rotation
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	
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
				
				var target_speed = base_speed * flying_mult
				
				# Handle gravity
				var y_velocity := velocity.y
				velocity.y = 0.0
				velocity = velocity.move_toward(move_direction * target_speed * speed_modifier, acceleration * flying_acceleration_mult * delta)
				velocity.y = y_velocity + _gravity * delta
				
				# Store last movement direction for rotation
				if move_direction.length() > 0.2:
					_last_movement_direction = move_direction

		State.SUPER_FLIGHT:
			var direction := -_camera.global_transform.basis.z.normalized()
			
			var current_acceleration := acceleration * super_acceleration_mult
			var target_speed := base_speed * super_mult
			var target_velocity := direction * target_speed * speed_modifier
			
			velocity = velocity.move_toward(target_velocity, current_acceleration * delta)
			
			# Rotate the character model to face the direction of travel.
			if velocity.length_squared() > 0.01:
				var target_basis := Transform3D().looking_at(-velocity.normalized(), Vector3.UP).basis
				_stickman.global_transform.basis = _stickman.global_transform.basis.orthonormalized().slerp(target_basis, flight_turn_speed * delta)
				%FlyCollision.global_transform.basis = _stickman.global_transform.basis
				%FlyCollision.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

func landing_movement(delta):
	# Apply gravity to stick to the floor
	velocity.y = _gravity * delta

	# Separate horizontal velocity to apply deceleration
	var horizontal_velocity = velocity
	horizontal_velocity.y = 0
	
	var current_speed = horizontal_velocity.length()
	
	# If we are already stopped, or if there was no initial speed, transition out.
	if current_speed < 0.5 or is_zero_approx(landing_initial_speed):
		velocity.x = 0.0
		velocity.z = 0.0
		current_state = State.GROUNDED
		return

	# Calculate current speed as a fraction of the initial speed (0.0 to 1.0)
	var speed_fraction = current_speed / landing_initial_speed
	
	var deceleration_multiplier = 1.0
	if landing_curve:
		deceleration_multiplier = landing_curve.sample(speed_fraction)
		
	var current_deceleration = max_landing_deceleration * deceleration_multiplier
	
	# Apply deceleration
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, current_deceleration * delta)
	
	# Re-combine velocities
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func handle_rotation(delta):
	var target_basis: Basis

	if is_aiming:
		# If aiming, align the character with the camera's horizontal rotation
		var cam_y_rotation = _shoulder_pivot.global_rotation.y
		var target_quat = Quaternion(Vector3.UP, cam_y_rotation)
		var current_quat = _stickman.global_transform.basis.get_rotation_quaternion()
		var new_quat = current_quat.slerp(target_quat, rotation_speed * delta)
		_stickman.global_transform.basis = Basis(new_quat)
	
	elif current_state != State.SUPER_FLIGHT:
		# For grounded and normal flight, rotate towards movement direction
		if _last_movement_direction.length_squared() > 0.01:
			target_basis = Transform3D().looking_at(-_last_movement_direction, Vector3.UP).basis
			_stickman.global_transform.basis = _stickman.global_transform.basis.orthonormalized().slerp(target_basis, rotation_speed * delta)

	# Sync spawn pivot to the stickman's rotation
	$SpawnPivot.global_transform.basis = _stickman.global_transform.basis

func handle_camera_zoom(delta):
	var target_fov: float
	if is_aiming:
		target_fov = aim_fov
	else:
		# Dynamic FOV based on speed when not aiming
		target_fov = base_fov + (velocity.length() * 0.15)
		if target_fov > 120.0: target_fov = 120.0
	
	# Smoothly interpolate to the target FOV
	_camera.fov = lerp(_camera.fov, target_fov, aim_speed * delta)

func speed_up(new_mult):
	var temp_mult = speed_mult
	speed_mult = new_mult
	%SpeedTimer.start()
	await %SpeedTimer.timeout
	speed_mult = temp_mult

func fly():
	if current_state == State.FLIGHT or \
	   current_state == State.SUPER_FLIGHT:
		if current_state == State.SUPER_FLIGHT: mouse_sensitivity /= 0.4
		current_state = State.IN_AIR
		_gravity = base_gravity
	else:
		current_state = State.FLIGHT
		velocity.y = 0.0
		_gravity = 0.0
		can_move = true

func spawn_projectile():
	var ball = projectile_scene.instantiate()
	ball.global_transform = %BallSpawn.global_transform
	get_tree().root.add_child(ball)

func _setup_local_player_fog():
	# Safety check
	if not world_environment_node or not world_environment_node.environment:
		push_error("Player Fog: WorldEnvironment node is not assigned in the Inspector!")
		return

	# Get the Environment resource from the node.
	var env = world_environment_node.environment
	
	# --- SYNC FOG WITH LOD2 ---
	var lod2_distance = sqrt(LODManager.LOD2_DISTANCE_SQ)

	# Enable the fog for the local player.
	env.fog_enabled = true
	if lod2_distance > 0:
		env.fog_density = 3.0 / lod2_distance

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

func switch_shoulders():
	match shoulder_side:
		1:
			_camera_animation.play("right_to_left")
			shoulder_side = 2
		2:
			_camera_animation.play("left_to_right")
			shoulder_side = 1

func make_sonic_boom():
	sonic_boom_vfx.emitting = true
	fx_player.play(0.0)

# --- Public Functions for Modifiers ---

# Call this from other scripts to set a new persistent speed modifier.
func set_speed_modifier(value: float):
	speed_modifier = value

# Call this to reset the speed modifier to its default state.
func reset_speed_modifier():
	speed_modifier = 1.0

# Call this to apply a temporary speed modifier (e.g., a 5-second slow debuff).
func apply_timed_speed_modifier(value: float, duration: float):
	set_speed_modifier(value)
	await get_tree().create_timer(duration).timeout
	reset_speed_modifier()


func _on_double_click_timer_timeout() -> void:
	click_count = 0
