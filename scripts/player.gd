class_name Player
extends CharacterBody3D

const GlobalBus = preload("res://scripts/global_events.gd")

## Hybrid (PC + Mobile) 3D First-Person Horror Player Controller
## Features:
## - Desktop mouse look with body yaw and clamped head pitch
## - Hybrid touch look zone & responsive virtual joystick for mobile / touch
## - Sprinting with stamina consumption and periodic noise emission (alerting Stalkers)
## - Smooth crouching with camera transition and collision height adjustment
## - Realistic sine-wave head bobbing and smooth flashlight sway
## - Raycast interaction system for doors, notes, keys, and puzzles
## - Bear trap root/slow entrapment with mashing escape mechanic
## - Master key inventory tracking, victory, and jumpscare / game over triggers

# --- Mobile / Hybrid Settings ---
@export_group("Hybrid Controls")
@export var force_mobile_ui: bool = false
@export var touch_look_sensitivity: float = 0.0035

# --- Movement Settings ---
@export_group("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var air_acceleration: float = 3.0

# --- Look Settings ---
@export_group("Look")
@export var mouse_sensitivity: float = 0.003
@export var keyboard_turn_speed: float = 2.5
@export var max_pitch_degrees: float = 85.0

# --- Stamina Settings ---
@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0
@export var stamina_regen_rate: float = 18.0
@export var stamina_regen_delay: float = 1.2
@export var sprint_noise_interval: float = 0.35
@export var sprint_noise_radius: float = 14.0

# --- Crouch Settings ---
@export_group("Crouch")
@export var standing_height: float = 2.0
@export var crouch_height: float = 1.2
@export var standing_head_y: float = 1.7
@export var crouch_head_y: float = 1.0
@export var crouch_transition_speed: float = 8.0

# --- Head Bob Settings ---
@export_group("Head Bob")
@export var bob_frequency_walk: float = 10.0
@export var bob_frequency_sprint: float = 14.0
@export var bob_amplitude_walk: float = 0.035
@export var bob_amplitude_sprint: float = 0.06
@export var bob_smooth_speed: float = 10.0

# --- Flashlight Sway Settings ---
@export_group("Flashlight")
@export var flashlight_sway_speed: float = 14.0

# --- Node References ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hybrid_hud: HybridHUD = $HybridHUD
@onready var flashlight_audio: AudioStreamPlayer = $FlashlightAudio

# --- Inventory & State Variables ---
var has_master_key: bool = false
var is_game_ended: bool = false
var current_stamina: float = 100.0
var stamina_regen_timer: float = 0.0
var sprint_noise_timer: float = 0.0
var is_crouching: bool = false
var is_sprinting: bool = false
var is_reading_note: bool = false
var camera_pitch: float = 0.0

# Mobile states
var is_mobile_sprinting: bool = false
var is_mobile_crouching: bool = false

# Trap state
var is_trapped: bool = false
var trap_timer: float = 0.0
var trap_speed_mult: float = 1.0
var trap_mash_count: int = 0
var trap_mash_needed: int = 4

var bob_timer: float = 0.0
var current_bob_offset: Vector3 = Vector3.ZERO
var current_interactable: Interactable = null

func _ready() -> void:
	# Add to "player" group for enemy detection and interaction
	add_to_group("player")
	
	current_stamina = max_stamina
	var is_mobile = DisplayServer.is_touchscreen_available() or force_mobile_ui
	
	# Desktop mouse capture logic: ONLY capture mouse when NOT on touch/mobile
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Setup and bind HybridHUD signals
	if hybrid_hud:
		hybrid_hud.set_mobile_mode(is_mobile)
		hybrid_hud.camera_look_dragged.connect(_on_touch_look_dragged)
		hybrid_hud.interact_requested.connect(_on_mobile_interact_requested)
		hybrid_hud.flashlight_toggled.connect(toggle_flashlight)
		hybrid_hud.sprint_changed.connect(func(sprint_val): is_mobile_sprinting = sprint_val)
		hybrid_hud.crouch_toggled.connect(func(crouch_val): is_mobile_crouching = crouch_val)
		hybrid_hud.update_stamina(current_stamina, max_stamina)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_ended:
		return
		
	# Click window to capture mouse if desktop and uncaptured
	if event is InputEventMouseButton and event.pressed:
		var is_mobile = DisplayServer.is_touchscreen_available() or force_mobile_ui
		if not is_mobile and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not is_reading_note:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# Note overlay takes priority for closing
	if is_reading_note:
		if (event.is_action_pressed("interact") or event.is_action_pressed("pause")) and not event.is_echo():
			close_note()
			get_viewport().set_input_as_handled()
		return

	# Toggle mouse capture / pause on desktop
	if event.is_action_pressed("pause") and not event.is_echo():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			var is_mobile = DisplayServer.is_touchscreen_available() or force_mobile_ui
			if not is_mobile:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# PC Mouse Look Rotation (Y-axis root yaw, X-axis head pitch)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right rotates the CharacterBody3D root on the Y-axis
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Up/down rotates the Head on the X-axis clamped -85 to +85 degrees
		var max_pitch = deg_to_rad(max_pitch_degrees)
		camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -max_pitch, max_pitch)
		head.rotation.x = camera_pitch
		get_viewport().set_input_as_handled()

