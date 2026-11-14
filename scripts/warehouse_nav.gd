class_name WarehouseNavRegion
extends NavigationRegion3D

## Automatically bakes or verifies the warehouse navigation mesh at startup
## so Stalker AI can navigate seamlessly around shelves, crates, and walls.

func _ready() -> void:
	if navigation_mesh == null:
		var nav_mesh = NavigationMesh.new()
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_height = 2.6
		nav_mesh.agent_max_climb = 0.3
		nav_mesh.agent_max_slope = 45.0
		navigation_mesh = nav_mesh
	
	# Bake navigation mesh in background thread on startup
	bake_navigation_mesh(true)
