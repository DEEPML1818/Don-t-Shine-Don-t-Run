class_name PressurePlateGrid
extends Node3D

const GlobalBus = preload("res://scripts/global_events.gd")

## Multi-Plate Floor Puzzle for Warehouse Secret Corridors
## Stepping on plates in the configured sequence lights them green.
## Stepping on the wrong plate flashes red, resets the sequence, and emits noise.
## Completing the sequence opens connected TrackShelf units.

signal puzzle_completed()

@export var target_shelves: Array[TrackShelf] = []
@export var sequence: Array[int] = [0, 2, 1, 3]

@onready var audio_step: AudioStreamPlayer3D = $AudioStep
@onready var audio_error: AudioStreamPlayer3D = $AudioError
@onready var audio_solve: AudioStreamPlayer3D = $AudioSolve

var plates: Array[Area3D] = []
var plate_materials: Array[StandardMaterial3D] = []
var initial_plate_y: Array[float] = []

var current_step: int = 0
var is_solved: bool = false
var is_resetting: bool = false

const COLOR_UNLIT: Color = Color(0.15, 0.18, 0.2, 1.0)
const COLOR_CORRECT: Color = Color(0.1, 1.0, 0.25, 1.0)
const COLOR_ERROR: Color = Color(1.0, 0.1, 0.1, 1.0)

func _ready() -> void:
	# Find all child Area3D plate nodes
	for child in get_children():
		if child is Area3D and child.name.begins_with("Plate"):
			var idx = plates.size()
			plates.append(child)
			initial_plate_y.append(child.position.y)
			
			# Setup unique emissive material for each plate's indicator ring
			var ring_mesh: MeshInstance3D = child.get_node_or_null("IndicatorRing")
			if ring_mesh:
				var mat: StandardMaterial3D = StandardMaterial3D.new()
				mat.albedo_color = COLOR_UNLIT
				mat.emission_enabled = false
				mat.emission = COLOR_UNLIT
				mat.emission_energy_multiplier = 0.0
				ring_mesh.material_override = mat
				plate_materials.append(mat)
			else:
				plate_materials.append(null)
			
			child.body_entered.connect(func(body): _on_plate_stepped(idx, body))

func _on_plate_stepped(plate_idx: int, body: Node3D) -> void:
	if is_solved or is_resetting:
		return
		
	if not (body is Player):
		return
		
	var expected_plate = sequence[current_step]
	if plate_idx == expected_plate:
		# Correct sequence step
		_set_plate_visual(plate_idx, COLOR_CORRECT, 2.5, true)
		_press_plate_down(plate_idx)
		if audio_step:
			audio_step.play()
			
		current_step += 1
		if current_step >= sequence.size():
			_solve_puzzle()
	else:
		# Wrong step: flash red, buzz, emit noise, and reset
		_trigger_error(plate_idx)

func _press_plate_down(idx: int) -> void:
	if idx < plates.size():
		var p = plates[idx]
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "position:y", initial_plate_y[idx] - 0.04, 0.1)

func _solve_puzzle() -> void:
	is_solved = true
	if audio_solve:
		audio_solve.play()
		
	# Light all plates bright green
	for i in range(plates.size()):
		_set_plate_visual(i, COLOR_CORRECT, 3.5, true)
		
	# Open all connected track shelves
	for shelf in target_shelves:
		if is_instance_valid(shelf):
			shelf.open_shelf()
			
	puzzle_completed.emit()

func _trigger_error(failed_plate_idx: int) -> void:
	is_resetting = true
	if audio_error:
		audio_error.play()
		
	# Alert nearby Stalkers to the buzzer noise
	GlobalBus.emit_noise(global_position, 18.0)
	
	# Flash red
	_set_plate_visual(failed_plate_idx, COLOR_ERROR, 3.5, true)
	
	# Reset sequence after delay
	var timer = get_tree().create_timer(0.7)
	timer.timeout.connect(_reset_grid)

func _reset_grid() -> void:
	current_step = 0
	for i in range(plates.size()):
		_set_plate_visual(i, COLOR_UNLIT, 0.0, false)
		# Spring plate back up
		var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(plates[i], "position:y", initial_plate_y[i], 0.3)
	is_resetting = false

func _set_plate_visual(idx: int, color: Color, energy: float, emissive: bool) -> void:
	if idx < plate_materials.size() and plate_materials[idx] != null:
		var mat = plate_materials[idx]
		mat.albedo_color = color
		mat.emission_enabled = emissive
		mat.emission = color
		mat.emission_energy_multiplier = energy
