@tool
extends SceneTree

const MODEL_DIR = "res://models/scary_monster/"

func _init() -> void:
	print("[ScaryModelGenerator] Initializing procedural scary human model builder...")
	DirAccess.make_dir_recursive_absolute(MODEL_DIR)
	_build_all()
	print("[ScaryModelGenerator] Completed successfully!")
	quit(0)

func _build_all() -> void:
	# 1. Prepare Materials
	var flesh_mat = ShaderMaterial.new()
	flesh_mat.shader = load("res://shaders/horror_flesh.gdshader")
	flesh_mat.set_shader_parameter("skin_color", Color(0.36, 0.38, 0.34, 1.0))
	flesh_mat.set_shader_parameter("bruise_color", Color(0.20, 0.11, 0.16, 1.0))
	flesh_mat.set_shader_parameter("gore_color", Color(0.40, 0.05, 0.04, 1.0))
	flesh_mat.set_shader_parameter("rim_color", Color(0.70, 0.12, 0.06, 1.0))
	flesh_mat.set_shader_parameter("roughness_skin", 0.82)
	flesh_mat.set_shader_parameter("wetness_intensity", 0.85)

	var hair_mat = ShaderMaterial.new()
	hair_mat.shader = load("res://shaders/messy_hair.gdshader")

	var cloth_mat = ShaderMaterial.new()
	cloth_mat.shader = load("res://shaders/tattered_cloth.gdshader")

	var eye_right_mat = ShaderMaterial.new()
	eye_right_mat.shader = load("res://shaders/creepy_eye.gdshader")
	eye_right_mat.set_shader_parameter("iris_color", Color(1.0, 0.18, 0.03, 1.0))
	eye_right_mat.set_shader_parameter("emission_boost", 5.0)
	eye_right_mat.set_shader_parameter("is_milky_cataract", false)

	var eye_left_mat = ShaderMaterial.new()
	eye_left_mat.shader = load("res://shaders/creepy_eye.gdshader")
	eye_left_mat.set_shader_parameter("is_milky_cataract", true)
	eye_left_mat.set_shader_parameter("emission_boost", 1.2)

	# 2. Build Meshes
	print("Generating Skull mesh...")
	var skull_mesh = _generate_skull(flesh_mat)
	ResourceSaver.save(skull_mesh, MODEL_DIR + "skull.res")

	print("Generating Jaw mesh...")
	var jaw_mesh = _generate_jaw(flesh_mat)
	ResourceSaver.save(jaw_mesh, MODEL_DIR + "jaw.res")

	print("Generating Teeth meshes...")
	var teeth_upper_mesh = _generate_teeth(true, flesh_mat)
	var teeth_lower_mesh = _generate_teeth(false, flesh_mat)
	ResourceSaver.save(teeth_upper_mesh, MODEL_DIR + "teeth_upper.res")
	ResourceSaver.save(teeth_lower_mesh, MODEL_DIR + "teeth_lower.res")

	print("Generating Eye meshes...")
	var eye_r_mesh = _generate_eyeball(0.048, eye_right_mat)
	var eye_l_mesh = _generate_eyeball(0.042, eye_left_mat)
	ResourceSaver.save(eye_r_mesh, MODEL_DIR + "eye_right.res")
	ResourceSaver.save(eye_l_mesh, MODEL_DIR + "eye_left.res")

	print("Generating Messy Hair mesh...")
	var hair_mesh = _generate_hair(hair_mat)
	ResourceSaver.save(hair_mesh, MODEL_DIR + "hair.res")

	print("Generating Spine & Dorsal Spikes...")
	var spine_mesh = _generate_spine(flesh_mat)
	ResourceSaver.save(spine_mesh, MODEL_DIR + "spine.res")

	print("Generating Ribcage & Clavicles...")
	var ribcage_mesh = _generate_ribcage(flesh_mat)
	ResourceSaver.save(ribcage_mesh, MODEL_DIR + "ribcage.res")

	print("Generating Arms & Clawed Hands...")
	var arm_l_mesh = _generate_arm(true, flesh_mat)
	var arm_r_mesh = _generate_arm(false, flesh_mat)
	var hand_l_mesh = _generate_hand(true, flesh_mat)
	var hand_r_mesh = _generate_hand(false, flesh_mat)
	ResourceSaver.save(arm_l_mesh, MODEL_DIR + "arm_left.res")
	ResourceSaver.save(arm_r_mesh, MODEL_DIR + "arm_right.res")
	ResourceSaver.save(hand_l_mesh, MODEL_DIR + "hand_left.res")
	ResourceSaver.save(hand_r_mesh, MODEL_DIR + "hand_right.res")

	print("Generating Pelvis & Legs...")
	var pelvis_mesh = _generate_pelvis(flesh_mat)
	var leg_l_mesh = _generate_leg(true, flesh_mat)
	var leg_r_mesh = _generate_leg(false, flesh_mat)
	ResourceSaver.save(pelvis_mesh, MODEL_DIR + "pelvis.res")
	ResourceSaver.save(leg_l_mesh, MODEL_DIR + "leg_left.res")
	ResourceSaver.save(leg_r_mesh, MODEL_DIR + "leg_right.res")

	print("Generating Tattered Shroud Cloth...")
	var shroud_mesh = _generate_shroud(cloth_mat)
	ResourceSaver.save(shroud_mesh, MODEL_DIR + "shroud.res")

	# 3. Assemble PackedScene
	print("Assembling ScaryHumanoidModel.tscn...")
	_assemble_scene()