func _on_touch_look_dragged(relative: Vector2) -> void:
	if is_game_ended or is_reading_note:
		return
	# Touch-look rotation: body Y yaw and head X pitch
	rotate_y(-relative.x * touch_look_sensitivity)
	var max_pitch = deg_to_rad(max_pitch_degrees)
	camera_pitch = clamp(camera_pitch - relative.y * touch_look_sensitivity, -max_pitch, max_pitch)
	head.rotation.x = camera_pitch

func _process(delta: float) -> void:
	if is_game_ended or is_reading_note:
		return
	
	# Flashlight PC toggle
	if Input.is_action_just_pressed("flashlight"):
		toggle_flashlight()
	
	# Flashlight subtle sway
	_process_flashlight_sway(delta)

func _physics_process(delta: float) -> void:
	if is_game_ended or is_reading_note:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Keyboard turning fallback (Left / Right arrow keys)
	var turn_dir: float = 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		turn_dir += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		turn_dir -= 1.0
	if turn_dir != 0.0:
		rotate_y(turn_dir * keyboard_turn_speed * delta)

	_handle_trap_status(delta)
	_handle_gravity(delta)
	_handle_crouch(delta)
	_handle_stamina_and_sprint(delta)
	_handle_movement(delta)
	_handle_head_bob(delta)
	_handle_interaction()
	
	move_and_slide()

# --- Movement & Physics ---
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching and not is_trapped:
		velocity.y = jump_velocity

func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch") or is_mobile_crouching
	
	var target_head_y = crouch_head_y if is_crouching else standing_head_y
	head.position.y = lerp(head.position.y, target_head_y, crouch_transition_speed * delta)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		var target_height = crouch_height if is_crouching else standing_height
		capsule.height = lerp(capsule.height, target_height, crouch_transition_speed * delta)
		collision_shape.position.y = capsule.height * 0.5

func _handle_stamina_and_sprint(delta: float) -> void:
	var wants_sprint = (Input.is_action_pressed("sprint") or is_mobile_sprinting) and not is_trapped
	var joy_vec = hybrid_hud.get_joystick_vector() if hybrid_hud else Vector2.ZERO
	var kb_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var has_input = (kb_vec.length() > 0.1 or joy_vec.length() > 0.1)
	
	if wants_sprint and has_input and is_on_floor() and not is_crouching and current_stamina > 0.0:
		is_sprinting = true
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		stamina_regen_timer = stamina_regen_delay
		
		# Emit noise while sprinting to alert the Stalker
		sprint_noise_timer -= delta
		if sprint_noise_timer <= 0.0:
			sprint_noise_timer = sprint_noise_interval
			GlobalBus.emit_noise(global_position, sprint_noise_radius)
	else:
		is_sprinting = false
		sprint_noise_timer = 0.0
		if stamina_regen_timer > 0.0:
			stamina_regen_timer -= delta
		elif current_stamina < max_stamina:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	
	if hybrid_hud:
		hybrid_hud.update_stamina(current_stamina, max_stamina)

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if hybrid_hud:
		var joy = hybrid_hud.get_joystick_vector()
		if joy.length_squared() > 0.01:
			input_dir = joy

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = walk_speed
	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting and current_stamina > 0.0:
		current_speed = sprint_speed
		
	if is_trapped:
		current_speed *= trap_speed_mult
	
	var accel = acceleration if is_on_floor() else air_acceleration
	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, accel * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, accel * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, accel * delta)
		velocity.z = lerp(velocity.z, 0.0, accel * delta)

