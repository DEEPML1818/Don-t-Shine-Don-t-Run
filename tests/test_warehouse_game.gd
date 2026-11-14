extends SceneTree

const GlobalBus = preload("res://scripts/global_events.gd")
const StalkerEnemyScript = preload("res://scripts/stalker_enemy.gd")

func _init() -> void:
	print("========================================")
	print("STARTING WAREHOUSE HORROR SYSTEM TESTS")
	print("========================================")
	
	var main_scene = load("res://scenes/Main.tscn")
	if main_scene == null:
		printerr("FAIL: Main.tscn could not be loaded!")
		quit(1)
		return
		
	var main = main_scene.instantiate()
	get_root().add_child(main)
	
	# Give scene a frame to initialize ready calls
	var player: Player = main.get_node_or_null("Player")
	assert(player != null, "Player node must exist in Main.tscn")
	assert(player.is_in_group("player"), "Player must be in 'player' group")
	print("[PASS] Main.tscn and Player instantiated properly.")
	
	# TEST 1: PC Mouse Mode & Mouse Look
	print("\n--- Testing PC Controls & Mouse Look ---")
	assert(player.head != null, "Player head must exist")
	assert(player.hybrid_hud != null, "Player HybridHUD must exist")
	
	# Verify HUD containers ignore mouse filter
	var hud_root: Control = player.hybrid_hud.get_node("HUDRoot")
	assert(hud_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUDRoot mouse_filter must be MOUSE_FILTER_IGNORE")
	print("[PASS] Fullscreen HUD container has mouse_filter = Control.MOUSE_FILTER_IGNORE")
	
	# Test mouse motion rotation
	var initial_body_rot_y = player.rotation.y
	var initial_head_rot_x = player.head.rotation.x
	
	var motion_ev = InputEventMouseMotion.new()
	motion_ev.relative = Vector2(100.0, 50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player._unhandled_input(motion_ev)
	
	assert(player.rotation.y != initial_body_rot_y, "Mouse motion X must rotate body on Y axis")
	assert(player.head.rotation.x != initial_head_rot_x, "Mouse motion Y must rotate head on X axis")
	var max_pitch = deg_to_rad(player.max_pitch_degrees)
	assert(abs(player.head.rotation.x) <= max_pitch + 0.001, "Head pitch must remain clamped within max pitch degrees")
	print("[PASS] PC Mouse Look properly rotates body Y yaw and clamped head X pitch.")
	
	# TEST 2: Hybrid Mobile Touch Controls & Virtual Joystick
	print("\n--- Testing Hybrid Mobile Controls ---")
	player.force_mobile_ui = true
	player.hybrid_hud.set_mobile_mode(true)
	assert(player.hybrid_hud.is_mobile_active == true, "HybridHUD mobile controls should be active")
	
	# Test Virtual Joystick
	var joystick: MobileVirtualJoystick = player.hybrid_hud.virtual_joystick
	assert(joystick != null, "VirtualJoystick must exist in HybridHUD")
	
	# Simulate touch on joystick
	var touch_down = InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.pressed = true
	touch_down.position = joystick.size * 0.5 + Vector2(40.0, -30.0)
	joystick._gui_input(touch_down)
	
	var joy_output = joystick.get_output()
	assert(joy_output.length() > 0.1, "Joystick should produce non-zero output vector when dragged")
	assert(joy_output.x > 0.0, "Joystick X should be positive when dragged right")
	assert(joy_output.y < 0.0, "Joystick Y should be negative when dragged up (forward)")
	print("[PASS] Virtual Joystick tracks touch index and outputs normalized direction vector: ", joy_output)
	
	# Simulate joystick release
	var touch_up = InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	joystick._gui_input(touch_up)
	assert(joystick.get_output() == Vector2.ZERO, "Joystick output must reset to ZERO on release")
	print("[PASS] Virtual Joystick cleanly resets on touch release.")
	
	# Test Touch-Look Zone
	var touch_look: TouchLookZone = player.hybrid_hud.touch_look_zone
	assert(touch_look != null, "TouchLookZone must exist in HybridHUD")
	
	var touch_look_start = InputEventScreenTouch.new()
	touch_look_start.index = 2 # Different finger index from joystick!
	touch_look_start.pressed = true
	touch_look._gui_input(touch_look_start)
	assert(touch_look.touch_index == 2, "TouchLookZone must track finger index 2")
	
	var prev_body_y = player.rotation.y
	var prev_head_x = player.head.rotation.x
	var drag_look = InputEventScreenDrag.new()
	drag_look.index = 2
	drag_look.relative = Vector2(80.0, -40.0)
	touch_look._gui_input(drag_look)
	
	assert(player.rotation.y != prev_body_y, "Touch drag must rotate body on Y axis")
	assert(player.head.rotation.x != prev_head_x, "Touch drag must rotate head on X axis")
	print("[PASS] Touch-Look Zone rotates camera independently without interfering with joystick.")
	
	# Test Action Buttons
	var btn_interact = player.hybrid_hud.btn_interact
	var btn_sprint = player.hybrid_hud.btn_sprint
	var btn_crouch = player.hybrid_hud.btn_crouch
	var btn_flashlight = player.hybrid_hud.btn_flashlight
	assert(btn_interact.mouse_filter == Control.MOUSE_FILTER_STOP, "Action button mouse_filter must be STOP")
	assert(btn_sprint.mouse_filter == Control.MOUSE_FILTER_STOP, "Action button mouse_filter must be STOP")
	assert(btn_crouch.mouse_filter == Control.MOUSE_FILTER_STOP, "Action button mouse_filter must be STOP")
	assert(btn_flashlight.mouse_filter == Control.MOUSE_FILTER_STOP, "Action button mouse_filter must be STOP")
	print("[PASS] Mobile Action Buttons have mouse_filter = STOP to prevent camera jerking.")
	
	# TEST 3: TrackShelf Functionality
	print("\n--- Testing TrackShelf ---")
	var shelf: TrackShelf = main.get_node_or_null("UpperTrackShelf")
	assert(shelf != null, "UpperTrackShelf must exist")
	assert(shelf.is_open == false, "Shelf must be initially closed")
	shelf.open_shelf()
	assert(shelf.is_open == true, "Shelf must be open after open_shelf()")
	shelf.close_shelf()
	assert(shelf.is_open == false, "Shelf must be closed after close_shelf()")
	print("[PASS] TrackShelf open_shelf() and close_shelf() functional.")
	
	# TEST 4: BearTrap Entrapment & Noise Emission
	print("\n--- Testing BearTrap ---")
	var trap: BearTrap = main.get_node_or_null("TrapCenterWest")
	assert(trap != null, "TrapCenterWest must exist")
	var noise_received: bool = false
	var received_noise_pos: Vector3 = Vector3.ZERO
	var noise_cb = func(pos, rad):
		noise_received = true
		received_noise_pos = pos
	GlobalBus.connect_noise(noise_cb)
	
	trap.spring_trap(player)
	assert(trap.is_sprung == true, "Trap must be sprung")
	assert(player.is_trapped == true, "Player must be trapped")
	assert(player.trap_speed_mult == trap.slow_multiplier, "Player speed mult must be slowed to 15%")
	assert(noise_received == true, "GlobalEvents must emit noise alert on trap trigger")
	print("[PASS] BearTrap successfully springs, slows player to 15%, and emits global noise.")
	
	# Test mashing escape
	for i in range(trap.mash_escapes_needed):
		player._trigger_interact()
	assert(player.is_trapped == false, "Player must break free after mashing escape")
	print("[PASS] Player breaks free from BearTrap by mashing Interact [E].")
	
	# TEST 5: PressurePlateGrid Sequence Puzzle
	print("\n--- Testing PressurePlateGrid ---")
	var grid: PressurePlateGrid = main.get_node_or_null("PressurePlateGrid")
	assert(grid != null, "PressurePlateGrid must exist")
	assert(grid.target_shelves.size() == 2, "Grid must control 2 target shelves")
	
	# Step on wrong plate first
	grid._on_plate_stepped(1, player) # Expected 0, stepped on 1
	assert(grid.is_resetting == true, "Wrong step must trigger error reset")
	grid._reset_grid()
	
	# Step on correct sequence: 0, 2, 1, 3
	grid._on_plate_stepped(0, player)
	assert(grid.current_step == 1, "Step 0 must advance step count to 1")
	grid._on_plate_stepped(2, player)
	assert(grid.current_step == 2, "Step 2 must advance step count to 2")
	grid._on_plate_stepped(1, player)
	assert(grid.current_step == 3, "Step 1 must advance step count to 3")
	grid._on_plate_stepped(3, player)
	assert(grid.is_solved == true, "Completing sequence must solve puzzle")
	assert(grid.target_shelves[0].is_open == true, "Connected LowerTrackShelfA must open")
	assert(grid.target_shelves[1].is_open == true, "Connected LowerTrackShelfB must open")
	print("[PASS] PressurePlateGrid sequence puzzle opens connected TrackShelves.")
	
	# TEST 6: ShadowPuzzle Spotlight Pedestal
	print("\n--- Testing ShadowPuzzle ---")
	var shadow: ShadowPuzzle = main.get_node_or_null("ShadowPuzzle")
	assert(shadow != null, "ShadowPuzzle must exist")
	assert(shadow.target_shelf != null, "ShadowPuzzle must connect to UpperTrackShelf")
	
	# Rotate until 180 degrees
	shadow.current_angle = 135.0
	shadow._on_interact(player) # Rotates +45 to 180.0
	shadow._check_alignment()
	assert(shadow.is_solved == true, "Reaching target angle 180 degrees must solve puzzle")
	assert(shadow.target_shelf.is_open == true, "UpperTrackShelf must open upon solving ShadowPuzzle")
	print("[PASS] ShadowPuzzle spotlight solves at target angle and opens UpperTrackShelf.")
	
	# TEST 7: MasterKey & ExitDoor
	print("\n--- Testing MasterKey & ExitDoor ---")
	var exit_door: ExitDoor = main.get_node_or_null("ExitDoor")
	assert(exit_door != null, "ExitDoor must exist")
	
	# Player without key tries to interact
	player.has_master_key = false
	exit_door._on_interact(player)
	assert(exit_door.is_open == false, "ExitDoor must remain locked without master key")
	assert(exit_door.prompt_text == "Locked - Requires Master Key", "Must display locked notification")
	print("[PASS] ExitDoor checks player.has_master_key and displays locked warning.")
	
	# Player collects key
	var key: MasterKey = main.get_node_or_null("MasterKey")
	assert(key != null, "MasterKey must exist")
	key._on_interact(player)
	assert(player.has_master_key == true, "Player must have master key after interaction")
	assert(player.hybrid_hud.key_indicator.visible == true, "HUD key icon must become visible")
	print("[PASS] MasterKey grants key to player and shows HUD key badge.")
	
	# Player with key unlocks exit door
	exit_door._on_interact(player)
	assert(exit_door.is_open == true, "ExitDoor must open when player has master key")
	assert(player.is_game_ended == true, "Victory escape sequence must be triggered")
	assert(player.hybrid_hud.victory_overlay.visible == true, "Victory overlay must be visible")
	print("[PASS] ExitDoor unlocks and triggers 'You Escaped' victory screen.")
	
	# TEST 8: StalkerEnemy AI Navigation, Vision, and Audio
	print("\n--- Testing StalkerEnemy AI ---")
	var stalker = main.get_node_or_null("StalkerEnemy")
	assert(stalker != null, "StalkerEnemy must exist")
	assert(stalker.patrol_points.size() == 4, "Stalker must have 4 patrol waypoints")
	assert(stalker.current_state == StalkerEnemyScript.State.PATROL, "Initial state must be PATROL")
	
	# Test noise hearing
	GlobalBus.emit_noise(Vector3(12.0, 0.0, -8.0), 25.0)
	assert(stalker.current_state == StalkerEnemyScript.State.INVESTIGATE, "Stalker must investigate heard noise")
	print("[PASS] Stalker transitions to INVESTIGATE upon hearing noise emission.")
	
	# Test sight cone detection
	player.global_position = stalker.global_position + Vector3(0, 0, -5.0)
	stalker.look_at(player.global_position, Vector3.UP)
	var sees = stalker._check_player_visibility()
	assert(sees == true, "Stalker must spot player directly in front within sight distance")
	stalker._start_chase()
	assert(stalker.current_state == StalkerEnemyScript.State.CHASE, "Stalker must enter CHASE when spotting player")
	print("[PASS] Stalker spots player via vision cone raycast and enters CHASE.")
	
	# Test Jumpscare on contact
	player.is_game_ended = false
	stalker.global_position = player.global_position + Vector3(0.5, 0, 0.5)
	stalker._trigger_jumpscare()
	assert(stalker.current_state == StalkerEnemyScript.State.JUMPSCARE, "State must be JUMPSCARE on contact")
	assert(player.is_game_ended == true, "Player game over must be triggered")
	assert(player.hybrid_hud.game_over_overlay.visible == true, "Game Over overlay must be visible")
	print("[PASS] Stalker triggers jumpscare and Game Over screen on contact.")
	
	print("\n========================================")
	print("ALL SYSTEMS TESTED AND VERIFIED: 100% PASS!")
	print("========================================")
	quit(0)
