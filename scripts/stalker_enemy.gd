class_name StalkerEnemy
extends CharacterBody3D

const GlobalBus = preload("res://scripts/global_events.gd")

## Intelligent Warehouse Horror Stalker AI
## States: PATROL, INVESTIGATE, CHASE, JUMPSCARE
## Uses NavigationAgent3D for pathfinding, vision raycast + FOV cone check,
## and listens to GlobalEvents noise emissions (sprinting, bear traps, puzzle buzzers).

enum State { PATROL, INVESTIGATE, CHASE, JUMPSCARE }

@export_group("AI Settings")
@export var patrol_points: Array[Node3D] = []
@export var patrol_speed: float = 2.4
@export var investigate_speed: float = 3.6
@export var chase_speed: float = 5.2
@export var sight_distance: float = 20.0
@export var sight_fov_degrees: float = 75.0
@export var catch_distance: float = 1.6
@export var patrol_wait_time: float = 2.0
@export var search_wait_time: float = 3.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_ray: RayCast3D = $VisionRay
@onready var eye_left: MeshInstance3D = $VisualRoot/Head/EyeLeft
@onready var eye_right: MeshInstance3D = $VisualRoot/Head/EyeRight
@onready var stalker_light: OmniLight3D = $VisualRoot/StalkerLight
@onready var alert_audio: AudioStreamPlayer3D = $AlertAudio
@onready var roar_audio: AudioStreamPlayer3D = $RoarAudio
@onready var jumpscare_audio: AudioStreamPlayer3D = $JumpscareAudio

var current_state: State = State.PATROL
var current_patrol_idx: int = 0
var wait_timer: float = 0.0
var investigate_target: Vector3 = Vector3.ZERO
var player_ref: Player = null
var is_chasing_player: bool = false
var lost_sight_timer: float = 0.0

func _ready() -> void:
	# Connect to global noise bus
	GlobalBus.connect_noise(_on_noise_emitted)
	
	# Configure navigation agent
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	# Find player reference
	call_deferred("_find_player")

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _on_noise_emitted(origin: Vector3, radius: float) -> void:
	if current_state == State.CHASE or current_state == State.JUMPSCARE:
		return
		
	var dist = global_position.distance_to(origin)
	if dist <= radius:
		# Alerted by noise
		current_state = State.INVESTIGATE
		investigate_target = origin
		nav_agent.target_position = origin
		wait_timer = search_wait_time
		if alert_audio and not alert_audio.playing:
			alert_audio.play()

func _physics_process(delta: float) -> void:
	if current_state == State.JUMPSCARE:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not player_ref:
		_find_player()

	# Check sight cone to player
	var can_see_player = _check_player_visibility()
	
	match current_state:
		State.PATROL:
			_process_patrol(delta, can_see_player)
		State.INVESTIGATE:
			_process_investigate(delta, can_see_player)
		State.CHASE:
			_process_chase(delta, can_see_player)

	move_and_slide()

# --- Vision Cone Detection ---
func _check_player_visibility() -> bool:
	if not player_ref or not is_instance_valid(player_ref) or player_ref.is_game_ended:
		return false
		
	var to_player = player_ref.global_position - global_position
	var dist = to_player.length()
	
	# If player has flashlight on, stalker can spot them from further and wider!
	var effective_sight_dist = sight_distance
	var effective_fov = sight_fov_degrees
	if player_ref.flashlight and player_ref.flashlight.visible:
		effective_sight_dist *= 1.4
		effective_fov += 35.0
		
	if dist > effective_sight_dist:
		return false
		
	# Angle check (horizontal forward direction)
	var forward = -transform.basis.z.normalized()
	var horizontal_to_player = Vector3(to_player.x, 0, to_player.z).normalized()
	var angle = rad_to_deg(forward.angle_to(horizontal_to_player))
	if angle > effective_fov * 0.5:
		return false
		
	# RayCast check for line-of-sight occlusion
	if vision_ray:
		var target_loc = player_ref.global_position + Vector3(0, 1.2, 0)
		vision_ray.target_position = vision_ray.to_local(target_loc)
		vision_ray.force_raycast_update()
		if vision_ray.is_colliding():
			var col = vision_ray.get_collider()
			if col == player_ref or (col and col.owner == player_ref):
				return true
				
	return false

# --- State Processors ---
func _process_patrol(delta: float, can_see_player: bool) -> void:
	if can_see_player:
		_start_chase()
		return
		
	if patrol_points.is_empty():
		return
		
	var target_node = patrol_points[current_patrol_idx]
	if not is_instance_valid(target_node):
		return
		
	var target_pos = target_node.global_position
	nav_agent.target_position = target_pos
	
	if nav_agent.is_navigation_finished() or global_position.distance_to(target_pos) < 1.2:
		# Reached waypoint, wait momentarily
		wait_timer += delta
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		if wait_timer >= patrol_wait_time:
			wait_timer = 0.0
			current_patrol_idx = (current_patrol_idx + 1) % patrol_points.size()
	else:
		_navigate_towards_path(patrol_speed, delta)

func _process_investigate(delta: float, can_see_player: bool) -> void:
	if can_see_player:
		_start_chase()
		return
		
	nav_agent.target_position = investigate_target
	
	if nav_agent.is_navigation_finished() or global_position.distance_to(investigate_target) < 1.5:
		# Arrived at noise location, search area
		wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		# Slowly scan head/body left and right
		rotate_y(delta * 1.5)
		if wait_timer <= 0.0:
			current_state = State.PATROL
	else:
		_navigate_towards_path(investigate_speed, delta)

func _process_chase(delta: float, can_see_player: bool) -> void:
	if not player_ref or player_ref.is_game_ended:
		current_state = State.PATROL
		return
		
	# Check catch distance
	var dist_to_player = global_position.distance_to(player_ref.global_position)
	if dist_to_player <= catch_distance:
		_trigger_jumpscare()
		return
		
	nav_agent.target_position = player_ref.global_position
	
	if can_see_player:
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += delta
		if lost_sight_timer > 4.5:
			# Lost sight of player: investigate last known location
			current_state = State.INVESTIGATE
			investigate_target = player_ref.global_position
			wait_timer = search_wait_time
			return
			
	_navigate_towards_path(chase_speed, delta)

func _start_chase() -> void:
	current_state = State.CHASE
	lost_sight_timer = 0.0
	if roar_audio:
		roar_audio.play()
	if stalker_light:
		stalker_light.light_color = Color(1.0, 0.1, 0.05, 1.0)
		stalker_light.light_energy = 2.5

func _trigger_jumpscare() -> void:
	current_state = State.JUMPSCARE
	velocity = Vector3.ZERO
	
	if jumpscare_audio:
		jumpscare_audio.play()
		
	if player_ref and is_instance_valid(player_ref):
		player_ref.trigger_game_over(self)

func _navigate_towards_path(speed: float, delta: float) -> void:
	var next_path_pos = nav_agent.get_next_path_position()
	var move_dir = (next_path_pos - global_position)
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
		# Smoothly rotate monster towards movement direction
		var target_angle = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
		
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
