# CityGenerator.gd
# Attach this script to a Node3D in your main scene.

@tool
extends Node3D

## --- SIGNALS ---
signal progress_updated(percentage, message)

## --- EXPORT VARIABLES ---
@export_group("Grid Settings")
@export var grid_size := Vector2i(50, 50)
@export var cell_size := 10.0
@export_subgroup("Chunk Settings")
@export var chunk_size := Vector2i(16, 16)

@export_group("Priority Zone Clusters")
# High Priority
@export_subgroup("Downtown District")
@export var downtown_cluster_count := 1
@export var downtown_cluster_size := Vector2i(15, 25)
@export_subgroup("Business District")
@export var business_cluster_count := 2
@export var business_cluster_size := Vector2i(10, 20)
@export_subgroup("Wealthy Residential District")
@export var wealthy_cluster_count := 1
@export var wealthy_cluster_size := Vector2i(15, 25)
# Medium Priority
@export_subgroup("Hospital")
@export var hospital_cluster_count := 1
@export var hospital_cluster_size := Vector2i(6, 10)
@export_subgroup("Police Department")
@export var police_cluster_count := 1
@export var police_cluster_size := Vector2i(4, 6)
@export_subgroup("Fire Department")
@export var fire_cluster_count := 1
@export var fire_cluster_size := Vector2i(4, 6)
@export_subgroup("Government District")
@export var government_cluster_count := 1
@export var government_cluster_size := Vector2i(8, 12)
@export_subgroup("University")
@export var university_cluster_count := 1
@export var university_cluster_size := Vector2i(10, 18)
# Low Priority
@export_subgroup("Sports Complex")
@export var sports_cluster_count := 1
@export var sports_cluster_size := Vector2i(10, 15)
@export_subgroup("Entertainment District")
@export var entertainment_cluster_count := 2
@export var entertainment_cluster_size := Vector2i(8, 16)
@export_subgroup("Technology District")
@export var technology_cluster_count := 1
@export var technology_cluster_size := Vector2i(12, 20)
@export_subgroup("Commercial District")
@export var commercial_cluster_count := 3
@export var commercial_cluster_size := Vector2i(8, 15)
@export_subgroup("Food District")
@export var food_cluster_count := 4
@export var food_cluster_size := Vector2i(6, 12)
@export_subgroup("Industrial District")
@export var industrial_cluster_count := 2
@export var industrial_cluster_size := Vector2i(10, 20)
@export_subgroup("Main Parks")
@export var park_cluster_count := 6
@export var park_cluster_size := Vector2i(9, 25)


@export_group("Filler Zone Settings")
@export var min_residential_area_size := 2
@export var min_dead_zone_to_park_size := 3
@export_range(5, 50, 1) var apartment_max_distance_from_core := 15 # NEW

@export_group("Priority Zone Fill Settings")
@export var max_large_buildings_per_zone := 3
@export var single_buildings_per_zone := 1
@export var plaza_size := Vector2i(3, 2)

@export_group("Layout Settings")
@export var major_road_count_horizontal := Vector2i(1, 2)
@export var major_road_count_vertical := Vector2i(1, 2)
@export var major_road_width := 2
@export var min_major_road_spacing := 5
@export var minor_road_from_major_chance := 0.25
@export var minor_road_from_edge_count := 15
@export var minor_road_min_straight_length := 6
@export var minor_road_max_length := 25
@export_subgroup("Variety")
@export var enforce_variety_in_standard_zones := true
@export_range(1, 5, 1) var min_variety_distance := 2

@export_group("Scene Assignments")
@export_subgroup("Priority Buildings")
@export var downtown_buildings: Array[PackedScene]
@export var business_buildings: Array[PackedScene]
@export var wealthy_residential_buildings: Array[PackedScene]
@export var commercial_buildings: Array[PackedScene]
@export var entertainment_buildings: Array[PackedScene]
@export var food_buildings: Array[PackedScene]
@export var technology_buildings: Array[PackedScene]
@export var government_buildings: Array[PackedScene]
@export var hospital_buildings: Array[PackedScene]
@export var police_buildings: Array[PackedScene]
@export var fire_buildings: Array[PackedScene]
@export var sports_buildings: Array[PackedScene]
@export var university_buildings: Array[PackedScene]
@export var industrial_buildings: Array[PackedScene]
@export_subgroup("Standard Buildings & Objects")
@export var apartment_buildings: Array[PackedScene]
@export var housing_buildings: Array[PackedScene]
@export var outskirt_objects: Array[PackedScene]
@export var water_objects: Array[PackedScene]
@export var dead_zone_objects: Array[PackedScene]
@export var walkway_objects: Array[PackedScene]
@export_subgroup("Infrastructure")
@export var road_scene: PackedScene
# Generic
@export var out_of_bounds_road_scene: PackedScene
@export var park_scene: PackedScene
@export var gate_objects: Array[Resource]

@export_group("Visualization")
@export var show_zone_colors := true
@export var downtown_color := Color.DARK_SLATE_BLUE
@export var business_color := Color.CORNFLOWER_BLUE
@export var wealthy_residential_color := Color.CRIMSON
@export var hospital_color := Color.WHITE
@export var police_color := Color.BLUE
@export var fire_color := Color.DARK_RED
@export var government_color := Color.SLATE_GRAY
@export var university_color := Color.CHOCOLATE
@export var sports_color := Color.SEA_GREEN
@export var entertainment_color := Color.MEDIUM_PURPLE
@export var technology_color := Color.AQUAMARINE
@export var commercial_color := Color.YELLOW_GREEN
@export var food_color := Color.ORANGE
@export var industrial_color := Color.DARK_SLATE_GRAY
@export var apartment_color := Color.GOLDENROD
@export var housing_color := Color.DARK_GOLDENROD
@export var outskirt_color := Color.SANDY_BROWN
@export var water_color := Color.DEEP_SKY_BLUE
@export var road_color := Color.DIM_GRAY
@export var park_color := Color.FOREST_GREEN
@export var walkway_color := Color.LIGHT_GRAY
@export var intersection_color := Color.PURPLE

@export_group("Generation")
@export var generate_in_editor := false:
	set(value):
		if value:
			generate_city()

# --- INTERNAL VARIABLES ---
enum Zone {
	EMPTY, PARK,
	MAJOR_ROAD, MINOR_ROAD, MAJOR_INTERSECTION,
	DOWNTOWN, BUSINESS, WEALTHY_RESIDENTIAL,
	HOSPITAL, POLICE, FIRE, GOVERNMENT, UNIVERSITY,
	SPORTS, ENTERTAINMENT, TECHNOLOGY, COMMERCIAL, FOOD, INDUSTRIAL,
	APARTMENTS, HOUSING, OUTSKIRT, WATER, WALKWAY
}
enum Direction { NONE, UP, DOWN, LEFT, RIGHT }
var road_direction_data: Dictionary = {}
var road_info_data: Dictionary = {}
var road_lane_index_data: Dictionary = {}
var grid_data: Dictionary = {}
var collision_chunks: Dictionary = {}
var generated_city_node: Node3D
var global_placement_counts: Dictionary = {}
var building_data_cache: Dictionary = {}
var road_network_body: StaticBody3D

# --- CORE FUNCTIONS ---
func _ready():
	# Don't auto-generate in the editor on load, only on checkbox click.
	if not Engine.is_editor_hint():
		# We now call it like this so it doesn't block the _ready function.
		generate_city.call_deferred()

func generate_city():
	emit_signal("progress_updated", 0.0, "Starting Generation...")
	await get_tree().process_frame # Allow UI to show up

	print("Starting procedural city generation...")
	_clear_city()
	global_placement_counts.clear()

	_cache_all_building_data()

	generated_city_node = Node3D.new()
	generated_city_node.name = "GeneratedCity"
	add_child(generated_city_node)

	road_network_body = StaticBody3D.new()
	road_network_body.name = "RoadNetworkCollision"
	_apply_world_collision_detection(road_network_body)
	generated_city_node.add_child(road_network_body)

	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		generated_city_node.owner = get_tree().edited_scene_root

	# --- Progress Updates Added ---
	emit_signal("progress_updated", 10.0, "Generating Road Layout...")
	await get_tree().process_frame
	_generate_layout()

	emit_signal("progress_updated", 50.0, "Placing Objects and Buildings...")
	await get_tree().process_frame
	_place_objects()

	emit_signal("progress_updated", 95.0, "Finalizing...")
	await get_tree().process_frame
	_generate_floor_collision()

	emit_signal("progress_updated", 100.0, "Complete!")
	await get_tree().process_frame

	print("City generation complete.")