# =========================================================================
# GEOMETRY GENERATORS
# =========================================================================

# Helper: Add an organic tube connecting a series of points
func _add_tube(st: SurfaceTool, pts: Array, radii: Array, radial_segs: int, col: Color, vcol_b_wet: float = 0.0) -> void:
	if pts.size() < 2 or radii.size() != pts.size():
		return
	var ring_verts: Array[Array] = []
	for i in range(pts.size()):
		var p = pts[i]
		var r = radii[i]
		var fwd: Vector3
		if i < pts.size() - 1:
			fwd = (pts[i+1] - p).normalized()
		else:
			fwd = (p - pts[i-1]).normalized()
		var up = Vector3.UP if abs(fwd.y) < 0.9 else Vector3.RIGHT
		var right = fwd.cross(up).normalized()
		var real_up = right.cross(fwd).normalized()
		
		var ring: Array[Vector3] = []
		for s in range(radial_segs):
			var a = (float(s) / float(radial_segs)) * TAU
			var offset = (right * cos(a) + real_up * sin(a)) * r
			ring.append(p + offset)
		ring_verts.append(ring)
		
	for i in range(pts.size() - 1):
		var v_ratio = float(i) / float(pts.size() - 1)
		for s in range(radial_segs):
			var s_next = (s + 1) % radial_segs
			var u0 = float(s) / float(radial_segs)
			var u1 = float(s + 1) / float(radial_segs)
			
			var p0 = ring_verts[i][s]
			var p1 = ring_verts[i][s_next]
			var p2 = ring_verts[i+1][s]
			var p3 = ring_verts[i+1][s_next]
			
			st.set_color(Color(col.r, col.g, vcol_b_wet, col.a))
			st.set_uv(Vector2(u0, v_ratio))
			st.add_vertex(p0)
			st.set_uv(Vector2(u0, v_ratio + 0.1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v_ratio))
			st.add_vertex(p1)
			
			st.set_uv(Vector2(u1, v_ratio))
			st.add_vertex(p1)
			st.set_uv(Vector2(u0, v_ratio + 0.1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v_ratio + 0.1))
			st.add_vertex(p3)

