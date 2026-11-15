class_name MessyHumanAnimator
extends Node3D

# =============================================================================
# PROCEDURAL ANIMATOR FOR THE SCARY MESSY HUMANOID ABOMINATION
# 
# "I scared myself testing this at 2:45 AM. If you stare at the jaw too long,
# it stares back."
# 
# Features:
# - Violent erratic head-twitches (Jacob's Ladder / J-Horror jitter)
# - Convulsive, ragged breathing with ribcage expansion
# - Asymmetrical shambling limp (one leg drags like broken cartilage)
# - Dislocated jaw gape & claw flex
# - Predatory hunched chase sprint
# =============================================================================

enum AnimState { IDLE, PATROL, INVESTIGATE, CHASE, JUMPSCARE }

@export var current_state: AnimState = AnimState.PATROL
@export var walk_speed_factor: float = 1.0

# Bone hierarchy node hooks
@onready var hips: Node3D = get_node_or_null("Hips")
@onready var torso: Node3D = get_node_or_null("Hips/Torso")
@onready var neck: Node3D = get_node_or_null("Hips/Torso/Neck")
@onready var head: Node3D = get_node_or_null("Hips/Torso/Neck/Head")
@onready var jaw_hinge: Node3D = get_node_or_null("Hips/Torso/Neck/Head/JawHinge")
@onready var shoulder_l: Node3D = get_node_or_null("Hips/Torso/ShoulderLeft")
@onready var shoulder_r: Node3D = get_node_or_null("Hips/Torso/ShoulderRight")
@onready var hand_l: Node3D = get_node_or_null("Hips/Torso/ShoulderLeft/HandLeft")
@onready var hand_r: Node3D = get_node_or_null("Hips/Torso/ShoulderRight/HandRight")
@onready var hip_l: Node3D = get_node_or_null("Hips/HipLeft")
@onready var hip_r: Node3D = get_node_or_null("Hips/HipRight")
@onready var eye_left: MeshInstance3D = get_node_or_null("Hips/Torso/Neck/Head/EyeLeft")
@onready var eye_right: MeshInstance3D = get_node_or_null("Hips/Torso/Neck/Head/EyeRight")

# Internal timers & math junk
var anim_time: float = 0.0
var walk_cycle: float = 0.0

# Jacob's Ladder erratic head twitching (violent snap -> jitter -> slow recover)
var twitch_timer: float = 0.0
var twitch_interval: float = 1.8
var twitch_target_rot: Vector3 = Vector3.ZERO
var current_twitch_rot: Vector3 = Vector3.ZERO
var twitch_jitter_duration: float = 0.0

# Default resting transforms
var default_hips_y: float = 1.20
var default_torso_rot: Vector3 = Vector3.ZERO
var default_neck_rot: Vector3 = Vector3.ZERO
var default_jaw_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	if hips:
		default_hips_y = hips.position.y
	if torso:
		default_torso_rot = torso.rotation
	if neck:
		default_neck_rot = neck.rotation
	if jaw_hinge:
		default_jaw_rot = jaw_hinge.rotation

func set_anim_state(state_name: String) -> void:
	match state_name.to_lower():
		"idle":
			current_state = AnimState.IDLE
		"patrol", "walk":
			current_state = AnimState.PATROL
		"investigate":
			current_state = AnimState.INVESTIGATE
		"chase", "run":
			current_state = AnimState.CHASE
		"jumpscare":
			current_state = AnimState.JUMPSCARE

func _process(delta: float) -> void:
	anim_time += delta
	_update_twitch(delta)
	
	match current_state:
		AnimState.IDLE:
			_process_idle(delta)
		AnimState.PATROL:
			_process_patrol(delta)
		AnimState.INVESTIGATE:
			_process_investigate(delta)
		AnimState.CHASE:
			_process_chase(delta)
		AnimState.JUMPSCARE:
			_process_jumpscare(delta)

# -----------------------------------------------------------------------------
# ERRATIC HEAD TWITCH (Jacob's Ladder / J-Horror stutter)
# -----------------------------------------------------------------------------
func _update_twitch(delta: float) -> void:
	twitch_timer += delta
	if twitch_timer >= twitch_interval:
		twitch_timer = 0.0
		# Random erratic twitch intervals (furious twitching during chase!)
		twitch_interval = randf_range(0.8, 2.5) if current_state != AnimState.CHASE else randf_range(0.18, 0.5)
		# Sudden violent angular snap
		twitch_target_rot = Vector3(
			deg_to_rad(randf_range(-18.0, 25.0)),
			deg_to_rad(randf_range(-35.0, 35.0)),
			deg_to_rad(randf_range(-22.0, 22.0))
		)
		twitch_jitter_duration = randf_range(0.12, 0.28)
		
	if twitch_jitter_duration > 0.0:
		twitch_jitter_duration -= delta
		# High frequency buzzing vibration
		var jitter = Vector3(
			randf_range(-0.07, 0.07),
			randf_range(-0.07, 0.07),
			randf_range(-0.07, 0.07)
		)
		current_twitch_rot = twitch_target_rot + jitter
	else:
		# Unsettling slow glide back toward neutral center
		current_twitch_rot = current_twitch_rot.lerp(Vector3.ZERO, delta * 3.5)