# --- LAYOUT GENERATION ---
func _generate_layout():
	_generate_roads()
	
	# --- NEW: Pre-calculate potential starting points ---
	var road_adjacent_empties = _get_all_road_adjacent_empty_cells()
	road_adjacent_empties.shuffle() # Shuffle once here

	# Pass the pre-calculated list to the zone generation functions
	_generate_main_priority_zones(road_adjacent_empties)
	_generate_essential_service_zones(road_adjacent_empties)
	_generate_secondary_priority_zones(road_adjacent_empties)
	
	_fill_remaining_space()

func _generate_roads():
	var used_y: Array[int] = []
	var used_x: Array[int] = []
	
	var horizontal_roads_to_build = randi_range(major_road_count_horizontal.x, major_road_count_horizontal.y)
	var vertical_roads_to_build = randi_range(major_road_count_vertical.x, major_road_count_vertical.y)
	
	# --- Horizontal Roads ---
	var margin_y = max(major_road_width, int(grid_size.y * 0.2))
	var min_y_range = margin_y
	var max_y_range = grid_size.y - margin_y - major_road_width

	if min_y_range <= max_y_range:
		for i in range(horizontal_roads_to_build):
			var y_coord: int
			var attempts = 0
			while attempts < 20:
				y_coord = randi_range(min_y_range, max_y_range)
				var is_too_close = false
				for used_y_coord in used_y:
					if abs(y_coord - used_y_coord) < min_major_road_spacing:
						is_too_close = true
						break
				if not is_too_close:
					_build_horizontal_major_road(y_coord, used_y)
					break
				attempts += 1
	
	# --- Vertical Roads ---
	var margin_x = max(major_road_width, int(grid_size.x * 0.2))
	var min_x_range = margin_x
	var max_x_range = grid_size.x - margin_x - major_road_width

	if min_x_range <= max_x_range:
		for i in range(vertical_roads_to_build):
			var x_coord: int
			var attempts = 0
			while attempts < 20:
				x_coord = randi_range(min_x_range, max_x_range)
				var is_too_close = false
				for used_x_coord in used_x:
					if abs(x_coord - used_x_coord) < min_major_road_spacing:
						is_too_close = true
						break
				if not is_too_close:
					_build_vertical_major_road(x_coord, used_x)
					break
				attempts += 1
	
	_generate_minor_roads()

# ADDED: Helper function to build a horizontal major road
func _build_horizontal_major_road(y_coord: int, used_y: Array):
	for lane_offset in range(major_road_width):
		used_y.append(y_coord + lane_offset)
	
	for x in range(grid_size.x):
		for lane in range(major_road_width):
			var pos = Vector2i(x, y_coord + lane)
			# Assign zone
			if grid_data.get(pos) == Zone.MAJOR_ROAD:
				grid_data[pos] = Zone.MAJOR_INTERSECTION
			else:
				grid_data[pos] = Zone.MAJOR_ROAD
			# Assign direction
			if lane < major_road_width / 2.0:
				road_direction_data[pos] = Direction.LEFT
			else:
				road_direction_data[pos] = Direction.RIGHT
			
			road_lane_index_data[pos] = lane

# ADDED: Helper function to build a vertical major road
func _build_vertical_major_road(x_coord: int, used_x: Array):
	for lane_offset in range(major_road_width):
		used_x.append(x_coord + lane_offset)

	for y in range(grid_size.y):
		for lane in range(major_road_width):
			var pos = Vector2i(x_coord + lane, y)
			# Assign zone
			if grid_data.get(pos) == Zone.MAJOR_ROAD or grid_data.get(pos) == Zone.MAJOR_INTERSECTION:
				grid_data[pos] = Zone.MAJOR_INTERSECTION
			else:
				grid_data[pos] = Zone.MAJOR_ROAD
			# Assign direction
			if lane < major_road_width / 2.0:
				road_direction_data[pos] = Direction.DOWN
			else:
				road_direction_data[pos] = Direction.UP
			
			road_lane_index_data[pos] = lane

func _generate_minor_roads():
	for i in range(minor_road_from_edge_count):
		var edge = randi_range(0, 3)
		var start_pos: Vector2i
		var direction: Vector2i
		match edge:
			0: start_pos = Vector2i(randi_range(0, grid_size.x - 1), 0); direction = Vector2i.DOWN
			1: start_pos = Vector2i(randi_range(0, grid_size.x - 1), grid_size.y - 1); direction = Vector2i.UP
			2: start_pos = Vector2i(0, randi_range(0, grid_size.y - 1)); direction = Vector2i.RIGHT
			3: start_pos = Vector2i(grid_size.x - 1, randi_range(0, grid_size.y - 1)); direction = Vector2i.LEFT
		if not _is_road(start_pos): _build_l_road(start_pos, direction)

	var all_road_tiles = grid_data.keys()
	for road_pos in all_road_tiles:
		if grid_data.get(road_pos) == Zone.MAJOR_ROAD and randf() < minor_road_from_major_chance:
			var is_horizontal = _is_road(road_pos + Vector2i.LEFT) or _is_road(road_pos + Vector2i.RIGHT)
			var direction = Vector2i.UP if randi() % 2 == 0 else Vector2i.DOWN if is_horizontal else Vector2i.LEFT if randi() % 2 == 0 else Vector2i.RIGHT
			if not _is_road(road_pos + direction): _build_l_road(road_pos, direction)

func _build_l_road(start_pos: Vector2i, direction: Vector2i):
	var current_pos = start_pos
	
	var straight_length = randi_range(minor_road_min_straight_length, minor_road_max_length / 2)
	var ortho_dir = Vector2i(-direction.y, direction.x)

	for i in range(straight_length):
		var next_pos = current_pos + direction
		if not Rect2i(Vector2i.ZERO, grid_size).has_point(next_pos) or _is_road(next_pos): return
		if _is_road(next_pos + ortho_dir) or _is_road(next_pos - ortho_dir): return
		current_pos = next_pos
		grid_data[current_pos] = Zone.MINOR_ROAD

	var turn_direction = Vector2i(-direction.y, direction.x) if randi() % 2 == 0 else Vector2i(direction.y, -direction.x)
	var ortho_turn_dir = Vector2i(-turn_direction.y, turn_direction.x)
	var turn_length = minor_road_max_length - straight_length

	for i in range(turn_length):
		var next_pos = current_pos + turn_direction
		if not Rect2i(Vector2i.ZERO, grid_size).has_point(next_pos) or _is_road(next_pos): return
		if _is_road(next_pos + ortho_turn_dir) or _is_road(next_pos - ortho_turn_dir): return
		current_pos = next_pos
		grid_data[current_pos] = Zone.MINOR_ROAD

func _is_road(pos: Vector2i) -> bool:
	var zone = grid_data.get(pos)
	return zone == Zone.MAJOR_ROAD or zone == Zone.MINOR_ROAD or zone == Zone.MAJOR_INTERSECTION

func _is_major_road(pos: Vector2i) -> bool:
	var zone = grid_data.get(pos)
	return zone == Zone.MAJOR_ROAD or zone == Zone.MAJOR_INTERSECTION

func _is_walkway(pos: Vector2i) -> bool:
	return grid_data.get(pos) == Zone.WALKWAY

func _generate_main_priority_zones(road_adjacent_empties: Array[Vector2i]):
	_place_area_clusters(Zone.DOWNTOWN, downtown_cluster_count, downtown_cluster_size.x, downtown_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.BUSINESS, business_cluster_count, business_cluster_size.x, business_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.WEALTHY_RESIDENTIAL, wealthy_cluster_count, wealthy_cluster_size.x, wealthy_cluster_size.y, road_adjacent_empties)

func _generate_essential_service_zones(road_adjacent_empties: Array[Vector2i]):
	_place_area_clusters(Zone.HOSPITAL, hospital_cluster_count, hospital_cluster_size.x, hospital_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.POLICE, police_cluster_count, police_cluster_size.x, police_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.FIRE, fire_cluster_count, fire_cluster_size.x, fire_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.GOVERNMENT, government_cluster_count, government_cluster_size.x, government_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.UNIVERSITY, university_cluster_count, university_cluster_size.x, university_cluster_size.y, road_adjacent_empties)

func _generate_secondary_priority_zones(road_adjacent_empties: Array[Vector2i]):
	_place_area_clusters(Zone.SPORTS, sports_cluster_count, sports_cluster_size.x, sports_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.ENTERTAINMENT, entertainment_cluster_count, entertainment_cluster_size.x, entertainment_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.TECHNOLOGY, technology_cluster_count, technology_cluster_size.x, technology_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.COMMERCIAL, commercial_cluster_count, commercial_cluster_size.x, commercial_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.FOOD, food_cluster_count, food_cluster_size.x, food_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.INDUSTRIAL, industrial_cluster_count, industrial_cluster_size.x, industrial_cluster_size.y, road_adjacent_empties)
	_place_area_clusters(Zone.PARK, park_cluster_count, park_cluster_size.x, park_cluster_size.y, road_adjacent_empties)

