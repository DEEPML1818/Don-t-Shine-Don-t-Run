class_name HybridHUD
extends CanvasLayer

## Comprehensive Hybrid (PC + Mobile) HUD & Controls Manager
## Handles HUD elements, responsive mobile virtual controls, and victory/game-over screens.

signal camera_look_dragged(relative: Vector2)
signal interact_requested()
signal flashlight_toggled()
signal sprint_changed(is_sprinting: bool)
signal crouch_toggled(is_crouching: bool)

@onready var hud_root: Control = $HUDRoot
@onready var crosshair: Control = $HUDRoot/Crosshair
@onready var interaction_prompt: Label = $HUDRoot/InteractionPrompt
@onready var stamina_container: Control = $HUDRoot/StaminaContainer
@onready var stamina_bar: ProgressBar = $HUDRoot/StaminaContainer/StaminaBar
@onready var key_indicator: Control = $HUDRoot/KeyIndicator
@onready var trapped_banner: Label = $HUDRoot/TrappedBanner

# Mobile Controls
@onready var mobile_controls: Control = $HUDRoot/MobileControls
@onready var virtual_joystick: MobileVirtualJoystick = $HUDRoot/MobileControls/VirtualJoystick
@onready var touch_look_zone: TouchLookZone = $HUDRoot/MobileControls/TouchLookZone
@onready var btn_interact: Button = $HUDRoot/MobileControls/ActionButtons/BtnInteract
@onready var btn_flashlight: Button = $HUDRoot/MobileControls/ActionButtons/BtnFlashlight
@onready var btn_sprint: Button = $HUDRoot/MobileControls/ActionButtons/BtnSprint
@onready var btn_crouch: Button = $HUDRoot/MobileControls/ActionButtons/BtnCrouch

# Overlays
@onready var note_overlay: Control = $HUDRoot/NoteOverlay
@onready var note_title_label: Label = $HUDRoot/NoteOverlay/PaperPanel/MarginContainer/VBoxContainer/NoteTitle
@onready var note_content_label: Label = $HUDRoot/NoteOverlay/PaperPanel/MarginContainer/VBoxContainer/NoteContent
@onready var victory_overlay: Control = $HUDRoot/VictoryOverlay
@onready var game_over_overlay: Control = $HUDRoot/GameOverOverlay

var is_mobile_active: bool = false
var is_crouching_toggled: bool = false

func _ready() -> void:
	# Ensure all root full-screen HUD containers ignore mouse filter for desktop look
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if key_indicator:
		key_indicator.visible = false
	if trapped_banner:
		trapped_banner.visible = false
	if victory_overlay:
		victory_overlay.visible = false
	if game_over_overlay:
		game_over_overlay.visible = false
	if note_overlay:
		note_overlay.visible = false

	# Connect mobile touch-look zone
	if touch_look_zone:
		touch_look_zone.look_dragged.connect(func(rel): camera_look_dragged.emit(rel))
	
	# Connect mobile action buttons
	if btn_interact:
		btn_interact.pressed.connect(func(): interact_requested.emit())
	if btn_flashlight:
		btn_flashlight.pressed.connect(func(): flashlight_toggled.emit())
	if btn_sprint:
		btn_sprint.button_down.connect(func(): sprint_changed.emit(true))
		btn_sprint.button_up.connect(func(): sprint_changed.emit(false))
	if btn_crouch:
		btn_crouch.pressed.connect(_on_crouch_button_pressed)

func set_mobile_mode(enable: bool) -> void:
	is_mobile_active = enable
	if mobile_controls:
		mobile_controls.visible = enable

func get_joystick_vector() -> Vector2:
	if not is_mobile_active or not virtual_joystick:
		return Vector2.ZERO
	return virtual_joystick.get_output()

func _on_crouch_button_pressed() -> void:
	is_crouching_toggled = not is_crouching_toggled
	if btn_crouch:
		if is_crouching_toggled:
			btn_crouch.modulate = Color(1.0, 0.8, 0.3, 1.0)
		else:
			btn_crouch.modulate = Color.WHITE
	crouch_toggled.emit(is_crouching_toggled)

# --- Dynamic HUD Feedback ---
func update_interaction_prompt(visible_flag: bool, text: String = "") -> void:
	if interaction_prompt:
		interaction_prompt.visible = visible_flag
		interaction_prompt.text = text
	if crosshair:
		crosshair.modulate = Color(1.0, 0.85, 0.3, 1.0) if visible_flag else Color(1, 1, 1, 0.6)

func update_stamina(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
		var target_alpha = 1.0 if current < maximum * 0.99 else 0.35
		stamina_bar.modulate.a = lerp(stamina_bar.modulate.a, target_alpha, 0.15)

func show_key_obtained() -> void:
	if key_indicator:
		key_indicator.visible = true
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		key_indicator.scale = Vector2(1.5, 1.5)
		tween.tween_property(key_indicator, "scale", Vector2.ONE, 0.5)

func set_trapped(trapped: bool, escape_count: int = 0, escape_needed: int = 4) -> void:
	if trapped_banner:
		trapped_banner.visible = trapped
		if trapped:
			trapped_banner.text = "TRAPPED IN BEAR TRAP!\nMash [E] to escape (%d/%d)" % [escape_count, escape_needed]

func display_note(title: String, content: String) -> void:
	if note_title_label:
		note_title_label.text = title
	if note_content_label:
		note_content_label.text = content
	if note_overlay:
		note_overlay.visible = true

func close_note() -> void:
	if note_overlay:
		note_overlay.visible = false

func show_victory() -> void:
	if victory_overlay:
		victory_overlay.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_game_over() -> void:
	if game_over_overlay:
		game_over_overlay.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
