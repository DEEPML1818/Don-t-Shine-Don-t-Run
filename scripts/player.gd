class_name Player
extends CharacterBody3D

## 3D First-Person Horror Player Controller
## Features:
## - Smooth mouse-look with vertical clamp
## - Acceleration/friction WASD movement and jump
## - Sprinting with stamina consumption and delayed regeneration
## - Smooth crouching with camera and collision height scaling
## - Realistic sine-wave head bobbing
## - Flashlight with subtle realistic lag/sway
## - Raycast interaction system for doors, notes, and items
## - Readable note UI overlay and HUD

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
@export var mouse_sensitivity: float = 0.002
@export var max_pitch_degrees: float = 85.0

# --- Stamina Settings ---
@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0
@export var stamina_regen_rate: float = 18.0
@export var stamina_regen_delay: float = 1.2

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

# --- HUD References ---
@onready var crosshair: Control = $HUD/Crosshair
@onready var interaction_prompt: Label = $HUD/InteractionPrompt
@onready var stamina_bar: ProgressBar = $HUD/StaminaContainer/StaminaBar
@onready var note_overlay: Control = $HUD/NoteOverlay
@onready var note_title_label: Label = $HUD/NoteOverlay/PaperPanel/MarginContainer/VBoxContainer/NoteTitle
@onready var note_content_label: Label = $HUD/NoteOverlay/PaperPanel/MarginContainer/VBoxContainer/NoteContent
@onready var note_close_label: Label = $HUD/NoteOverlay/PaperPanel/MarginContainer/VBoxContainer/CloseHint

# --- State Variables ---
var current_stamina: float = 100.0
var stamina_regen_timer: float = 0.0
var is_crouching: bool = false
var is_sprinting: bool = false
var is_reading_note: bool = false

var bob_timer: float = 0.0
var current_bob_offset: Vector3 = Vector3.ZERO
var current_interactable: Interactable = null

func _ready() -> void:
	# Capture mouse cursor on game start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_stamina = max_stamina
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	
	if interaction_prompt:
		interaction_prompt.visible = false
	if note_overlay:
		note_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Note overlay takes priority for closing
	if is_reading_note:
		if (event.is_action_pressed("interact") or event.is_action_pressed("pause")) and not event.is_echo():
			close_note()
			get_viewport().set_input_as_handled()
		return

	# Toggle mouse capture / pause
	if event.is_action_pressed("pause") and not event.is_echo():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# Mouse look rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw (left/right on body)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Pitch (up/down on head/camera)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		var max_pitch = deg_to_rad(max_pitch_degrees)
		head.rotation.x = clamp(head.rotation.x, -max_pitch, max_pitch)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_reading_note:
		return
	
	# Flashlight toggle
	if Input.is_action_just_pressed("flashlight") and flashlight:
		flashlight.visible = not flashlight.visible
	
	# Flashlight subtle sway
	_process_flashlight_sway(delta)

func _physics_process(delta: float) -> void:
	if is_reading_note:
		# Freeze velocity when reading note
		velocity = Vector3.ZERO
		move_and_slide()
		return

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
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity

func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	
	var target_head_y = crouch_head_y if is_crouching else standing_head_y
	head.position.y = lerp(head.position.y, target_head_y, crouch_transition_speed * delta)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		var target_height = crouch_height if is_crouching else standing_height
		capsule.height = lerp(capsule.height, target_height, crouch_transition_speed * delta)
		collision_shape.position.y = capsule.height * 0.5

func _handle_stamina_and_sprint(delta: float) -> void:
	var wants_sprint = Input.is_action_pressed("sprint")
	var has_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length() > 0.1
	
	if wants_sprint and has_input and is_on_floor() and not is_crouching and current_stamina > 0.0:
		is_sprinting = true
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		stamina_regen_timer = stamina_regen_delay
	else:
		is_sprinting = false
		if stamina_regen_timer > 0.0:
			stamina_regen_timer -= delta
		elif current_stamina < max_stamina:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	
	if stamina_bar:
		stamina_bar.value = current_stamina
		# Subtle opacity effect: only fully visible when depleted or recovering
		var target_alpha = 1.0 if current_stamina < max_stamina * 0.99 else 0.35
		stamina_bar.modulate.a = lerp(stamina_bar.modulate.a, target_alpha, delta * 6.0)

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = walk_speed
	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting and current_stamina > 0.0:
		current_speed = sprint_speed
	
	var accel = acceleration if is_on_floor() else air_acceleration
	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, accel * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, accel * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, accel * delta)
		velocity.z = lerp(velocity.z, 0.0, accel * delta)

# --- Head Bobbing ---
func _handle_head_bob(delta: float) -> void:
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var on_ground = is_on_floor() and horizontal_speed > 0.1
	
	if on_ground:
		var freq = bob_frequency_sprint if is_sprinting else bob_frequency_walk
		var amp = bob_amplitude_sprint if is_sprinting else bob_amplitude_walk
		if is_crouching:
			amp *= 0.5
		
		bob_timer += delta * freq
		var target_bob_y = sin(bob_timer) * amp
		var target_bob_x = cos(bob_timer * 0.5) * (amp * 0.5)
		current_bob_offset = current_bob_offset.lerp(Vector3(target_bob_x, target_bob_y, 0), bob_smooth_speed * delta)
	else:
		# Return smoothly to center
		current_bob_offset = current_bob_offset.lerp(Vector3.ZERO, bob_smooth_speed * delta)
	
	camera.position = current_bob_offset

# --- Flashlight Sway ---
func _process_flashlight_sway(delta: float) -> void:
	if not flashlight:
		return
	# Slerp the flashlight rotation slightly behind the camera for an immersive fluid feel
	var target_basis = camera.global_transform.basis
	flashlight.global_transform.basis = flashlight.global_transform.basis.slerp(target_basis, flashlight_sway_speed * delta)

# --- Interaction System ---
func _handle_interaction() -> void:
	current_interactable = _find_interactable()
	
	if current_interactable and current_interactable.can_interact:
		if interaction_prompt:
			interaction_prompt.text = "[E] " + current_interactable.get_prompt()
			interaction_prompt.visible = true
		if crosshair:
			crosshair.modulate = Color(1.0, 0.9, 0.5, 1.0) # Warm highlight on interactable
		
		if Input.is_action_just_pressed("interact"):
			current_interactable.interact(self)
	else:
		if interaction_prompt:
			interaction_prompt.visible = false
		if crosshair:
			crosshair.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _find_interactable() -> Interactable:
	if not interaction_ray or not interaction_ray.is_colliding():
		return null
	
	var col = interaction_ray.get_collider()
	if not col:
		return null
	
	# Check collider directly
	if col is Interactable:
		return col
	
	# Check parent hierarchy (useful for multi-node props or composite prefabs)
	var parent = col.get_parent()
	while parent != null:
		if parent is Interactable:
			return parent
		parent = parent.get_parent()
	
	# Check scene owner
	if col.owner is Interactable:
		return col.owner
	
	return null

# --- Note Overlay Handling ---
func display_note(title: String, content: String) -> void:
	is_reading_note = true
	if note_title_label:
		note_title_label.text = title
	if note_content_label:
		note_content_label.text = content
	if note_close_label:
		note_close_label.text = "[E] or [Esc] to Close"
	if note_overlay:
		note_overlay.visible = true
	if interaction_prompt:
		interaction_prompt.visible = false

func close_note() -> void:
	is_reading_note = false
	if note_overlay:
		note_overlay.visible = false