func _add_collision_to_chunk(instance: Node3D):
	# 1. Validate the incoming instance and its metadata
	if not is_instance_valid(instance):
		printerr("Aborting collision chunking: provided instance is not valid.")
		return
	if not instance.has_meta("grid_position"):
		var scene_path = instance.scene_file_path if instance.scene_file_path else "[dynamic instance]"
		printerr("Aborting collision chunking: instance is missing 'grid_position' metadata. Scene path: %s" % scene_path)
		return
		
	var grid_pos = instance.get_meta("grid_position")
	if not grid_pos is Vector2i:
		printerr("Aborting collision chunking: 'grid_position' metadata is not a Vector2i.")
		return
		
	var chunk_coord = grid_pos / chunk_size

	# 2. Get or create the StaticBody3D for this chunk
	var chunk_body: StaticBody3D
	
	if not collision_chunks.has(chunk_coord):
		chunk_body = StaticBody3D.new()
		chunk_body.name = "CollisionChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
		var chunk_world_pos = Vector3(chunk_coord.x * chunk_size.x * cell_size, 0, chunk_coord.y * chunk_size.y * cell_size)
		chunk_body.position = chunk_world_pos
		generated_city_node.add_child(chunk_body)
		collision_chunks[chunk_coord] = chunk_body
	else:
		chunk_body = collision_chunks[chunk_coord]

	if not is_instance_valid(chunk_body):
		printerr("FATAL: chunk_body is null after creation/retrieval for chunk: %s" % chunk_coord)
		return

	# 3. Find all collision shapes and add them to the chunk using the Godot 4 API
	for shape_node in instance.find_children("*", "CollisionShape3D"):
		if shape_node.is_in_group("collision_for_chunking"):
			if shape_node.shape:
				# Step A: Create a new shape owner for this specific shape.
				var owner_id = chunk_body.create_shape_owner(shape_node)
				
				# Step B: Calculate the shape's transform relative to the chunk body.
				var shape_global_transform = shape_node.global_transform
				var local_transform = chunk_body.global_transform.affine_inverse() * shape_global_transform
				
				# Step C: Set the transform for the new owner.
				chunk_body.shape_owner_set_transform(owner_id, local_transform)

				# Step D: Add the shape to the new owner.
				chunk_body.shape_owner_add_shape(owner_id, shape_node.shape.duplicate())
			
			# The original CollisionShape3D node is now redundant.
			shape_node.queue_free()

# --- MODIFIED FUNCTION ---
func _place_area_clusters(zone_type: Zone, count: int, min_size: int, max_size: int, road_adjacent_empties: Array[Vector2i]):
	if count <= 0: return

	var clusters_placed = 0
	
	# --- PASS 1: Organic Placement (No changes needed here) ---
	var available_starts: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if not grid_data.has(pos):
				available_starts.append(pos)
	
	available_starts.shuffle()

	for start_pos in available_starts:
		if clusters_placed >= count: break 

		if not grid_data.has(start_pos):
			var cluster_tiles = _grow_area(start_pos, min_size, max_size)
			
			if cluster_tiles.size() >= min_size:
				var is_road_adjacent = false
				for tile in cluster_tiles:
					if _is_road(tile + Vector2i.UP) or _is_road(tile + Vector2i.DOWN) or _is_road(tile + Vector2i.LEFT) or _is_road(tile + Vector2i.RIGHT):
						is_road_adjacent = true
						break
				
				if is_road_adjacent:
					var can_place = true
					for tile in cluster_tiles:
						if grid_data.has(tile):
							can_place = false
							break
					
					if can_place:
						for t in cluster_tiles: grid_data[t] = zone_type
						clusters_placed += 1
						print("Successfully placed an organic ", Zone.keys()[zone_type], " district. (", clusters_placed, "/", count, ")")


	# --- PASS 2: Forced Placement (Now uses the pre-compiled list) ---
	if clusters_placed < count:
		#print("Warning: Organic placement failed for ", Zone.keys()[zone_type], ". Attempting forced placement for remaining ", count - clusters_placed, " clusters.")
		var forced_placements = 0
		for i in range(count - clusters_placed):
			if _force_place_cluster(zone_type, min_size, max_size, road_adjacent_empties):
				forced_placements += 1
			else:
				print("Error: Could not force place a ", Zone.keys()[zone_type], " district. The map may be too full or fragmented.")
				break 
		clusters_placed += forced_placements

	#print("Finished placing ", Zone.keys()[zone_type], " districts. Total placed: ", clusters_placed, " out of ", count, " requested.")


# --- NEW HELPER FUNCTION ---
# This function is more aggressive. It specifically finds empty cells next to roads
# and tries to grow a zone from there, guaranteeing road adjacency.
func _force_place_cluster(zone_type: Zone, min_size: int, max_size: int, road_adjacent_empties: Array[Vector2i]) -> bool:
	# This function is now much more efficient.
	# It iterates backwards so we can safely remove items from the list without messing up the loop index.
	for i in range(road_adjacent_empties.size() - 1, -1, -1):
		var start_pos = road_adjacent_empties[i]

		if not grid_data.has(start_pos):
			var cluster_tiles = _grow_area(start_pos, min_size, max_size)

			if cluster_tiles.size() >= min_size:
				var can_place = true
				for tile in cluster_tiles:
					if grid_data.has(tile):
						can_place = false
						break
				
				if can_place:
					for t in cluster_tiles:
						grid_data[t] = zone_type
					
					# --- IMPORTANT: Remove used tiles from the master list ---
					for tile_to_remove in cluster_tiles:
						var index = road_adjacent_empties.find(tile_to_remove)
						if index != -1:
							road_adjacent_empties.remove_at(index)
					
					#print("Successfully force-placed a ", Zone.keys()[zone_type], " district.")
					return true # Success!

	return false # We looped through all candidates and couldn't find a large enough spot.


func _grow_area(start_pos: Vector2i, min_size: int, max_size: int) -> Array[Vector2i]:
	var target_size = randi_range(min_size, max_size)
	var area_tiles: Array[Vector2i] = [start_pos]
	var frontier: Array[Vector2i] = [start_pos]
	while area_tiles.size() < target_size and not frontier.is_empty():
		var current_tile = frontier.pick_random()
		frontier.erase(current_tile)
		var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		neighbors.shuffle()
		for n_dir in neighbors:
			var neighbor_pos = current_tile + n_dir
			if Rect2i(Vector2i.ZERO, grid_size).has_point(neighbor_pos) and not grid_data.has(neighbor_pos) and not area_tiles.has(neighbor_pos):
				area_tiles.append(neighbor_pos)
				frontier.append(neighbor_pos)
				if area_tiles.size() >= target_size: return area_tiles
	return area_tiles

func _fill_remaining_space():
	_generate_residential_zones()
	_generate_outskirts_and_parks()

func _calculate_distance_grid(urban_core_tiles: Array[Vector2i]) -> Dictionary:
	var distance_grid: Dictionary = {}
	if urban_core_tiles.is_empty():
		return distance_grid

	var queue: Array[Vector2i] = urban_core_tiles.duplicate()
	var visited: Dictionary = {}

	# Initialize the queue with all core tiles, which have a distance of 0.
	for pos in queue:
		distance_grid[pos] = 0
		visited[pos] = true

	# Standard Breadth-First Search (BFS) to "flood fill" distances outwards.
	var head = 0
	while head < queue.size():
		var current_pos = queue[head]
		head += 1
		var current_dist = distance_grid[current_pos]

		for n_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_pos = current_pos + n_dir
			if Rect2i(Vector2i.ZERO, grid_size).has_point(neighbor_pos) and not visited.has(neighbor_pos):
				visited[neighbor_pos] = true
				distance_grid[neighbor_pos] = current_dist + 1
				queue.append(neighbor_pos)
				
	return distance_grid