# -----------------------------------------------------------------------------
# ANIMATION PROCESSORS
# -----------------------------------------------------------------------------
func _process_idle(delta: float) -> void:
	# Convulsive, ragged breathing with shudder
	var breath = sin(anim_time * 2.2) * 0.04
	var shudder = sin(anim_time * 16.0) * 0.005
	
	if torso:
		torso.rotation = default_torso_rot + Vector3(breath + shudder, 0.0, sin(anim_time * 1.1) * 0.02)
		torso.scale = Vector3(1.0 + breath * 0.4, 1.0 + breath * 0.2, 1.0 + breath * 0.8)
		
	if neck and head:
		neck.rotation = default_neck_rot + Vector3(breath * 0.5, 0.0, 0.0)
		head.rotation = current_twitch_rot
		
	if jaw_hinge:
		# Gaping slack jaw shivering slightly
		var jaw_shiver = sin(anim_time * 9.0) * 0.03 + 0.12
		jaw_hinge.rotation = default_jaw_rot + Vector3(jaw_shiver, 0.0, 0.0)
		
	if shoulder_l and shoulder_r:
		# Limp dangling arms
		shoulder_l.rotation = Vector3(sin(anim_time * 1.3) * 0.05, 0.0, 0.05)
		shoulder_r.rotation = Vector3(cos(anim_time * 1.2) * 0.05, 0.0, -0.05)
		
	if hand_l and hand_r:
		var claw_twitch = sin(anim_time * 4.5) * 0.12 + 0.15
		hand_l.rotation = Vector3(claw_twitch, sin(anim_time * 3.0) * 0.08, 0.0)
		hand_r.rotation = Vector3(claw_twitch, -cos(anim_time * 3.2) * 0.08, 0.0)
		
	if hip_l and hip_r:
		hip_l.rotation = Vector3.ZERO
		hip_r.rotation = Vector3.ZERO

func _process_patrol(delta: float) -> void:
	walk_cycle += delta * 3.6 * walk_speed_factor
	var cycle_sin = sin(walk_cycle)
	var cycle_cos = cos(walk_cycle)
	
	# Asymmetrical shambling limp (one leg collapses downward)
	var limp_drop = abs(cycle_cos) * 0.06
	if hips:
		hips.position.y = default_hips_y - limp_drop
		hips.rotation.y = cycle_sin * 0.08
		hips.rotation.z = cycle_sin * 0.04
		
	if hip_l and hip_r:
		# Left leg has full stride, Right leg drags with limp
		hip_l.rotation.x = cycle_sin * 0.42
		hip_r.rotation.x = -cycle_sin * 0.32 + 0.05
		
	if torso:
		var breath = sin(anim_time * 2.8) * 0.05
		torso.rotation = default_torso_rot + Vector3(0.08 + breath, -cycle_sin * 0.08, cycle_cos * 0.04)
		
	if neck and head:
		neck.rotation = default_neck_rot + Vector3(0.12, cycle_sin * 0.05, 0.0)
		head.rotation = current_twitch_rot
		
	if jaw_hinge:
		var jaw_gawp = abs(cycle_sin) * 0.15 + 0.10
		jaw_hinge.rotation = default_jaw_rot + Vector3(jaw_gawp, 0.0, 0.0)
		
	if shoulder_l and shoulder_r:
		# Uneven counter-swinging arms
		shoulder_l.rotation = Vector3(-cycle_sin * 0.35 + 0.10, 0.0, 0.08)
		shoulder_r.rotation = Vector3(cycle_sin * 0.28 + 0.18, 0.0, -0.06)
		
	if hand_l and hand_r:
		hand_l.rotation = Vector3(abs(cycle_sin) * 0.22 + 0.15, 0.0, 0.0)
		hand_r.rotation = Vector3(abs(cycle_cos) * 0.22 + 0.15, 0.0, 0.0)