# --- Trap System ---
func trap_player(duration: float, speed_mult: float, mash_needed: int = 4) -> void:
	is_trapped = true
	trap_timer = duration
	trap_speed_mult = speed_mult
	trap_mash_count = 0
	trap_mash_needed = mash_needed
	if hybrid_hud:
		hybrid_hud.set_trapped(true, trap_mash_count, trap_mash_needed)

func _handle_trap_status(delta: float) -> void:
	if not is_trapped:
		return
	
	trap_timer -= delta
	if trap_timer <= 0.0:
		untrap_player()

func untrap_player() -> void:
	is_trapped = false
	trap_speed_mult = 1.0
	if hybrid_hud:
		hybrid_hud.set_trapped(false)

# --- Head Bobbing ---
func _handle_head_bob(delta: float) -> void:
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var on_ground = is_on_floor() and horizontal_speed > 0.1
	
	if on_ground:
		var freq = bob_frequency_sprint if is_sprinting else bob_frequency_walk
		var amp = bob_amplitude_sprint if is_sprinting else bob_amplitude_walk
		if is_crouching:
			amp *= 0.5
		if is_trapped:
			amp *= 0.2
		
		bob_timer += delta * freq
		var target_bob_y = sin(bob_timer) * amp
		var target_bob_x = cos(bob_timer * 0.5) * (amp * 0.5)
		current_bob_offset = current_bob_offset.lerp(Vector3(target_bob_x, target_bob_y, 0), bob_smooth_speed * delta)
	else:
		current_bob_offset = current_bob_offset.lerp(Vector3.ZERO, bob_smooth_speed * delta)
	
	camera.position = current_bob_offset

# --- Flashlight ---
func toggle_flashlight() -> void:
	if not flashlight:
		return
	flashlight.visible = not flashlight.visible
	if flashlight_audio:
		flashlight_audio.play()

func _process_flashlight_sway(delta: float) -> void:
	if not flashlight:
		return
	var target_basis = camera.global_transform.basis
	flashlight.global_transform.basis = flashlight.global_transform.basis.slerp(target_basis, flashlight_sway_speed * delta)

# --- Interaction System ---
func _handle_interaction() -> void:
	current_interactable = _find_interactable()
	
	if current_interactable and current_interactable.can_interact:
		if hybrid_hud:
			hybrid_hud.update_interaction_prompt(true, "[E] " + current_interactable.get_prompt())
		
		if Input.is_action_just_pressed("interact"):
			_trigger_interact()
	else:
		if hybrid_hud:
			hybrid_hud.update_interaction_prompt(false)

func _trigger_interact() -> void:
	# If trapped in bear trap, interaction mashing helps break free
	if is_trapped:
		trap_mash_count += 1
		if hybrid_hud:
			hybrid_hud.set_trapped(true, trap_mash_count, trap_mash_needed)
		if trap_mash_count >= trap_mash_needed:
			untrap_player()
		return
		
	if current_interactable and current_interactable.can_interact:
		current_interactable.interact(self)

func _on_mobile_interact_requested() -> void:
	_trigger_interact()

func _find_interactable() -> Interactable:
	if not interaction_ray or not interaction_ray.is_colliding():
		return null
	
	var col = interaction_ray.get_collider()
	if not col:
		return null
	
	if col is Interactable:
		return col
	
	var parent = col.get_parent()
	while parent != null:
		if parent is Interactable:
			return parent
		parent = parent.get_parent()
	
	if col.owner is Interactable:
		return col.owner
	
	return null

# --- Note Overlay Handling ---
func display_note(title: String, content: String) -> void:
	is_reading_note = true
	if hybrid_hud:
		hybrid_hud.display_note(title, content)

func close_note() -> void:
	is_reading_note = false
	if hybrid_hud:
		hybrid_hud.close_note()

# --- Key, Victory & Game Over ---
func obtain_master_key() -> void:
	has_master_key = true
	if hybrid_hud:
		hybrid_hud.show_key_obtained()

func trigger_victory() -> void:
	if is_game_ended:
		return
	is_game_ended = true
	velocity = Vector3.ZERO
	if hybrid_hud:
		hybrid_hud.show_victory()
	GlobalBus.notify_escaped()

func trigger_game_over(stalker_source: Node3D = null) -> void:
	if is_game_ended:
		return
	is_game_ended = true
	velocity = Vector3.ZERO
	if stalker_source and camera:
		# Snap camera view to face the monster
		camera.look_at(stalker_source.global_position + Vector3.UP * 1.5, Vector3.UP)
	if hybrid_hud:
		hybrid_hud.show_game_over()
	GlobalBus.notify_caught()