func _generate_residential_zones():
	# First, find all the "urban core" tiles to measure distance from.
	var urban_core_tiles: Array[Vector2i] = []
	for pos in grid_data:
		var zone = grid_data.get(pos)
		if zone == Zone.DOWNTOWN or zone == Zone.BUSINESS or zone == Zone.UNIVERSITY or zone == Zone.SPORTS:
			urban_core_tiles.append(pos)

	if urban_core_tiles.is_empty():
		# Fallback: If no downtown/business, treat everything as housing
		_generate_residential_filler(Zone.HOUSING)
		return

	# --- NEW (OPTIMIZED): Pre-calculate the entire distance grid once. ---
	var distance_grid = _calculate_distance_grid(urban_core_tiles)

	# Find all empty areas adjacent to roads
	var road_adjacent_candidates: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x,y)
			if not grid_data.has(pos):
				if _is_road(pos + Vector2i.UP) or _is_road(pos + Vector2i.DOWN) or _is_road(pos + Vector2i.LEFT) or _is_road(pos + Vector2i.RIGHT):
					road_adjacent_candidates.append(pos)

	# For each area, determine if it should be apartments or housing
	var visited: Dictionary = {}
	for pos in road_adjacent_candidates:
		if not visited.has(pos):
			var area = _find_contiguous_area_from_list(pos, road_adjacent_candidates, visited)
			if area.size() >= min_residential_area_size:
				
				# --- REPLACED (OPTIMIZED): Use the pre-calculated grid for fast lookups. ---
				# The old, slow nested loop that iterated through all urban_core_tiles is gone.
				var total_min_dist = 0.0
				for tile_pos in area:
					# We just look up the value from our map. This is incredibly fast.
					total_min_dist += distance_grid.get(tile_pos, INF)
				
				var avg_dist = total_min_dist / area.size() if not area.is_empty() else INF
				# --- END REPLACEMENT ---

				# Assign the zone based on the distance (this logic is unchanged)
				var new_zone_type = Zone.APARTMENTS if avg_dist <= apartment_max_distance_from_core else Zone.HOUSING
				for tile_pos in area:
					grid_data[tile_pos] = new_zone_type

func _generate_residential_filler(zone_to_fill: Zone):
	var road_adjacent_candidates: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x,y)
			if not grid_data.has(pos):
				if _is_road(pos + Vector2i.UP) or _is_road(pos + Vector2i.DOWN) or _is_road(pos + Vector2i.LEFT) or _is_road(pos + Vector2i.RIGHT):
					road_adjacent_candidates.append(pos)
	var visited: Dictionary = {}
	for pos in road_adjacent_candidates:
		if not visited.has(pos):
			var area = _find_contiguous_area_from_list(pos, road_adjacent_candidates, visited)
			if area.size() >= min_residential_area_size:
				for tile_pos in area: grid_data[tile_pos] = zone_to_fill

func _generate_outskirts_and_parks():
	var visited: Dictionary = {}
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if not visited.has(pos) and not grid_data.has(pos):
				var area = _find_contiguous_empty_area(pos, visited)
				var is_outskirt = false
				for tile_pos in area:
					if tile_pos.x == 0 or tile_pos.x == grid_size.x - 1 or tile_pos.y == 0 or tile_pos.y == grid_size.y - 1:
						is_outskirt = true
						break
				if is_outskirt:
					for tile_pos in area: grid_data[tile_pos] = Zone.OUTSKIRT
				elif area.size() >= min_dead_zone_to_park_size:
					for tile_pos in area: grid_data[tile_pos] = Zone.PARK
				else:
					for tile_pos in area: grid_data[tile_pos] = Zone.EMPTY

func _find_contiguous_empty_area(start_pos: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var area_tiles: Array[Vector2i] = []; var frontier: Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	while not frontier.is_empty():
		var current_pos = frontier.pop_front(); area_tiles.append(current_pos)
		for n_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_pos = current_pos + n_dir
			if Rect2i(Vector2i.ZERO, grid_size).has_point(neighbor_pos) and not visited.has(neighbor_pos) and not grid_data.has(neighbor_pos):
				visited[neighbor_pos] = true; frontier.append(neighbor_pos)
	return area_tiles

func _find_contiguous_area_from_list(start_pos: Vector2i, candidate_list: Array[Vector2i], visited: Dictionary) -> Array[Vector2i]:
	var area_tiles: Array[Vector2i] = []; var frontier: Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	while not frontier.is_empty():
		var current_pos = frontier.pop_front(); area_tiles.append(current_pos)
		for n_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_pos = current_pos + n_dir
			if not visited.has(neighbor_pos) and candidate_list.has(neighbor_pos):
				visited[neighbor_pos] = true; frontier.append(neighbor_pos)
	return area_tiles


# --- OBJECT PLACEMENT ---
func _place_objects():
	var occupied_cells: Dictionary = {}
	var visited_priority_tiles: Dictionary = {}
	
	print("Placing entire road network...")
	_place_road_network(occupied_cells)
	print("...Road network placement complete.")

	var placements_to_make: Array[Dictionary] = []

	var priority_order = [
		Zone.DOWNTOWN, Zone.BUSINESS, Zone.WEALTHY_RESIDENTIAL,
		Zone.HOSPITAL, Zone.POLICE, Zone.FIRE, Zone.GOVERNMENT, Zone.UNIVERSITY,
		Zone.SPORTS, Zone.ENTERTAINMENT, Zone.TECHNOLOGY, Zone.COMMERCIAL, Zone.FOOD, Zone.INDUSTRIAL
	]
	
	for zone_type in priority_order:
		for grid_pos in grid_data:
			if grid_data.get(grid_pos) == zone_type and not visited_priority_tiles.has(grid_pos):
				var district_tiles = _find_contiguous_zone_area(grid_pos, zone_type, visited_priority_tiles)
				_populate_priority_zone(zone_type, district_tiles, occupied_cells, placements_to_make)

	var zone_pools: Dictionary = {}
	for zone_id in Zone.values():
		var typed_array: Array[Vector2i] = []
		zone_pools[zone_id] = typed_array
	for pos in grid_data: 
		if grid_data.has(pos):
			zone_pools[grid_data[pos]].append(pos)

	_populate_standard_zone(Zone.APARTMENTS, zone_pools[Zone.APARTMENTS], occupied_cells, placements_to_make)
	_populate_standard_zone(Zone.HOUSING, zone_pools[Zone.HOUSING], occupied_cells, placements_to_make)
	_populate_standard_zone(Zone.OUTSKIRT, zone_pools[Zone.OUTSKIRT], occupied_cells, placements_to_make)
	_populate_standard_zone(Zone.PARK, zone_pools[Zone.PARK], occupied_cells, placements_to_make)
	_populate_standard_zone(Zone.EMPTY, zone_pools[Zone.EMPTY], occupied_cells, placements_to_make)

	var worker_callable = Callable(self, "_building_instantiation_worker").bind(placements_to_make)
	var thread = Thread.new()
	thread.start(worker_callable)
	var all_instances = thread.wait_to_finish()
	
	var object_parent_node = Node3D.new()
	object_parent_node.name = "BuildingsAndObjects"
	
	# --- FIX: Add the parent to the scene tree BEFORE the loop ---
	generated_city_node.add_child(object_parent_node)

	for item in all_instances:
		var instance: Node3D = item["instance"]
		var grid_pos: Vector2i = item["grid_pos"]
		var footprint: Vector2i = item["footprint"]
		
		LODManager.register_structure(instance)
		
		# Now that the parent is in the tree, adding the instance here
		# also adds it to the tree immediately.
		object_parent_node.add_child(instance)
		
		# This call is now safe because the instance is in the tree.
		var has_road_collision = false
		for shape_node in instance.find_children("*", "CollisionShape3D"):
			if shape_node.is_in_group("road_collision"):
				has_road_collision = true
				break
		if not has_road_collision:
			_add_collision_to_chunk(instance)
		
		for x in range(footprint.x):
			for y in range(footprint.y):
				occupied_cells[grid_pos + Vector2i(x,y)] = instance

	# --- The parent is already added, so this line is removed from the end ---

	if show_zone_colors:
		for grid_pos in grid_data:
			var world_pos = Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)
			_create_zone_plane(world_pos, _get_zone_color(grid_data.get(grid_pos, Zone.EMPTY)))