# Helper: Add a cone/spike (teeth, claws, dorsal spikes)
func _add_cone(st: SurfaceTool, base: Vector3, tip: Vector3, base_radius: float, segs: int, col: Color, is_bone: bool = false, is_wet: bool = false) -> void:
	var fwd = (tip - base).normalized()
	var up = Vector3.UP if abs(fwd.y) < 0.9 else Vector3.RIGHT
	var right = fwd.cross(up).normalized()
	var real_up = right.cross(fwd).normalized()
	
	var bone_val = 1.0 if is_bone else 0.0
	var wet_val = 1.0 if is_wet else 0.0
	var vertex_color = Color(col.r, bone_val, wet_val, 1.0)
	
	for s in range(segs):
		var a0 = (float(s) / float(segs)) * TAU
		var a1 = (float(s + 1) / float(segs)) * TAU
		var p0 = base + (right * cos(a0) + real_up * sin(a0)) * base_radius
		var p1 = base + (right * cos(a1) + real_up * sin(a1)) * base_radius
		
		# Side triangle
		st.set_color(vertex_color)
		st.set_uv(Vector2(float(s)/float(segs), 1.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(tip)
		st.set_uv(Vector2(float(s+1)/float(segs), 1.0))
		st.add_vertex(p1)
		
		# Base triangle (closed cap)
		st.set_color(vertex_color)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(base)
		st.set_uv(Vector2(cos(a1)*0.5+0.5, sin(a1)*0.5+0.5))
		st.add_vertex(p1)
		st.set_uv(Vector2(cos(a0)*0.5+0.5, sin(a0)*0.5+0.5))
		st.add_vertex(p0)

# Helper: Add a quad ribbon (hair strands, cloth shreds, wounds)
func _add_ribbon(st: SurfaceTool, pts: Array, widths: Array, normal_dir: Vector3, col: Color) -> void:
	for i in range(pts.size() - 1):
		var p0 = pts[i]
		var p1 = pts[i+1]
		var fwd = (p1 - p0).normalized()
		var side = fwd.cross(normal_dir).normalized()
		var w0 = widths[i] * 0.5
		var w1 = widths[i+1] * 0.5
		
		var v0 = p0 - side * w0
		var v1 = p0 + side * w0
		var v2 = p1 - side * w1
		var v3 = p1 + side * w1
		
		var t0 = float(i) / float(pts.size())
		var t1 = float(i+1) / float(pts.size())
		
		st.set_color(col)
		st.set_uv(Vector2(0.0, t0))
		st.add_vertex(v0)
		st.set_uv(Vector2(0.0, t1))
		st.add_vertex(v2)
		st.set_uv(Vector2(1.0, t0))
		st.add_vertex(v1)
		
		st.set_uv(Vector2(1.0, t0))
		st.add_vertex(v1)
		st.set_uv(Vector2(0.0, t1))
		st.add_vertex(v2)
		st.set_uv(Vector2(1.0, t1))
		st.add_vertex(v3)

# -------------------------------------------------------------------------
# 1. DEFORMED HUMAN SKULL
# -------------------------------------------------------------------------
func _generate_skull(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var lat_segs = 18
	var lon_segs = 24
	var r_base = Vector3(0.18, 0.22, 0.24) # Deformed elongated cranium
	
	var grid: Array[Array] = []
	for lat in range(lat_segs + 1):
		var theta = (float(lat) / float(lat_segs)) * PI
		var row: Array[Vector3] = []
		for lon in range(lon_segs + 1):
			var phi = (float(lon) / float(lon_segs)) * TAU
			var nx = sin(theta) * cos(phi)
			var ny = cos(theta)
			var nz = sin(theta) * sin(phi)
			
			var pos = Vector3(nx * r_base.x, ny * r_base.y, nz * r_base.z)
			
			# Anatomical Horror Deformations:
			# Elongated rear occiput
			if nz > 0.05:
				pos.z += nz * 0.14
				pos.y += nz * 0.06
			
			# Gaunt sunken temples
			if abs(nx) > 0.35 and nz < 0.1 and nz > -0.15:
				pos.x *= 0.78
				
			# High zygomatic cheekbones
			if abs(nx) > 0.45 and ny < 0.0 and ny > -0.4 and nz < -0.1:
				pos.x *= 1.25
				pos.z -= 0.04
				
			# Eye socket hollow depressions (Right eye wider, Left eye sunken/fractured)
			if nz < -0.12 and ny > -0.15 and ny < 0.2:
				if nx > 0.12 and nx < 0.65:
					pos.z += 0.06 # right socket hollow
				elif nx < -0.08 and nx > -0.65:
					pos.z += 0.09 # left socket deeply sunken
					pos.x *= 0.9
					
			# Nasal cavity cleft
			if abs(nx) < 0.12 and ny > -0.22 and ny < -0.05 and nz < -0.15:
				pos.z += 0.07
				pos.x *= 0.7
				
			# Maxilla dental arch extending forward & down
			if ny < -0.18 and nz < -0.05:
				pos.y -= 0.08
				pos.z -= 0.06
				
			# Asymmetrical deformity (twisted left side)
			if nx < 0.0:
				pos.y -= 0.02
				pos.x += 0.015
				
			row.append(pos)
		grid.append(row)
		
	for lat in range(lat_segs):
		var v0 = float(lat) / float(lat_segs)
		var v1 = float(lat + 1) / float(lat_segs)
		for lon in range(lon_segs):
			var u0 = float(lon) / float(lon_segs)
			var u1 = float(lon + 1) / float(lon_segs)
			
			var p0 = grid[lat][lon]
			var p1 = grid[lat][lon+1]
			var p2 = grid[lat+1][lon]
			var p3 = grid[lat+1][lon+1]
			
			# Vertex coloring for gore/bruising on sockets and temples
			var blood_amt = 0.0
			if p0.z < -0.12 and p0.y < 0.05:
				blood_amt = 0.65 # Dried gore around sockets and mouth
			if p0.x < -0.05 and p0.z < -0.1:
				blood_amt = 0.85 # Weeping dark trauma on left eye
				
			var vcol = Color(blood_amt, 0.0, 0.0, 1.0)
			
			st.set_color(vcol)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p1)
			
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p1)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p3)

	# Add coarse surgical stitches across right forehead fissure
	var stitch_pts = [
		Vector3(0.04, 0.22, -0.14), Vector3(0.06, 0.17, -0.18),
		Vector3(0.08, 0.12, -0.20), Vector3(0.11, 0.07, -0.22)
	]
	for sp in stitch_pts:
		_add_tube(st, [sp - Vector3(0.02, 0.01, 0.01), sp + Vector3(0.02, 0.01, 0.01)], [0.005, 0.005], 4, Color(0.9, 0.0, 0.3, 1.0), 0.5)

	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 2. DISLOCATED MANDIBLE (LOWER JAW)