func _process_investigate(delta: float) -> void:
	walk_cycle += delta * 2.2
	var cycle_sin = sin(walk_cycle)
	
	if hips:
		hips.position.y = default_hips_y - 0.08
		hips.rotation.y = sin(anim_time * 1.2) * 0.18
		
	if torso:
		torso.rotation = default_torso_rot + Vector3(0.25, 0.0, sin(anim_time * 0.8) * 0.08)
		
	if neck and head:
		# Cock head sideways inquisitively like a predatory owl
		neck.rotation = default_neck_rot + Vector3(0.20, sin(anim_time * 1.5) * 0.25, 0.18)
		head.rotation = current_twitch_rot + Vector3(0.0, 0.0, sin(anim_time * 2.0) * 0.12)
		
	if jaw_hinge:
		jaw_hinge.rotation = default_jaw_rot + Vector3(0.22, 0.0, 0.0)
		
	if shoulder_l and shoulder_r:
		shoulder_l.rotation = Vector3(0.35, -0.15, 0.15)
		shoulder_r.rotation = Vector3(0.40, 0.15, -0.15)
		
	if hand_l and hand_r:
		hand_l.rotation = Vector3(0.35, 0.0, sin(anim_time * 4.0) * 0.15)
		hand_r.rotation = Vector3(0.35, 0.0, -sin(anim_time * 4.0) * 0.15)
		
	if hip_l and hip_r:
		hip_l.rotation.x = cycle_sin * 0.25
		hip_r.rotation.x = -cycle_sin * 0.25

func _process_chase(delta: float) -> void:
	# Frantic horror sprint!
	walk_cycle += delta * 8.5
	var cycle_sin = sin(walk_cycle)
	var cycle_cos = cos(walk_cycle)
	
	# Deep hunched forward posture
	if hips:
		hips.position.y = default_hips_y - 0.14 + abs(cycle_cos) * 0.08
		hips.rotation.y = cycle_sin * 0.14
		hips.rotation.z = cycle_sin * 0.08
		
	if hip_l and hip_r:
		hip_l.rotation.x = cycle_sin * 0.65
		hip_r.rotation.x = -cycle_sin * 0.65
		
	if torso:
		# Thrashing aggressively forward towards player
		var thrash = sin(anim_time * 18.0) * 0.04
		torso.rotation = default_torso_rot + Vector3(0.42 + thrash, -cycle_sin * 0.14, cycle_cos * 0.08)
		
	if neck and head:
		neck.rotation = default_neck_rot + Vector3(0.38, 0.0, 0.0)
		head.rotation = current_twitch_rot + Vector3(sin(anim_time * 22.0) * 0.08, 0.0, 0.0)
		
	if jaw_hinge:
		# Gaping wide shriek / roar
		var roar_gape = sin(anim_time * 12.0) * 0.12 + 0.48
		jaw_hinge.rotation = default_jaw_rot + Vector3(roar_gape, 0.0, 0.0)
		
	if shoulder_l and shoulder_r:
		# Lanky arms thrust forward to claw
		shoulder_l.rotation = Vector3(0.85 + cycle_sin * 0.22, 0.12, 0.10)
		shoulder_r.rotation = Vector3(0.85 - cycle_sin * 0.22, -0.12, -0.10)
		
	if hand_l and hand_r:
		var claw_swipe = sin(anim_time * 14.0) * 0.35 + 0.35
		hand_l.rotation = Vector3(claw_swipe, 0.15, 0.0)
		hand_r.rotation = Vector3(claw_swipe, -0.15, 0.0)

func _process_jumpscare(delta: float) -> void:
	# Violent, frantic lunging right into player's camera screen!
	var violent_shake = Vector3(
		randf_range(-0.15, 0.15),
		randf_range(-0.15, 0.15),
		randf_range(-0.12, 0.12)
	)
	
	if hips:
		hips.position.y = default_hips_y - 0.12 + randf_range(-0.04, 0.04)
		hips.position.z = -0.25
		
	if torso:
		torso.rotation = default_torso_rot + Vector3(0.55, 0.0, 0.0) + violent_shake * 0.5
		
	if neck and head:
		neck.rotation = default_neck_rot + Vector3(0.50, 0.0, 0.0)
		head.rotation = violent_shake * 1.8
		
	if jaw_hinge:
		# Jaw dropped to absolute anatomical maximum
		jaw_hinge.rotation = default_jaw_rot + Vector3(0.65 + randf_range(-0.08, 0.08), 0.0, randf_range(-0.06, 0.06))
		
	if shoulder_l and shoulder_r:
		# Claws wrapping around player's viewport
		shoulder_l.rotation = Vector3(1.15 + violent_shake.x, -0.25, 0.25)
		shoulder_r.rotation = Vector3(1.15 + violent_shake.x, 0.25, -0.25)
		
	if hand_l and hand_r:
		hand_l.rotation = Vector3(0.65, 0.35, 0.0)
		hand_r.rotation = Vector3(0.65, -0.35, 0.0)