func _populate_priority_zone(zone_type: Zone, available_tiles: Array[Vector2i], occupied_cells: Dictionary, placements_to_make: Array):
	if available_tiles.is_empty(): return
	var local_counts: Dictionary = {}
	var building_scene_list = _get_building_scenes_for_zone(zone_type)
	if building_scene_list.is_empty(): return
	var border_tiles: Array[Vector2i] = []; var inner_tiles: Array[Vector2i] = []
	for grid_pos in available_tiles:
		var is_border = false
		for n_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not available_tiles.has(grid_pos + n_dir): is_border = true; break
		if is_border: border_tiles.append(grid_pos)
		else: inner_tiles.append(grid_pos)
	var district_center := Vector2.ZERO
	if not available_tiles.is_empty():
		for tile in available_tiles: district_center += Vector2(tile)
		district_center /= available_tiles.size()
	for grid_pos in border_tiles: 
		if not occupied_cells.has(grid_pos):
			_place_walkway(grid_pos, occupied_cells, local_counts, placements_to_make)
	var landmark_scenes = building_scene_list.filter(func(s): return building_data_cache.get(s.resource_path, {"is_landmark": false}).is_landmark)
	landmark_scenes.shuffle()
	for landmark_scene in landmark_scenes:
		var data = building_data_cache[landmark_scene.resource_path]
		var path = landmark_scene.resource_path
		var max_placements = data.local_limit if data.local_limit > 0 else 999
		for i in range(max_placements):
			if data.global_limit != -1 and global_placement_counts.get(path, 0) >= data.global_limit: break 
			var placement = _find_best_fit_for_building(landmark_scene, inner_tiles, occupied_cells, district_center, zone_type, true)
			if placement.is_valid:
				placements_to_make.append({ "scene": landmark_scene, "grid_pos": placement.position, "footprint": placement.size, "rotation_y": placement.rotation_y })
				for x in range(placement.size.x):
					for y in range(placement.size.y):
						occupied_cells[placement.position + Vector2i(x,y)] = path
				_increment_counts(path, local_counts)
				_create_plaza(placement.position, placement.size, plaza_size, placement.rotation_y, occupied_cells, local_counts, placements_to_make)
			else: break
	var support_scenes = building_scene_list.filter(func(s): return not building_data_cache.get(s.resource_path, {"is_landmark": false}).is_landmark)
	_place_support_buildings(support_scenes, inner_tiles, occupied_cells, district_center, zone_type, local_counts, placements_to_make)
	for grid_pos in inner_tiles:
		if not occupied_cells.has(grid_pos): _place_walkway(grid_pos, occupied_cells, local_counts, placements_to_make)



func _place_support_buildings(scene_list: Array[PackedScene], available_tiles: Array[Vector2i], occupied_cells: Dictionary, district_center: Vector2, zone_type: Zone, local_counts: Dictionary, placements_to_make: Array):
	for scene in scene_list:
		var data = building_data_cache[scene.resource_path]
		var path = scene.resource_path
		var max_placements = data.local_limit
		if max_placements <= 0: max_placements = single_buildings_per_zone if data.size == Vector2i.ONE else max_large_buildings_per_zone
		if data.local_limit == -1: max_placements = 999
		for i in range(max_placements):
			if data.global_limit != -1 and global_placement_counts.get(path, 0) >= data.global_limit: break
			var placement = _find_best_fit_for_building(scene, available_tiles, occupied_cells, district_center, zone_type)
			if placement.is_valid:
				placements_to_make.append({ "scene": scene, "grid_pos": placement.position, "footprint": placement.size, "rotation_y": placement.rotation_y })
				for x in range(placement.size.x):
					for y in range(placement.size.y):
						occupied_cells[placement.position + Vector2i(x,y)] = path
				_increment_counts(path, local_counts)
			else: break



func _populate_standard_zone(zone_type: Zone, available_tiles: Array[Vector2i], occupied_cells: Dictionary, placements_to_make: Array):
	if available_tiles.is_empty(): return
	var scene_list: Array[PackedScene] = []
	match zone_type:
		Zone.APARTMENTS: scene_list = apartment_buildings
		Zone.HOUSING: scene_list = housing_buildings
		Zone.OUTSKIRT: scene_list = outskirt_objects
		Zone.EMPTY: scene_list = dead_zone_objects
		Zone.PARK: 
			for grid_pos in available_tiles: 
				if not occupied_cells.has(grid_pos):
					placements_to_make.append({ "scene": park_scene, "grid_pos": grid_pos, "footprint": Vector2i.ONE, "rotation_y": 0.0 })
					occupied_cells[grid_pos] = park_scene.resource_path
			return
	var tiles_to_check = available_tiles.duplicate()
	tiles_to_check.shuffle()
	for grid_pos in tiles_to_check:
		if occupied_cells.has(grid_pos): continue
		var scene = _get_random_scene(scene_list, {})
		if scene:
			var data = building_data_cache.get(scene.resource_path, {"size": Vector2i.ONE})
			var placement; var rotation = 0.0
			if zone_type == Zone.OUTSKIRT:
				var grid_center = Vector2(grid_size) / 2.0
				var dir_from_center = (Vector2(grid_pos) - grid_center).normalized()
				var angle = rad_to_deg(dir_from_center.angle())
				if angle > -45 and angle <= 45: rotation = 270 
				elif angle > 45 and angle <= 135: rotation = 180
				elif angle > 135 or angle <= -135: rotation = 90
				else: rotation = 0
				var can_place = true
				for x in range(data.size.x):
					for y in range(data.size.y):
						if occupied_cells.has(grid_pos + Vector2i(x,y)): can_place = false; break
					if not can_place: break
				if can_place: placement = {"is_valid": true, "position": grid_pos, "size": data.size, "rotation_y": rotation}
				else: placement = {"is_valid": false}
			else: 
				placement = _find_placement_at_anchor(grid_pos, scene, available_tiles, occupied_cells, Vector2(grid_size)/2.0, zone_type)
			if placement.is_valid:
				if not occupied_cells.has(placement.position):
					placements_to_make.append({ "scene": scene, "grid_pos": placement.position, "footprint": placement.size, "rotation_y": placement.rotation_y })
					for x in range(placement.size.x):
						for y in range(placement.size.y):
							occupied_cells[placement.position + Vector2i(x,y)] = scene.resource_path
					_increment_counts(scene.resource_path, {})


func _get_random_scene(scene_array: Array[PackedScene], local_counts: Dictionary) -> PackedScene:
	if scene_array.is_empty(): return null
	var available_scenes: Array[PackedScene] = []
	for scene in scene_array:
		if not scene: continue
		var path = scene.resource_path
		var data = building_data_cache.get(path)
		if data == null: continue

		var global_count = global_placement_counts.get(path, 0)
		var local_count = local_counts.get(path, 0)
		
		if (data.global_limit == -1 or global_count < data.global_limit) and \
		   (data.local_limit == -1 or local_count < data.local_limit):
			available_scenes.append(scene)
	
	if available_scenes.is_empty(): return null
	return available_scenes.pick_random()

func _increment_counts(path: String, local_counts: Dictionary):
	global_placement_counts[path] = global_placement_counts.get(path, 0) + 1
	if local_counts.has(path):
		local_counts[path] = local_counts.get(path, 0) + 1

func _create_plaza(start_pos: Vector2i, landmark_size: Vector2i, plaza_dims: Vector2i, rotation_y: float, occupied_cells: Dictionary, local_counts: Dictionary, placements_to_make: Array):
	var forward_vector = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rotation_y))
	var plaza_origin = start_pos
	var plaza_width = plaza_dims.x; var plaza_depth = plaza_dims.y
	if abs(forward_vector.x) > abs(forward_vector.z): 
		var offset_x = landmark_size.x if forward_vector.x > 0 else -plaza_width
		plaza_origin += Vector2i(offset_x, -int(plaza_width / 2.0))
	else: 
		var offset_y = landmark_size.y if forward_vector.z > 0 else -plaza_depth
		plaza_origin += Vector2i(-int(plaza_width / 2.0), offset_y)
	for x in range(plaza_width):
		for y in range(plaza_depth):
			var plaza_tile = plaza_origin + Vector2i(x,y)
			if not occupied_cells.has(plaza_tile):
				_place_walkway(plaza_tile, occupied_cells, local_counts, placements_to_make)

func _place_walkway(grid_pos: Vector2i, occupied_cells: Dictionary, local_counts: Dictionary, placements_to_make: Array):
	var scene = _get_random_scene(walkway_objects, local_counts)
	if scene:
		placements_to_make.append({ "scene": scene, "grid_pos": grid_pos, "footprint": Vector2i.ONE, "rotation_y": 0.0 })
		# --- FIX: Update both dictionaries for correct scoring and variety checks ---
		occupied_cells[grid_pos] = scene.resource_path
		grid_data[grid_pos] = Zone.WALKWAY
		_increment_counts(scene.resource_path, local_counts)