# -------------------------------------------------------------------------
func _generate_jaw(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Mandible curve from left condyle hinge -> chin -> right condyle hinge
	var jaw_pts = [
		Vector3(-0.13, 0.08, 0.02),  # Left hinge
		Vector3(-0.14, -0.05, -0.04), # Left branch
		Vector3(-0.11, -0.14, -0.14), # Left jaw angle
		Vector3(-0.06, -0.17, -0.22), # Left chin
		Vector3(0.00, -0.18, -0.25),  # Chin apex (twisted protrusion)
		Vector3(0.07, -0.16, -0.22),  # Right chin
		Vector3(0.12, -0.13, -0.14),  # Right jaw angle
		Vector3(0.14, -0.04, -0.04),  # Right branch
		Vector3(0.13, 0.08, 0.02)    # Right hinge
	]
	var jaw_radii = [0.022, 0.028, 0.035, 0.038, 0.042, 0.038, 0.035, 0.028, 0.022]
	_add_tube(st, jaw_pts, jaw_radii, 8, Color(0.7, 0.2, 0.0, 1.0), 0.6)
	
	# Hollow throat cavity backing (deep black/red gore inside mouth)
	var throat_pts = [
		Vector3(-0.08, -0.05, -0.08), Vector3(0.08, -0.05, -0.08),
		Vector3(0.0, -0.15, -0.14)
	]
	st.set_color(Color(0.85, 0.0, 0.8, 1.0)) # bloody wet throat
	st.set_uv(Vector2(0, 0))
	st.add_vertex(throat_pts[0])
	st.set_uv(Vector2(1, 0))
	st.add_vertex(throat_pts[1])
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(throat_pts[2])
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 3. MESSY HUMAN TEETH & JAGGED FANGS
# -------------------------------------------------------------------------
func _generate_teeth(is_upper: bool, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var count = 16
	var arch_width = 0.09 if is_upper else 0.082
	var arch_depth = 0.10 if is_upper else 0.095
	var base_y = -0.16 if is_upper else -0.16
	var base_z = -0.15 if is_upper else -0.15
	var tip_dir = Vector3.DOWN if is_upper else Vector3.UP
	
	for i in range(count):
		var t = float(i) / float(count - 1)
		var angle = (t - 0.5) * PI * 0.82
		var tx = sin(angle) * arch_width
		var tz = base_z - cos(angle) * arch_depth
		var ty = base_y
		
		# Individual teeth characteristics (crooked, some chipped, canines are fangs!)
		var tooth_len = 0.035
		var tooth_rad = 0.009
		var is_fang = (i == 3 or i == 4 or i == 11 or i == 12)
		if is_fang:
			tooth_len = 0.065 # Long predatory fangs
			tooth_rad = 0.012
		elif i == 7 or i == 8:
			tooth_len = 0.042 # Prominent front incisors
			
		# Irregular crooked tilt
		var tilt_x = sin(float(i) * 2.7) * 0.008
		var tilt_z = cos(float(i) * 3.1) * 0.009
		
		var base_pos = Vector3(tx, ty, tz)
		var tip_pos = base_pos + tip_dir * tooth_len + Vector3(tilt_x, 0.0, tilt_z)
		
		_add_cone(st, base_pos, tip_pos, tooth_rad, 6, Color(0.4, 0.0, 0.0, 1.0), true, true)
		
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 4. EYEBALL
# -------------------------------------------------------------------------
func _generate_eyeball(radius: float, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var lat_segs = 12
	var lon_segs = 16
	for lat in range(lat_segs):
		var th0 = (float(lat) / float(lat_segs)) * PI
		var th1 = (float(lat + 1) / float(lat_segs)) * PI
		for lon in range(lon_segs):
			var ph0 = (float(lon) / float(lon_segs)) * TAU
			var ph1 = (float(lon + 1) / float(lon_segs)) * TAU
			
			var p0 = Vector3(sin(th0)*cos(ph0), cos(th0), sin(th0)*sin(ph0)) * radius
			var p1 = Vector3(sin(th0)*cos(ph1), cos(th0), sin(th0)*sin(ph1)) * radius
			var p2 = Vector3(sin(th1)*cos(ph0), cos(th1), sin(th1)*sin(ph0)) * radius
			var p3 = Vector3(sin(th1)*cos(ph1), cos(th1), sin(th1)*sin(ph1)) * radius
			
			var u0 = float(lon) / float(lon_segs)
			var u1 = float(lon + 1) / float(lon_segs)
			var v0 = float(lat) / float(lat_segs)
			var v1 = float(lat + 1) / float(lat_segs)
			
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p1)
			
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p1)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p3)
			
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 5. MATTED STRINGY HUMAN HAIR
# -------------------------------------------------------------------------
func _generate_hair(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Generate 24 strands originating from scalp and draping down
	var strand_origins = [
		# Forehead fringe (hanging down over face and eyes)
		Vector3(-0.10, 0.20, -0.18), Vector3(-0.05, 0.22, -0.21),
		Vector3(0.00, 0.23, -0.22), Vector3(0.05, 0.22, -0.21),
		Vector3(0.10, 0.20, -0.18),
		# Left side strands (hanging over ear/neck)
		Vector3(-0.16, 0.18, -0.08), Vector3(-0.18, 0.14, 0.02),
		Vector3(-0.17, 0.10, 0.10), Vector3(-0.15, 0.06, 0.16),
		# Right side strands
		Vector3(0.16, 0.18, -0.08), Vector3(0.18, 0.14, 0.02),
		Vector3(0.17, 0.10, 0.10), Vector3(0.15, 0.06, 0.16),
		# Crown and rear parietal
		Vector3(-0.06, 0.25, -0.05), Vector3(0.06, 0.25, -0.05),
		Vector3(-0.08, 0.22, 0.12), Vector3(0.08, 0.22, 0.12),
		Vector3(0.00, 0.20, 0.22), Vector3(-0.05, 0.14, 0.25),
		Vector3(0.05, 0.14, 0.25), Vector3(0.00, 0.08, 0.28)
	]
	
	for idx in range(strand_origins.size()):
		var root = strand_origins[idx]
		var length_mult = 0.35 + (float(idx % 5) * 0.08)
		var pts: Array[Vector3] = [root]
		var cur = root
		var segs = 6
		for s in range(1, segs + 1):
			var frac = float(s) / float(segs)
			var dy = -frac * length_mult
			# Curl slightly around head contours
			var dx = sin(frac * 3.5 + float(idx)) * 0.025
			var dz = (0.04 if cur.z > 0.0 else -0.03) * frac
			var p = root + Vector3(dx, dy, dz)
			pts.append(p)
		var widths = [0.035, 0.030, 0.025, 0.020, 0.015, 0.008, 0.002]
		_add_ribbon(st, pts, widths, Vector3.UP, Color(0.3, 0.0, 0.0, 1.0))
		
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 6. HUNCHED SPINE & DORSAL SPIKES
# -------------------------------------------------------------------------
func _generate_spine(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Severe kyphotic S-curve spine from Pelvis (y=0) to Neck (y=0.95)
	var vertebrae_count = 14
	var spine_pts: Array[Vector3] = []
	var spine_radii: Array[float] = []
	
	for i in range(vertebrae_count):
		var t = float(i) / float(vertebrae_count - 1)
		var y = t * 0.95
		# Kyphotic arching forward and scoliosis tilt
		var z = sin(t * PI) * 0.22 - (t * 0.26)
		var x = sin(t * TAU * 0.75) * 0.025 # scoliosis twist
		var pos = Vector3(x, y, z)
		spine_pts.append(pos)
		spine_radii.append(0.042 - t * 0.012)
		
		# Protruding sharp spinous process spike on each vertebra
		var spike_len = 0.08 + sin(t * PI) * 0.06
		var spike_tip = pos + Vector3(0.0, 0.01, 0.12).normalized() * spike_len
		_add_cone(st, pos, spike_tip, 0.018, 5, Color(0.65, 0.0, 0.0, 1.0), true, false)
		
	_add_tube(st, spine_pts, spine_radii, 8, Color(0.5, 0.0, 0.0, 1.0), 0.2)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 7. EMACIATED RIBCAGE & CLAVICLES
# -------------------------------------------------------------------------
func _generate_ribcage(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 7 pairs of curved ribs jutting from spine to sternum
	var rib_count = 7
	for r in range(rib_count):
		var t = float(r) / float(rib_count - 1)
		var spine_y = 0.30 + t * 0.45
		var spine_z = sin((0.35 + t * 0.45) * PI) * 0.20 - ((0.35 + t * 0.45) * 0.24)
		var sternum_y = spine_y - 0.08
		var sternum_z = spine_z - 0.26
		
		var rib_width = (sin(t * PI * 0.85 + 0.15)) * 0.24
		
		# Left Rib
		var rib_l_pts = [
			Vector3(0.0, spine_y, spine_z),
			Vector3(-rib_width * 0.8, spine_y + 0.02, spine_z - 0.06),
			Vector3(-rib_width, spine_y - 0.02, spine_z - 0.16),
			Vector3(-rib_width * 0.5, sternum_y - 0.01, sternum_z + 0.02),
			Vector3(0.0, sternum_y, sternum_z)
		]
		var r_rads = [0.012, 0.015, 0.016, 0.014, 0.012]
		_add_tube(st, rib_l_pts, r_rads, 6, Color(0.35, 0.0, 0.0, 1.0), 0.2)
		
		# Right Rib (Asymmetric deformity: cracked and lower)
		var rib_r_pts = [
			Vector3(0.0, spine_y, spine_z),
			Vector3(rib_width * 0.75, spine_y - 0.01, spine_z - 0.05),
			Vector3(rib_width * 0.92, spine_y - 0.05, spine_z - 0.15),
			Vector3(rib_width * 0.45, sternum_y - 0.03, sternum_z + 0.02),
			Vector3(0.0, sternum_y, sternum_z)
		]
		_add_tube(st, rib_r_pts, r_rads, 6, Color(0.45, 0.0, 0.0, 1.0), 0.2)
		
	# Sternum plate
	var sternum_pts = [
		Vector3(0.0, 0.72, -0.28), Vector3(0.0, 0.55, -0.24),
		Vector3(0.0, 0.38, -0.20), Vector3(0.0, 0.24, -0.16)
	]
	_add_tube(st, sternum_pts, [0.028, 0.025, 0.022, 0.015], 6, Color(0.3, 0.0, 0.0, 1.0), 0.1)
	
	# Sharp S-curved Clavicles (Collarbones)
	var clav_l = [Vector3(0.0, 0.75, -0.26), Vector3(-0.14, 0.77, -0.20), Vector3(-0.28, 0.74, -0.12)]
	var clav_r = [Vector3(0.0, 0.75, -0.26), Vector3(0.14, 0.74, -0.20), Vector3(0.28, 0.70, -0.12)]
	_add_tube(st, clav_l, [0.02, 0.018, 0.022], 6, Color(0.4, 0.0, 0.0, 1.0), 0.1)
	_add_tube(st, clav_r, [0.02, 0.018, 0.022], 6, Color(0.4, 0.0, 0.0, 1.0), 0.1)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 8. GAUNT ARMS & ELBOWS
# -------------------------------------------------------------------------
func _generate_arm(is_left: bool, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sign_x = -1.0 if is_left else 1.0
	
	# Upper arm + Elbow + Forearm (Elongated, hanging low)
	var arm_pts = [
		Vector3(0.0, 0.0, 0.0),                          # Shoulder joint
		Vector3(sign_x * 0.04, -0.25, 0.02),             # Bicep/tricep mid
		Vector3(sign_x * 0.02, -0.52, 0.06),             # Knobby elbow
		Vector3(sign_x * 0.01, -0.80, -0.04),            # Forearm mid
		Vector3(0.0, -1.08, -0.10)                       # Wrist
	]
	var arm_rads = [0.055, 0.045, 0.052, 0.038, 0.032]
	_add_tube(st, arm_pts, arm_rads, 8, Color(0.45, 0.0, 0.0, 1.0), 0.15)
	
	# Sharp olecranon elbow bone spur
	var elbow_base = arm_pts[2]
	var elbow_tip = elbow_base + Vector3(sign_x * 0.02, 0.02, 0.07)
	_add_cone(st, elbow_base, elbow_tip, 0.025, 5, Color(0.5, 0.0, 0.0, 1.0), true)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 9. GNARLED HANDS WITH 5 CROOKED CLAW FINGERS
# -------------------------------------------------------------------------
func _generate_hand(is_left: bool, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sign_x = -1.0 if is_left else 1.0
	
	# Palm plate
	var palm_pts = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(sign_x * 0.02, -0.07, -0.02),
		Vector3(sign_x * 0.03, -0.13, -0.03)
	]
	_add_tube(st, palm_pts, [0.032, 0.042, 0.045], 6, Color(0.5, 0.0, 0.0, 1.0), 0.3)
	
	# 5 articulated fingers with sharp blackened claws!
	# [Thumb, Index, Middle, Ring, Pinky]
	var finger_offsets = [
		Vector3(sign_x * 0.05, -0.04, 0.03),  # Thumb
		Vector3(sign_x * 0.03, -0.13, -0.02), # Index
		Vector3(sign_x * 0.00, -0.14, -0.03), # Middle
		Vector3(-sign_x * 0.02, -0.13, -0.02),# Ring
		Vector3(-sign_x * 0.04, -0.11, -0.01) # Pinky
	]
	var finger_lengths = [0.12, 0.17, 0.20, 0.18, 0.14]
	
	for f in range(5):
		var base = finger_offsets[f]
		var flen = finger_lengths[f]
		var f_dir = Vector3(sign_x * (float(f - 2) * 0.03), -1.0, -0.4).normalized()
		
		# 3 knuckle segments
		var p1 = base + f_dir * (flen * 0.4)
		var p2 = p1 + (f_dir + Vector3(0.0, -0.2, -0.3)).normalized() * (flen * 0.35)
		var p3 = p2 + (f_dir + Vector3(0.0, -0.4, -0.6)).normalized() * (flen * 0.25)
		
		_add_tube(st, [base, p1, p2, p3], [0.014, 0.012, 0.010, 0.008], 5, Color(0.55, 0.0, 0.0, 1.0), 0.4)
		
		# Blackened claw nail on tip
		var claw_tip = p3 + (f_dir + Vector3(0.0, -0.6, -0.8)).normalized() * 0.055
		_add_cone(st, p3, claw_tip, 0.009, 5, Color(0.85, 0.0, 0.0, 1.0), false, true)
		
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 10. BONY PELVIS & ILIAC CRESTS
# -------------------------------------------------------------------------
func _generate_pelvis(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Iliac crest wings
	var pelvis_l = [
		Vector3(0.0, 0.05, 0.04),
		Vector3(-0.16, 0.12, 0.01),
		Vector3(-0.24, 0.04, -0.06),
		Vector3(-0.15, -0.12, -0.08),
		Vector3(0.0, -0.16, -0.06)
	]
	var pelvis_r = [
		Vector3(0.0, 0.05, 0.04),
		Vector3(0.16, 0.10, 0.01),
		Vector3(0.24, 0.02, -0.06),
		Vector3(0.15, -0.13, -0.08),
		Vector3(0.0, -0.16, -0.06)
	]
	_add_tube(st, pelvis_l, [0.038, 0.035, 0.032, 0.028, 0.022], 6, Color(0.4, 0.0, 0.0, 1.0), 0.15)
	_add_tube(st, pelvis_r, [0.038, 0.035, 0.032, 0.028, 0.022], 6, Color(0.4, 0.0, 0.0, 1.0), 0.15)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 11. SHAMBLING LEGS & BARE HUMAN FEET
# -------------------------------------------------------------------------
func _generate_leg(is_left: bool, mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sign_x = -1.0 if is_left else 1.0
	
	# Thigh (femur) -> Knee -> Shin (tibia) -> Ankle
	var leg_pts = [
		Vector3(0.0, 0.0, 0.0),                          # Hip joint
		Vector3(sign_x * 0.02, -0.28, 0.03),             # Thigh mid
		Vector3(sign_x * 0.01, -0.58, 0.08),             # Knobby knee
		Vector3(0.0, -0.88, 0.02),                       # Shin mid
		Vector3(sign_x * 0.01, -1.16, -0.04)             # Ankle
	]
	var leg_rads = [0.065, 0.055, 0.062, 0.045, 0.038]
	_add_tube(st, leg_pts, leg_rads, 8, Color(0.4, 0.0, 0.0, 1.0), 0.1)
	
	# Bony patella knee protrusion
	var knee_base = leg_pts[2]
	var knee_tip = knee_base + Vector3(0.0, 0.01, -0.06)
	_add_cone(st, knee_base, knee_tip, 0.032, 6, Color(0.45, 0.0, 0.0, 1.0), true)
	
	# Bare human foot with 5 splayed crooked toes
	var ankle_pos = leg_pts[4]
	var heel_pos = ankle_pos + Vector3(0.0, -0.06, 0.08)
	var ball_pos = ankle_pos + Vector3(0.0, -0.08, -0.16)
	_add_tube(st, [heel_pos, ankle_pos + Vector3(0, -0.04, 0), ball_pos], [0.038, 0.035, 0.045], 6, Color(0.5, 0.0, 0.0, 1.0), 0.2)
	
	# 5 Toes
	for t in range(5):
		var toe_x = sign_x * (float(t - 2) * 0.018)
		var toe_base = ball_pos + Vector3(toe_x, 0.0, -0.02)
		var toe_tip = toe_base + Vector3(toe_x * 0.4, -0.01, -0.065)
		_add_cone(st, toe_base, toe_tip, 0.011, 4, Color(0.65, 0.0, 0.0, 1.0), true)
		
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 12. TATTERED BURIAL / HOSPITAL SHROUD CLOTH
# -------------------------------------------------------------------------
func _generate_shroud(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Shreds hanging across shoulders, chest, and hips
	var shroud_ribbons = [
		# Diagonal chest sash (left shoulder to right hip)
		[Vector3(-0.26, 0.76, -0.14), Vector3(-0.12, 0.55, -0.22), Vector3(0.08, 0.30, -0.20), Vector3(0.20, 0.05, -0.12)],
		# Right shoulder drape
		[Vector3(0.26, 0.72, -0.14), Vector3(0.24, 0.45, -0.16), Vector3(0.22, 0.15, -0.08)],
		# Waist ragged apron strips
		[Vector3(-0.16, 0.08, -0.10), Vector3(-0.18, -0.25, -0.12), Vector3(-0.20, -0.55, -0.08)],
		[Vector3(-0.06, 0.06, -0.12), Vector3(-0.05, -0.30, -0.15), Vector3(-0.08, -0.62, -0.10)],
		[Vector3(0.06, 0.06, -0.12), Vector3(0.08, -0.28, -0.15), Vector3(0.05, -0.58, -0.10)],
		[Vector3(0.16, 0.08, -0.10), Vector3(0.18, -0.24, -0.12), Vector3(0.19, -0.50, -0.08)]
	]
	
	for ribbon in shroud_ribbons:
		var widths: Array[float] = []
		for p in ribbon:
			widths.append(0.12)
		_add_ribbon(st, ribbon, widths, Vector3.FORWARD, Color(0.7, 0.1, 0.1, 1.0))
		
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()

# -------------------------------------------------------------------------
# 13. PACKEDSCENE ASSEMBLY
# -------------------------------------------------------------------------
func _assemble_scene() -> void:
	var root = Node3D.new()
	root.name = "MessyHumanoid"

	# Animation controller
	var anim_script = load("res://scripts/messy_human_animator.gd")
	root.set_script(anim_script)

	# Pelvis / Root bone
	var hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 1.20, 0.0)
	root.add_child(hips)
	hips.owner = root

	var pelvis_inst = MeshInstance3D.new()
	pelvis_inst.name = "PelvisMesh"
	pelvis_inst.mesh = load(MODEL_DIR + "pelvis.res")
	hips.add_child(pelvis_inst)
	pelvis_inst.owner = root

	# Torso / Spine Root
	var torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.0, 0.0)
	hips.add_child(torso)
	torso.owner = root

	var spine_inst = MeshInstance3D.new()
	spine_inst.name = "SpineMesh"
	spine_inst.mesh = load(MODEL_DIR + "spine.res")
	torso.add_child(spine_inst)
	spine_inst.owner = root

	var ribcage_inst = MeshInstance3D.new()
	ribcage_inst.name = "RibcageMesh"
	ribcage_inst.mesh = load(MODEL_DIR + "ribcage.res")
	torso.add_child(ribcage_inst)
	ribcage_inst.owner = root

	var shroud_inst = MeshInstance3D.new()
	shroud_inst.name = "ShroudMesh"
	shroud_inst.mesh = load(MODEL_DIR + "shroud.res")
	torso.add_child(shroud_inst)
	shroud_inst.owner = root

	# Neck & Head
	var neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0.0, 0.95, -0.26)
	torso.add_child(neck)
	neck.owner = root

	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.08, -0.05)
	neck.add_child(head)
	head.owner = root

	var skull_inst = MeshInstance3D.new()
	skull_inst.name = "SkullMesh"
	skull_inst.mesh = load(MODEL_DIR + "skull.res")
	head.add_child(skull_inst)
	skull_inst.owner = root

	var hair_inst = MeshInstance3D.new()
	hair_inst.name = "HairMesh"
	hair_inst.mesh = load(MODEL_DIR + "hair.res")
	head.add_child(hair_inst)
	hair_inst.owner = root

	var teeth_up_inst = MeshInstance3D.new()
	teeth_up_inst.name = "TeethUpper"
	teeth_up_inst.mesh = load(MODEL_DIR + "teeth_upper.res")
	head.add_child(teeth_up_inst)
	teeth_up_inst.owner = root

	# Eyes
	var eye_r_inst = MeshInstance3D.new()
	eye_r_inst.name = "EyeRight"
	eye_r_inst.position = Vector3(0.09, 0.04, -0.19)
	eye_r_inst.mesh = load(MODEL_DIR + "eye_right.res")
	head.add_child(eye_r_inst)
	eye_r_inst.owner = root

	var eye_l_inst = MeshInstance3D.new()
	eye_l_inst.name = "EyeLeft"
	eye_l_inst.position = Vector3(-0.09, 0.03, -0.18)
	eye_l_inst.mesh = load(MODEL_DIR + "eye_left.res")
	head.add_child(eye_l_inst)
	eye_l_inst.owner = root

	# Hinged Lower Jaw
	var jaw_hinge = Node3D.new()
	jaw_hinge.name = "JawHinge"
	jaw_hinge.position = Vector3(0.0, -0.04, 0.02)
	head.add_child(jaw_hinge)
	jaw_hinge.owner = root

	var jaw_inst = MeshInstance3D.new()
	jaw_inst.name = "JawMesh"
	jaw_inst.mesh = load(MODEL_DIR + "jaw.res")
	jaw_hinge.add_child(jaw_inst)
	jaw_inst.owner = root

	var teeth_low_inst = MeshInstance3D.new()
	teeth_low_inst.name = "TeethLower"
	teeth_low_inst.mesh = load(MODEL_DIR + "teeth_lower.res")
	jaw_hinge.add_child(teeth_low_inst)
	teeth_low_inst.owner = root

	# Left Arm
	var shoulder_l = Node3D.new()
	shoulder_l.name = "ShoulderLeft"
	shoulder_l.position = Vector3(-0.28, 0.74, -0.12)
	torso.add_child(shoulder_l)
	shoulder_l.owner = root

	var arm_l_inst = MeshInstance3D.new()
	arm_l_inst.name = "ArmLeftMesh"
	arm_l_inst.mesh = load(MODEL_DIR + "arm_left.res")
	shoulder_l.add_child(arm_l_inst)
	arm_l_inst.owner = root

	var hand_l = Node3D.new()
	hand_l.name = "HandLeft"
	hand_l.position = Vector3(0.0, -1.08, -0.10)
	shoulder_l.add_child(hand_l)
	hand_l.owner = root

	var hand_l_inst = MeshInstance3D.new()
	hand_l_inst.name = "HandLeftMesh"
	hand_l_inst.mesh = load(MODEL_DIR + "hand_left.res")
	hand_l.add_child(hand_l_inst)
	hand_l_inst.owner = root

	# Right Arm
	var shoulder_r = Node3D.new()
	shoulder_r.name = "ShoulderRight"
	shoulder_r.position = Vector3(0.28, 0.70, -0.12)
	torso.add_child(shoulder_r)
	shoulder_r.owner = root

	var arm_r_inst = MeshInstance3D.new()
	arm_r_inst.name = "ArmRightMesh"
	arm_r_inst.mesh = load(MODEL_DIR + "arm_right.res")
	shoulder_r.add_child(arm_r_inst)
	arm_r_inst.owner = root

	var hand_r = Node3D.new()
	hand_r.name = "HandRight"
	hand_r.position = Vector3(0.0, -1.08, -0.10)
	shoulder_r.add_child(hand_r)
	hand_r.owner = root

	var hand_r_inst = MeshInstance3D.new()
	hand_r_inst.name = "HandRightMesh"
	hand_r_inst.mesh = load(MODEL_DIR + "hand_right.res")
	hand_r.add_child(hand_r_inst)
	hand_r_inst.owner = root

	# Left Leg
	var hip_l = Node3D.new()
	hip_l.name = "HipLeft"
	hip_l.position = Vector3(-0.16, -0.06, 0.0)
	hips.add_child(hip_l)
	hip_l.owner = root

	var leg_l_inst = MeshInstance3D.new()
	leg_l_inst.name = "LegLeftMesh"
	leg_l_inst.mesh = load(MODEL_DIR + "leg_left.res")
	hip_l.add_child(leg_l_inst)
	leg_l_inst.owner = root

	# Right Leg
	var hip_r = Node3D.new()
	hip_r.name = "HipRight"
	hip_r.position = Vector3(0.16, -0.06, 0.0)
	hips.add_child(hip_r)
	hip_r.owner = root

	var leg_r_inst = MeshInstance3D.new()
	leg_r_inst.name = "LegRightMesh"
	leg_r_inst.mesh = load(MODEL_DIR + "leg_right.res")
	hip_r.add_child(leg_r_inst)
	leg_r_inst.owner = root

	# Save PackedScene
	var packed = PackedScene.new()
	var pack_err = packed.pack(root)
	if pack_err == OK:
		var save_err = ResourceSaver.save(packed, "res://scenes/ScaryHumanoidModel.tscn")
		print("Saved ScaryHumanoidModel.tscn, code:", save_err)
	else:
		printerr("Failed to pack scene, error:", pack_err)
