extends Node

# --- CONFIGURATION ---
# These are the distances at which the LOD levels will switch.
# You can tweak these values to fit your game's scale.
const LOD1_DISTANCE_SQ := 202500.0   # 50 units (50*50*100)
const LOD2_DISTANCE_SQ := 640000.0  # 80 units (80*80*100)

# How often, in seconds, the manager should check distances and update LODs.
# A value between 0.1 and 0.5 is usually good.
const UPDATE_INTERVAL := 0.25

# --- INTERNAL VARIABLES ---
var lod_buildings: Array[Node3D] = []
var player_node: Node3D = null
var update_timer: float = 0.0

func _process(delta: float):
	# This timer ensures the main update logic doesn't run every single frame,
	# which is much better for performance.
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_lods()

# --- PUBLIC FUNCTIONS ---

# The CityGenerator will call this to add a new building to the manager's list.
func register_building(building: Node3D):
	lod_buildings.append(building)

# The player's script should call this in its _ready() function.
func register_player(player: Node3D):
	if player.is_multiplayer_authority():
		player_node = player

# Call this if you ever clear the city, to prevent errors.
func clear_buildings():
	lod_buildings.clear()

# --- PRIVATE LOGIC ---

func _update_lods():
	# If there's no player or no buildings, there's nothing to do.
	if not is_instance_valid(player_node) or lod_buildings.is_empty():
		return

	var player_pos = player_node.global_position

	# Create a temporary array to hold buildings that might need to be removed.
	var buildings_to_remove = []

	for building in lod_buildings:
		# First, check if the building is still valid (it might have been destroyed).
		if not is_instance_valid(building):
			buildings_to_remove.append(building)
			continue

		# Calculate the squared distance. This is much faster than a regular
		# distance check because it avoids a costly square root calculation.
		var dist_sq = player_pos.distance_squared_to(building.global_position)
		
		var new_lod_level = 0 # Default to highest detail
		if dist_sq > LOD2_DISTANCE_SQ:
			new_lod_level = 2 # Low detail
		elif dist_sq > LOD1_DISTANCE_SQ:
			new_lod_level = 1 # Medium detail
		
		# Command the building to update its appearance.
		if building.has_method("set_lod_level"):
			building.set_lod_level(new_lod_level)

	# Clean up any invalid buildings from the main list.
	for building in buildings_to_remove:
		lod_buildings.erase(building)