func _get_building_scenes_for_zone(zone_type: Zone) -> Array[PackedScene]:
	match zone_type:
		Zone.DOWNTOWN: return downtown_buildings
		Zone.BUSINESS: return business_buildings
		Zone.WEALTHY_RESIDENTIAL: return wealthy_residential_buildings
		Zone.COMMERCIAL: return commercial_buildings
		Zone.ENTERTAINMENT: return entertainment_buildings
		Zone.FOOD: return food_buildings
		Zone.TECHNOLOGY: return technology_buildings
		Zone.GOVERNMENT: return government_buildings
		Zone.HOSPITAL: return hospital_buildings
		Zone.POLICE: return police_buildings
		Zone.FIRE: return fire_buildings
		Zone.SPORTS: return sports_buildings
		Zone.UNIVERSITY: return university_buildings
		Zone.INDUSTRIAL: return industrial_buildings
		_: return []

func _get_all_road_adjacent_empty_cells() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if not grid_data.has(pos): # Is it empty?
				# Check neighbors for a road
				if _is_road(pos + Vector2i.UP) or \
				   _is_road(pos + Vector2i.DOWN) or \
				   _is_road(pos + Vector2i.LEFT) or \
				   _is_road(pos + Vector2i.RIGHT):
					candidates.append(pos)
	return candidates

func _find_best_fit_for_building(scene: PackedScene, area_tiles: Array[Vector2i], occupied_cells: Dictionary, district_center: Vector2, zone_type: Zone, from_center := false) -> Dictionary:
	var valid_placements = []
	var tiles_to_check = area_tiles.duplicate()
	if not from_center: tiles_to_check.shuffle()

	for pos in tiles_to_check:
		if occupied_cells.has(pos): continue
		
		var placement = _find_placement_at_anchor(pos, scene, area_tiles, occupied_cells, district_center, zone_type)
		if placement.is_valid:
			valid_placements.append(placement)

	if valid_placements.is_empty():
		return {"is_valid": false}

	valid_placements.sort_custom(func(a, b): return a.score > b.score)
	var best_score = valid_placements[0].score
	var best_placements = valid_placements.filter(func(p): return p.score == best_score)
	
	var final_placement = best_placements.pick_random()
	final_placement["is_valid"] = true
	return final_placement

func _find_placement_at_anchor(anchor_pos: Vector2i, scene: PackedScene, area_tiles: Array[Vector2i], occupied_cells: Dictionary, district_center: Vector2, zone_type: Zone) -> Dictionary:
	var valid_placements = []
	var building_size = building_data_cache[scene.resource_path].size
	var path = scene.resource_path
	var is_priority_zone = [Zone.DOWNTOWN, Zone.BUSINESS, Zone.WEALTHY_RESIDENTIAL, Zone.HOSPITAL, Zone.POLICE, Zone.FIRE, Zone.GOVERNMENT, Zone.UNIVERSITY, Zone.SPORTS, Zone.ENTERTAINMENT, Zone.TECHNOLOGY, Zone.COMMERCIAL, Zone.FOOD, Zone.INDUSTRIAL].has(zone_type)
	for i in range(4):
		var rot = i * 90
		var current_footprint = building_size if i % 2 == 0 else Vector2i(building_size.y, building_size.x)
		var can_place = true
		for x in range(current_footprint.x):
			for y in range(current_footprint.y):
				var check_pos = anchor_pos + Vector2i(x, y)
				if not area_tiles.has(check_pos) or occupied_cells.has(check_pos):
					can_place = false; break
			if not can_place: break
		if can_place and (is_priority_zone or enforce_variety_in_standard_zones):
			for x in range(-min_variety_distance, current_footprint.x + min_variety_distance):
				for y in range(-min_variety_distance, current_footprint.y + min_variety_distance):
					if x >= 0 and x < current_footprint.x and y >= 0 and y < current_footprint.y: continue
					var neighbor_pos = anchor_pos + Vector2i(x, y)
					if occupied_cells.has(neighbor_pos):
						var neighbor_data = occupied_cells[neighbor_pos]
						# --- FIX: Add type check to prevent crash with road instances ---
						if neighbor_data is String and neighbor_data == path:
							can_place = false; break
				if not can_place: break

		if can_place:
			var score = 0
			var road_score = 0
			var walkway_score = 0
			var nearby_road_score = 0
			
			# UPDATED: Swapped logic for 90 and 270 degrees to match Godot's CCW rotation.
			if rot == 0: # Front is -Z (Up)
				for x in range(current_footprint.x):
					var check_pos = anchor_pos + Vector2i(x, -1)
					if _is_road(check_pos): road_score += 1
					elif _is_walkway(check_pos): walkway_score += 1
			elif rot == 90: # Front is -X (Left)
				for y in range(current_footprint.y):
					var check_pos = anchor_pos + Vector2i(-1, y)
					if _is_road(check_pos): road_score += 1
					elif _is_walkway(check_pos): walkway_score += 1
			elif rot == 180: # Front is +Z (Down)
				for x in range(current_footprint.x):
					var check_pos = anchor_pos + Vector2i(x, current_footprint.y)
					if _is_road(check_pos): road_score += 1
					elif _is_walkway(check_pos): walkway_score += 1
			elif rot == 270: # Front is +X (Right)
				for y in range(current_footprint.y):
					var check_pos = anchor_pos + Vector2i(current_footprint.x, y)
					if _is_road(check_pos): road_score += 1
					elif _is_walkway(check_pos): walkway_score += 1
			
			if road_score == 0 and walkway_score == 0:
				for distance in range(2, 4):
					if rot == 0:
						for x in range(current_footprint.x):
							if _is_road(anchor_pos + Vector2i(x, -distance)): nearby_road_score += 1
					elif rot == 90: # Check Left
						for y in range(current_footprint.y):
							if _is_road(anchor_pos + Vector2i(-distance, y)): nearby_road_score += 1
					elif rot == 180:
						for x in range(current_footprint.x):
							if _is_road(anchor_pos + Vector2i(x, current_footprint.y - 1 + distance)): nearby_road_score += 1
					elif rot == 270: # Check Right
						for y in range(current_footprint.y):
							if _is_road(anchor_pos + Vector2i(current_footprint.x - 1 + distance, y)): nearby_road_score += 1
					if nearby_road_score > 0: break
			
			score = road_score * 10 + walkway_score * 5 + nearby_road_score * 2
			
			if score == 0:
				var dir_to_center = (district_center - Vector2(anchor_pos)).normalized()
				var angle = rad_to_deg(dir_to_center.angle())
				var ideal_rot = 0
				# This logic correctly determines the ideal rotation to face the district center.
				if angle > -45 and angle <= 45: ideal_rot = 270 # Face Right
				elif angle > 45 and angle <= 135: ideal_rot = 180 # Face Down
				elif angle > 135 or angle <= -135: ideal_rot = 90 # Face Left
				else: ideal_rot = 0 # Face Up
				
				if rot == ideal_rot:
					score = 1

			valid_placements.append({
				"position": anchor_pos,
				"size": current_footprint,
				"rotation_y": rot,
				"score": score
			})

	if valid_placements.is_empty():
		return {"is_valid": false}

	valid_placements.sort_custom(func(a, b): return a.score > b.score)
	var best_score = valid_placements[0].score
	var best_placements = valid_placements.filter(func(p): return p.score == best_score)
	
	var final_placement = best_placements.pick_random()
	final_placement["is_valid"] = true
	return final_placement


func _create_zone_plane(pos: Vector3, color: Color):
	var plane_mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	var material = StandardMaterial3D.new()
	plane_mesh.size = Vector2(cell_size, cell_size)
	material.albedo_color = color
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	plane_mesh.material = material
	plane_mesh_instance.mesh = plane_mesh
	var offset = Vector3(cell_size / 2.0, 0, cell_size / 2.0)
	plane_mesh_instance.position = pos + offset - Vector3(0, 0.01, 0)
	generated_city_node.add_child(plane_mesh_instance)

func _clear_city():
	var old_city = find_child("GeneratedCity", false, false)
	if is_instance_valid(old_city): remove_child(old_city); old_city.free()
	if is_instance_valid(road_network_body): road_network_body.free()
	road_info_data.clear()
	road_direction_data.clear()
	road_lane_index_data.clear()
	grid_data.clear()
	collision_chunks.clear()
	LODManager.clear_structures()

func _find_contiguous_zone_area(start_pos: Vector2i, zone_type: Zone, visited: Dictionary) -> Array[Vector2i]:
	var area_tiles: Array[Vector2i] = []; var frontier: Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	while not frontier.is_empty():
		var current_pos = frontier.pop_front(); area_tiles.append(current_pos)
		for n_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_pos = current_pos + n_dir
			if Rect2i(Vector2i.ZERO, grid_size).has_point(neighbor_pos) and not visited.has(neighbor_pos) and grid_data.get(neighbor_pos) == zone_type:
				visited[neighbor_pos] = true; frontier.append(neighbor_pos)
	return area_tiles

func _get_zone_color(zone_type: Zone) -> Color:
	match zone_type:
		Zone.DOWNTOWN: return downtown_color
		Zone.BUSINESS: return business_color
		Zone.WEALTHY_RESIDENTIAL: return wealthy_residential_color
		Zone.HOSPITAL: return hospital_color
		Zone.POLICE: return police_color
		Zone.FIRE: return fire_color
		Zone.GOVERNMENT: return government_color
		Zone.UNIVERSITY: return university_color
		Zone.SPORTS: return sports_color
		Zone.ENTERTAINMENT: return entertainment_color
		Zone.TECHNOLOGY: return technology_color
		Zone.COMMERCIAL: return commercial_color
		Zone.FOOD: return food_color
		Zone.INDUSTRIAL: return industrial_color
		Zone.APARTMENTS: return apartment_color # REPLACED
		Zone.HOUSING: return housing_color     # REPLACED
		Zone.OUTSKIRT: return outskirt_color
		Zone.MAJOR_ROAD: return road_color
		Zone.MAJOR_INTERSECTION: return intersection_color
		Zone.MINOR_ROAD: return road_color
		Zone.PARK: return park_color
		Zone.WALKWAY: return walkway_color
		_: return Color.BLACK

func _cache_all_building_data():
	if not building_data_cache.is_empty(): return

	var all_scene_arrays = [
		downtown_buildings, business_buildings, wealthy_residential_buildings,
		hospital_buildings, police_buildings, fire_buildings, government_buildings, university_buildings,
		sports_buildings, entertainment_buildings, technology_buildings, commercial_buildings, food_buildings, industrial_buildings,
		apartment_buildings, housing_buildings, outskirt_objects, dead_zone_objects, walkway_objects
	]
	
	for scene_array in all_scene_arrays:
		for scene in scene_array:
			if not scene or not scene.can_instantiate(): continue
			if building_data_cache.has(scene.resource_path): continue
			
			var temp_instance = scene.instantiate()
			var data = {
				"size": temp_instance.get("size") if temp_instance.has_method("get") and "size" in temp_instance else Vector2i.ONE,
				"is_landmark": temp_instance.get("is_landmark") if temp_instance.has_method("get") and "is_landmark" in temp_instance else false,
				"global_limit": temp_instance.get("global_limit") if temp_instance.has_method("get") and "global_limit" in temp_instance else -1,
				"local_limit": temp_instance.get("local_limit") if temp_instance.has_method("get") and "local_limit" in temp_instance else -1,
			}
			building_data_cache[scene.resource_path] = data
			temp_instance.queue_free()

func _generate_floor_collision():
	var floor_body = StaticBody3D.new()
	floor_body.name = "FloorCollision"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	var map_width = grid_size.x * cell_size
	var map_depth = grid_size.y * cell_size
	
	box_shape.size = Vector3(map_width, 1, map_depth)
	collision_shape.shape = box_shape
	
	floor_body.position = Vector3(map_width / 2.0, -0.5, map_depth / 2.0)
	
	floor_body.add_child(collision_shape)
	generated_city_node.add_child(floor_body)

# --- UPDATED ROAD PLACEMENT LOGIC ---
func _place_road_network(occupied_cells: Dictionary):
	# ===================================================================
	# PASS 1: ANALYSIS - Build the road_info_data dictionary
	# ===================================================================
	for pos in grid_data.keys():
		var zone = int(grid_data.get(pos))
		
		# Check if the zone is any kind of road.
		if not (zone in [Zone.MAJOR_ROAD, Zone.MINOR_ROAD, Zone.MAJOR_INTERSECTION]):
			continue # Skip this cell if it's a building zone, park, etc.
		
		var info = {}
		info["grid_pos"] = pos
		var connections: Array[Vector2i] = []
		var is_major = (zone == Zone.MAJOR_ROAD or zone == Zone.MAJOR_INTERSECTION)
		info["is_major"] = is_major

		# --- Neighbor Analysis ---
		if _is_road(pos + Vector2i.UP): connections.append(Vector2i.UP)
		if _is_road(pos + Vector2i.RIGHT): connections.append(Vector2i.RIGHT)
		if _is_road(pos + Vector2i.DOWN): connections.append(Vector2i.DOWN)
		if _is_road(pos + Vector2i.LEFT): connections.append(Vector2i.LEFT)
		info["connections"] = connections
		
		var neighbor_positions = {}
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var check_pos = pos + dir
			if _is_road(check_pos):
				neighbor_positions[dir] = check_pos
		info["neighbor_grid_positions"] = neighbor_positions
		
		if is_major:
			# --- Major Road and Intersection Logic ---
			var major_road_type = Enums.MajorRoadType.UNKNOWN
			var scene_rotation = 0
			var lane_index = 0
			var flow_dir = road_direction_data.get(pos, Direction.NONE)
			var traffic_flow_vector = Vector2i.ZERO

			# Check for T-junction with a minor road
			var is_t_junction = false
			var is_horizontal = (flow_dir == Direction.LEFT or flow_dir == Direction.RIGHT)
			if is_horizontal:
				if grid_data.get(pos + Vector2i.UP) == Zone.MINOR_ROAD or grid_data.get(pos + Vector2i.DOWN) == Zone.MINOR_ROAD:
					is_t_junction = true
					scene_rotation = 270 if grid_data.get(pos + Vector2i.UP) == Zone.MINOR_ROAD else 90
			else: # Vertical
				if grid_data.get(pos + Vector2i.LEFT) == Zone.MINOR_ROAD or grid_data.get(pos + Vector2i.RIGHT) == Zone.MINOR_ROAD:
					is_t_junction = true
					scene_rotation = 0 if grid_data.get(pos + Vector2i.LEFT) == Zone.MINOR_ROAD else 180
			
			if is_t_junction:
				major_road_type = Enums.MajorRoadType.T_JUNCTION
			elif zone == Zone.MAJOR_INTERSECTION:
				var major_road_neighbor_count = 0
				var mask = 0
				var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				for n_dir in neighbors:
					if grid_data.get(pos + n_dir) == Zone.MAJOR_ROAD:
						match n_dir:
							Vector2i.UP: mask += 1
							Vector2i.DOWN: mask += 2
							Vector2i.LEFT: mask += 4
							Vector2i.RIGHT: mask += 8
						major_road_neighbor_count += 1
				if major_road_neighbor_count == 2:
					major_road_type = Enums.MajorRoadType.INTERSECTION_CORNER
					match mask:
						5: scene_rotation = 0
						6: scene_rotation = 90
						10: scene_rotation = 180
						9: scene_rotation = 270
				else:
					major_road_type = Enums.MajorRoadType.INTERSECTION_FILLER
			else:
				major_road_type = Enums.MajorRoadType.STRAIGHT
			
			# Determine visual rotation and lane index for STRAIGHT pieces
			if major_road_type == Enums.MajorRoadType.STRAIGHT:
				var lane_type = Enums.MajorRoadLaneType.MIDDLE # Default to middle
				var total_width = major_road_width
				
				lane_index = road_lane_index_data.get(pos, 0)
				
				if is_horizontal:
					scene_rotation = 270 if flow_dir == Direction.LEFT else 90
				else:
					scene_rotation = 0 if flow_dir == Direction.DOWN else 180
				
				# Rule 1: Check if the lane is an outer edge
				if lane_index == 0 or lane_index == total_width - 1:
					lane_type = Enums.MajorRoadLaneType.EDGE
				else:
					var is_odd_width = total_width % 2 != 0
					# Rule 2: Handle odd-width roads
					if is_odd_width:
						var center_index = int(total_width / 2)
						if lane_index == center_index:
							lane_type = Enums.MajorRoadLaneType.ODD_CENTER
					# Rule 3: Handle even-width roads
					else: # is_even_width
						var center_index1 = int(total_width / 2)
						var center_index2 = center_index1 - 1
						if lane_index == center_index1 or lane_index == center_index2:
							lane_type = Enums.MajorRoadLaneType.EVEN_CENTER
				
				# Add the new information to the data package
				info["major_road_lane_type"] = lane_type
			
			# Determine traffic flow vector
			match flow_dir:
				Direction.UP: traffic_flow_vector = Vector2i.UP
				Direction.DOWN: traffic_flow_vector = Vector2i.DOWN
				Direction.LEFT: traffic_flow_vector = Vector2i.LEFT
				Direction.RIGHT: traffic_flow_vector = Vector2i.RIGHT

			info["major_road_type"] = major_road_type
			info["rotation"] = scene_rotation
			info["lane_index"] = lane_index
			info["traffic_flow"] = traffic_flow_vector
			info["major_road_width"] = major_road_width # Pass the global width for context
		else:
			# --- Minor Road Logic (using bitmask) ---
			var mask = 0
			if connections.has(Vector2i.UP): mask += 1
			if connections.has(Vector2i.RIGHT): mask += 2
			if connections.has(Vector2i.DOWN): mask += 4
			if connections.has(Vector2i.LEFT): mask += 8

			var road_type = Enums.RoadType.UNKNOWN
			var scene_rotation = 0
			match mask:
				0, 1, 2, 4, 8: road_type = Enums.RoadType.END
				3, 6, 9, 12: road_type = Enums.RoadType.CORNER
				5, 10: road_type = Enums.RoadType.STRAIGHT
				7, 11, 13, 14: road_type = Enums.RoadType.T_JUNCTION
				15: road_type = Enums.RoadType.INTERSECTION
			
			match mask:
				0, 4, 5, 7, 12, 15: scene_rotation = 0
				2, 6, 11: scene_rotation = 90
				1, 3, 13: scene_rotation = 180
				8, 9, 10, 14: scene_rotation = 270
				
			info["type"] = road_type
			info["rotation"] = scene_rotation

		road_info_data[pos] = info
	
	var worker_callable = Callable(self, "_road_instantiation_worker")
	var thread = Thread.new()
	thread.start(worker_callable)
	var results = thread.wait_to_finish()
	var all_instances = results["instances"]
	var all_collision_shapes = results["collision_shapes"]
	
	var start_time = Time.get_ticks_msec()
	
	var road_parent_node = Node3D.new()
	road_parent_node.name = "Roads"
	
	for item in all_instances:
		var instance = item["instance"]
		road_parent_node.add_child(instance) # Add to temporary node first
		occupied_cells[item["pos"]] = instance
		
		LODManager.register_structure(instance)
	
	generated_city_node.add_child(road_parent_node) # Add the parent once
	
	for shape_node in all_collision_shapes:
		if is_instance_valid(shape_node):
			shape_node.owner = null
			shape_node.reparent(road_network_body)
	
	print("Main thread processing took: ", Time.get_ticks_msec() - start_time, " ms")
	_trigger_road_neighbor_config(occupied_cells)

func _trigger_road_neighbor_config(occupied_road_cells: Dictionary):
	# This is the final pass that allows "smart" nodes to configure their neighbors.
	for pos in occupied_road_cells:
		var road_instance = occupied_road_cells[pos]
		var road_info = road_info_data.get(pos)

		if not road_info: continue

		# Check if this road piece is a "smart" junction that needs to configure its neighbors.
		var is_smart_junction = false
		var junction_type = ""
		if not road_info.is_major and (road_info.type == Enums.RoadType.T_JUNCTION or road_info.type == Enums.RoadType.INTERSECTION):
			is_smart_junction = true # Is Minor Junction
			junction_type = "MJ"
		elif road_info.is_major and road_info.major_road_type == Enums.MajorRoadType.T_JUNCTION:
			is_smart_junction = true # Is Major T_Junction
			junction_type = "MT"
		elif grid_data.get(pos) == Zone.MAJOR_INTERSECTION:
			is_smart_junction = true # Is Major Intersection
			junction_type = "MI"
		
		if is_smart_junction:
			var neighbor_positions = road_info.get("neighbor_grid_positions", {})
			var forced_direction = Vector2i.ZERO
			for direction in neighbor_positions:
				forced_direction = -direction
				var neighbor_pos = neighbor_positions[direction]
				
				# Get the actual neighbor instance from our dictionary
				var neighbor_instance = occupied_road_cells.get(neighbor_pos)
				var neighbor_info = road_info_data.get(neighbor_pos)
				var decor_type = ""
			
				if is_instance_valid(neighbor_instance) and neighbor_info:
					match junction_type:
						"MJ":
							decor_type = "Stop"
						"MT":
							decor_type = "SmallTraffic"
						"MI":
							if road_info.major_road_type == Enums.MajorRoadType.INTERSECTION_CORNER:
								match road_info.rotation:
									0, 180:
										if road_direction_data.get(neighbor_pos) == Direction.LEFT or \
										road_direction_data.get(neighbor_pos) == Direction.RIGHT: decor_type = "LargeTraffic"
									90, 270:
										if road_direction_data.get(neighbor_pos) == Direction.UP or \
										road_direction_data.get(neighbor_pos) == Direction.DOWN: decor_type = "LargeTraffic"
					
					if (!neighbor_info.is_major and neighbor_info.type == Enums.RoadType.STRAIGHT) or \
					(neighbor_info.is_major and neighbor_info.major_road_type == Enums.MajorRoadType.STRAIGHT):
						if junction_type == "MT" and neighbor_info.is_major: continue
						
						if neighbor_instance.has_method("configure_for_junction"):
							neighbor_instance.configure_for_junction(road_instance, decor_type, forced_direction)

func _road_instantiation_worker() -> Dictionary:
	var instances_to_add: Array[Dictionary] = []
	var collision_shapes_to_add: Array[CollisionShape3D] = []
	
	print("Thread started: Instantiating road scenes...")
	
	for pos in road_info_data:
		var data = road_info_data[pos]
		if not road_scene: continue
			
		var instance = road_scene.instantiate()
		
		# We set the position but DO NOT add it to the main tree here.
		var offset = Vector3(cell_size / 2.0, 0, cell_size / 2.0)
		instance.position = Vector3(pos.x * cell_size, 0, pos.y * cell_size) + offset
		
		if instance.has_method("generate_scene"):
			# We pass 'null' for the body because we can't access it from the thread.
			# The collision extraction will be handled differently.
			instance.generate_scene(data)
		
		# Collect the instance and its position to be added later.
		instances_to_add.append({"instance": instance, "pos": pos})
		
		# Extract the collision shapes and collect them.
		if instance.has_method("extract_collision_shapes"):
			var shapes = instance.extract_collision_shapes(instance.lod0_node)
			collision_shapes_to_add.append_array(shapes)
			
	print("Thread finished.")
	
	# Return all the created data in a single dictionary.
	return {
		"instances": instances_to_add,
		"collision_shapes": collision_shapes_to_add
	}

func _building_instantiation_worker(placements: Array) -> Array:
	var instances_to_add: Array[Dictionary] = []
	print("Thread started: Instantiating all building/object scenes...")

	for placement_data in placements:
		var scene: PackedScene = placement_data["scene"]
		var grid_pos: Vector2i = placement_data["grid_pos"]
		var footprint: Vector2i = placement_data["footprint"]
		var rotation_y: float = placement_data["rotation_y"]
		
		if not scene: continue
		
		var instance = scene.instantiate()
		instance.set_meta("grid_position", grid_pos)

		var offset = Vector3((footprint.x * cell_size) / 2.0, 0, (footprint.y * cell_size) / 2.0)
		var world_pos = Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size) + offset
		
		instance.position = world_pos
		instance.rotate_y(deg_to_rad(rotation_y))
		
		instances_to_add.append({
			"instance": instance,
			"grid_pos": grid_pos,
			"footprint": footprint
		})

	print("Thread finished: building instantiation complete.")
	return instances_to_add


func _apply_world_collision_detection(instance):
	instance.set_collision_layer_value(1, true)
	instance.set_collision_mask_value(1, false)
	instance.set_collision_mask_value(2, true)
	instance.set_collision_mask_value(3, true)
	instance.set_collision_mask_value(4, true)
	instance.set_collision_mask_value(6, true)

func _check_road_intersection_neighbors(pos, width) -> bool:
	if grid_data.get(pos + Vector2i.RIGHT) == Zone.MAJOR_INTERSECTION and \
	   grid_data.get(pos + Vector2i.DOWN) == Zone.MAJOR_INTERSECTION and \
	   grid_data.get(pos + Vector2i(1,1)) == Zone.MAJOR_INTERSECTION:
		if width == 2: return true
		elif grid_data.get(pos + Vector2i(2,0)) == Zone.MAJOR_INTERSECTION and \
			 grid_data.get(pos + Vector2i(0,2)) == Zone.MAJOR_INTERSECTION and \
			 grid_data.get(pos + Vector2i(2,2)) == Zone.MAJOR_INTERSECTION:
			if width == 3: return true
			elif grid_data.get(pos + Vector2i(3,0)) == Zone.MAJOR_INTERSECTION and \
				 grid_data.get(pos + Vector2i(0,3)) == Zone.MAJOR_INTERSECTION and \
				 grid_data.get(pos + Vector2i(3,3)) == Zone.MAJOR_INTERSECTION:
					if width == 4: return true
	return false
