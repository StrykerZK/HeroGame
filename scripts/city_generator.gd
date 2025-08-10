# CityGenerator.gd
# Attach this script to a Node3D in your main scene.

@tool
extends Node3D

## --- EXPORT VARIABLES ---
## These variables will appear in the Inspector panel in the Godot editor.
## You can tweak them there without changing the code.

@export_group("Grid Settings")
# The size of the city grid in cells (e.g., 50x50).
@export var grid_size := Vector2i(50, 50)
# The physical size of each grid cell in world units.
@export var cell_size := 10.0

# --- UPDATED: Restructured Zone Settings ---
@export_group("Priority Zone Clusters")
@export_subgroup("Business District")
@export var business_cluster_count := 2
@export var business_cluster_size := Vector2i(10, 20)
@export_subgroup("Wealthy Residential District")
@export var wealthy_cluster_count := 1
@export var wealthy_cluster_size := Vector2i(15, 25)
@export_subgroup("Entertainment District")
@export var entertainment_cluster_count := 2
@export var entertainment_cluster_size := Vector2i(8, 16)
@export_subgroup("Technology District")
@export var technology_cluster_count := 1
@export var technology_cluster_size := Vector2i(12, 20)
@export_subgroup("Government District")
@export var government_cluster_count := 1
@export var government_cluster_size := Vector2i(8, 12)
@export_subgroup("Commercial District")
@export var commercial_cluster_count := 3
@export var commercial_cluster_size := Vector2i(8, 15)
@export_subgroup("Food District")
@export var food_cluster_count := 4
@export var food_cluster_size := Vector2i(6, 12)
@export_subgroup("Main Parks")
@export var park_cluster_count := 6
@export var park_cluster_size := Vector2i(9, 25)

@export_group("Filler Zone Settings")
# Any contiguous empty area smaller than this will become a "dead zone".
@export var min_residential_area_size := 2
# Any dead zone with this many tiles or more will become a park.
@export var min_dead_zone_to_park_size := 3


@export_group("Layout Settings")
# The min (x) and max (y) number of horizontal major roads.
@export var major_road_count_horizontal := Vector2i(1, 2)
# The min (x) and max (y) number of vertical major roads.
@export var major_road_count_vertical := Vector2i(1, 2)
# The minimum distance between major roads on the same axis.
@export var min_major_road_spacing := 5
# The chance (0.0 to 1.0) for a minor road to branch off from a major one.
@export var minor_road_from_major_chance := 0.25
# How many minor roads should start from the map edges.
@export var minor_road_from_edge_count := 15
# The minimum number of tiles a minor road must travel straight before turning.
@export var minor_road_min_straight_length := 6
# The maximum total length of a minor road.
@export var minor_road_max_length := 25

@export_group("Scene Assignments")
# Assign your pre-made building scenes here.
@export var business_buildings: Array[PackedScene]
@export var residential_buildings: Array[PackedScene]
@export var wealthy_residential_buildings: Array[PackedScene]
@export var commercial_buildings: Array[PackedScene]
@export var entertainment_buildings: Array[PackedScene]
@export var food_buildings: Array[PackedScene]
@export var technology_buildings: Array[PackedScene]
@export var government_buildings: Array[PackedScene]
@export var outskirt_objects: Array[PackedScene] # For things like trees, rocks, etc.
@export var road_scene: PackedScene
@export var park_scene: PackedScene

@export_group("Visualization")
# If true, a colored plane will be placed under each zone for easy identification.
@export var show_zone_colors := true
@export var business_color := Color.CORNFLOWER_BLUE
@export var residential_color := Color.GOLDENROD
@export var wealthy_residential_color := Color.CRIMSON
@export var commercial_color := Color.YELLOW_GREEN
@export var entertainment_color := Color.MEDIUM_PURPLE
@export var food_color := Color.ORANGE
@export var technology_color := Color.AQUAMARINE
@export var government_color := Color.SLATE_GRAY
@export var outskirt_color := Color.SANDY_BROWN
@export var road_color := Color.DIM_GRAY
@export var park_color := Color.FOREST_GREEN

@export_group("Generation")
# A button to trigger generation from the editor.
@export var generate_in_editor := false:
	set(value):
		if value:
			generate_city()

# --- INTERNAL VARIABLES ---

enum Zone {
	EMPTY,
	ROAD,
	PARK,
	BUSINESS,
	RESIDENTIAL,
	WEALTHY_RESIDENTIAL,
	COMMERCIAL,
	ENTERTAINMENT,
	FOOD,
	TECHNOLOGY,
	GOVERNMENT,
	OUTSKIRT
}

var grid_data: Dictionary = {}
var generated_city_node: Node3D


# --- CORE FUNCTIONS ---

func _ready():
	# Don't auto-generate in the editor on load, only on checkbox click.
	if not Engine.is_editor_hint():
		generate_city()

func generate_city():
	print("Starting procedural city generation...")
	_clear_city()

	generated_city_node = Node3D.new()
	generated_city_node.name = "GeneratedCity"
	add_child(generated_city_node)

	# In the editor, set the owner of the generated content to the scene root.
	# This ensures that generated nodes are saved with the scene and handled correctly.
	if Engine.is_editor_hint():
		if get_tree() and get_tree().edited_scene_root:
			generated_city_node.owner = get_tree().edited_scene_root

	_generate_layout()
	_place_objects()

	print("City generation complete.")


# --- LAYOUT GENERATION ---

func _generate_layout():
	grid_data.clear()
	# Pass 1: Generate major and minor roads.
	_generate_roads()
	# Pass 2: Place main priority zone clusters.
	_generate_main_priority_zones()
	# Pass 3: Place secondary priority zone clusters.
	_generate_secondary_priority_zones()
	# Pass 4: Fill all remaining space with residential, outskirts, parks, and dead zones.
	_fill_remaining_space()


# --- Road Generation Overhaul ---
func _generate_roads():
	var used_y: Array[int] = []
	var used_x: Array[int] = []
	
	var horizontal_roads_to_build = randi_range(major_road_count_horizontal.x, major_road_count_horizontal.y)
	var vertical_roads_to_build = randi_range(major_road_count_vertical.x, major_road_count_vertical.y)
	
	# Create major horizontal roads (2 tiles wide)
	var margin_y = max(2, int(grid_size.y * 0.2))
	for i in range(horizontal_roads_to_build):
		var y_coord: int
		var attempts = 0
		while attempts < 20:
			y_coord = randi_range(margin_y, grid_size.y - margin_y - 2)
			var is_too_close = false
			for used_y_coord in used_y:
				if abs(y_coord - used_y_coord) < min_major_road_spacing:
					is_too_close = true
					break
			if not is_too_close:
				break
			attempts += 1
		if attempts == 20: continue # Failed to find a suitable spot

		used_y.append(y_coord)
		used_y.append(y_coord + 1)
		for x in range(grid_size.x):
			for lane in range(2):
				grid_data[Vector2i(x, y_coord + lane)] = Zone.ROAD
			
	# Create major vertical roads (2 tiles wide)
	var margin_x = max(2, int(grid_size.x * 0.2))
	for i in range(vertical_roads_to_build):
		var x_coord: int
		var attempts = 0
		while attempts < 20:
			x_coord = randi_range(margin_x, grid_size.x - margin_x - 2)
			var is_too_close = false
			for used_x_coord in used_x:
				if abs(x_coord - used_x_coord) < min_major_road_spacing:
					is_too_close = true
					break
			if not is_too_close:
				break
			attempts += 1
		if attempts == 20: continue # Failed to find a suitable spot
		
		used_x.append(x_coord)
		used_x.append(x_coord + 1)
		for y in range(grid_size.y):
			for lane in range(2):
				grid_data[Vector2i(x_coord + lane, y)] = Zone.ROAD
	
	_generate_minor_roads()

# --- Minor Road Generation System ---
func _generate_minor_roads():
	# 1. Spawn roads from the edges of the map
	for i in range(minor_road_from_edge_count):
		var edge = randi_range(0, 3) # 0: top, 1: bottom, 2: left, 3: right
		var start_pos: Vector2i
		var direction: Vector2i
		
		match edge:
			0: # Top
				start_pos = Vector2i(randi_range(0, grid_size.x - 1), 0)
				direction = Vector2i.DOWN
			1: # Bottom
				start_pos = Vector2i(randi_range(0, grid_size.x - 1), grid_size.y - 1)
				direction = Vector2i.UP
			2: # Left
				start_pos = Vector2i(0, randi_range(0, grid_size.y - 1))
				direction = Vector2i.RIGHT
			3: # Right
				start_pos = Vector2i(grid_size.x - 1, randi_range(0, grid_size.y - 1))
				direction = Vector2i.LEFT
		
		if not _is_road(start_pos):
			_build_l_road(start_pos, direction)

	# 2. Spawn roads from existing major roads
	var all_road_tiles = grid_data.keys()
	for road_pos in all_road_tiles:
		if randf() < minor_road_from_major_chance:
			var is_horizontal = _is_road(road_pos + Vector2i.LEFT) or _is_road(road_pos + Vector2i.RIGHT)
			var direction: Vector2i
			if is_horizontal:
				direction = Vector2i.UP if randi() % 2 == 0 else Vector2i.DOWN
			else:
				direction = Vector2i.LEFT if randi() % 2 == 0 else Vector2i.RIGHT
			
			if not _is_road(road_pos + direction):
				_build_l_road(road_pos, direction)

# --- Builds a simple L-shaped road with parallel checks ---
func _build_l_road(start_pos: Vector2i, direction: Vector2i):
	var current_pos = start_pos
	
	# Phase 1: Straight part
	var straight_length = randi_range(minor_road_min_straight_length, minor_road_max_length / 2)
	var left_dir = Vector2i(direction.y, -direction.x)
	var right_dir = Vector2i(-direction.y, direction.x)

	for i in range(straight_length):
		var next_pos = current_pos + direction
		
		# Stop if we go out of bounds or hit an existing road
		if not Rect2i(Vector2i.ZERO, grid_size).has_point(next_pos) or _is_road(next_pos):
			return
		
		# Check for parallel roads before placing the segment
		if _is_road(next_pos + left_dir) or _is_road(next_pos + right_dir):
			return

		current_pos = next_pos
		grid_data[current_pos] = Zone.ROAD

	# Phase 2: Turn part
	var turn_direction = Vector2i(-direction.y, direction.x) if randi() % 2 == 0 else Vector2i(direction.y, -direction.x)
	var turn_left_dir = Vector2i(turn_direction.y, -turn_direction.x)
	var turn_right_dir = Vector2i(-turn_direction.y, turn_direction.x)
	var turn_length = minor_road_max_length - straight_length

	for i in range(turn_length):
		var next_pos = current_pos + turn_direction
		
		# Stop if we go out of bounds or hit an existing road
		if not Rect2i(Vector2i.ZERO, grid_size).has_point(next_pos) or _is_road(next_pos):
			return
		
		# Check for parallel roads after turning
		if _is_road(next_pos + turn_left_dir) or _is_road(next_pos + turn_right_dir):
			return

		current_pos = next_pos
		grid_data[current_pos] = Zone.ROAD

# --- Helper to check if a tile is a road ---
func _is_road(pos: Vector2i) -> bool:
	return grid_data.get(pos) == Zone.ROAD

# --- NEW: Main Priority Zone Generation ---
func _generate_main_priority_zones():
	_place_area_clusters(Zone.PARK, park_cluster_count, park_cluster_size.x, park_cluster_size.y)
	_place_area_clusters(Zone.BUSINESS, business_cluster_count, business_cluster_size.x, business_cluster_size.y)
	_place_area_clusters(Zone.WEALTHY_RESIDENTIAL, wealthy_cluster_count, wealthy_cluster_size.x, wealthy_cluster_size.y)
	_place_area_clusters(Zone.ENTERTAINMENT, entertainment_cluster_count, entertainment_cluster_size.x, entertainment_cluster_size.y)
	_place_area_clusters(Zone.TECHNOLOGY, technology_cluster_count, technology_cluster_size.x, technology_cluster_size.y)
	_place_area_clusters(Zone.GOVERNMENT, government_cluster_count, government_cluster_size.x, government_cluster_size.y)

# --- NEW: Secondary Priority Zone Generation ---
func _generate_secondary_priority_zones():
	_place_area_clusters(Zone.COMMERCIAL, commercial_cluster_count, commercial_cluster_size.x, commercial_cluster_size.y)
	_place_area_clusters(Zone.FOOD, food_cluster_count, food_cluster_size.x, food_cluster_size.y)

func _place_area_clusters(zone_type: Zone, count: int, min_size: int, max_size: int):
	var max_attempts_per_cluster = 50
	for i in range(count):
		var attempts = 0
		while attempts < max_attempts_per_cluster:
			attempts += 1
			var start_pos = Vector2i(
				randi_range(1, grid_size.x - 2),
				randi_range(1, grid_size.y - 2)
			)
			if not grid_data.has(start_pos):
				var cluster_tiles = _grow_area(start_pos, min_size, max_size)
				if cluster_tiles.size() >= min_size:
					for tile in cluster_tiles:
						grid_data[tile] = zone_type
					break

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
				if area_tiles.size() >= target_size:
					return area_tiles
	return area_tiles

# --- UPDATED: New consolidated filler system ---
func _fill_remaining_space():
	# Pass 1: Fill residential zones adjacent to roads
	_generate_residential_filler()
	# Pass 2: Fill outskirts, parks, and dead zones in the remaining space
	_generate_outskirts_and_parks()
	
func _generate_residential_filler():
	var road_adjacent_candidates: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x,y)
			if not grid_data.has(pos):
				if _is_road(pos + Vector2i.UP) or _is_road(pos + Vector2i.DOWN) or \
				   _is_road(pos + Vector2i.LEFT) or _is_road(pos + Vector2i.RIGHT):
					road_adjacent_candidates.append(pos)

	var visited: Dictionary = {}
	for pos in road_adjacent_candidates:
		if not visited.has(pos):
			var area = _find_contiguous_area_from_list(pos, road_adjacent_candidates, visited)
			if area.size() >= min_residential_area_size:
				for tile_pos in area:
					grid_data[tile_pos] = Zone.RESIDENTIAL

func _generate_outskirts_and_parks():
	var visited: Dictionary = {}
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if not visited.has(pos) and not grid_data.has(pos):
				var area = _find_contiguous_empty_area(pos, visited)
				
				var is_outskirt = false
				for tile_pos in area:
					if tile_pos.x == 0 or tile_pos.x == grid_size.x - 1 or \
					   tile_pos.y == 0 or tile_pos.y == grid_size.y - 1:
						is_outskirt = true
						break
				if is_outskirt:
					for tile_pos in area:
						grid_data[tile_pos] = Zone.OUTSKIRT
					continue
					
				if area.size() >= min_dead_zone_to_park_size:
					for tile_pos in area:
						grid_data[tile_pos] = Zone.PARK
					continue

# --- Helper function to find contiguous empty areas using flood fill ---
func _find_contiguous_empty_area(start_pos: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var area_tiles: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start_pos]
	visited[start_pos] = true

	while not frontier.is_empty():
		var current_pos = frontier.pop_front()
		area_tiles.append(current_pos)

		var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for n_dir in neighbors:
			var neighbor_pos = current_pos + n_dir
			
			if Rect2i(Vector2i.ZERO, grid_size).has_point(neighbor_pos) and not visited.has(neighbor_pos) and not grid_data.has(neighbor_pos):
				visited[neighbor_pos] = true
				frontier.append(neighbor_pos)
	
	return area_tiles

# --- Helper function to find contiguous areas from a specific list of tiles ---
func _find_contiguous_area_from_list(start_pos: Vector2i, candidate_list: Array[Vector2i], visited: Dictionary) -> Array[Vector2i]:
	var area_tiles: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start_pos]
	visited[start_pos] = true

	while not frontier.is_empty():
		var current_pos = frontier.pop_front()
		area_tiles.append(current_pos)

		var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for n_dir in neighbors:
			var neighbor_pos = current_pos + n_dir
			
			if not visited.has(neighbor_pos) and candidate_list.has(neighbor_pos):
				visited[neighbor_pos] = true
				frontier.append(neighbor_pos)
	
	return area_tiles


# --- UPDATED: Object Placement ---
func _place_objects():
	if grid_data.is_empty():
		push_warning("Grid data is empty. Cannot place objects.")
		return

	for grid_pos in grid_data:
		var zone_type = grid_data.get(grid_pos, Zone.EMPTY) # Use .get() for safety
		var object_to_place: PackedScene
		var zone_color: Color

		match zone_type:
			Zone.ROAD:
				object_to_place = road_scene
				zone_color = road_color
			Zone.PARK:
				object_to_place = park_scene
				zone_color = park_color
			Zone.BUSINESS:
				object_to_place = _get_random_building(business_buildings)
				zone_color = business_color
			Zone.RESIDENTIAL:
				object_to_place = _get_random_building(residential_buildings)
				zone_color = residential_color
			Zone.WEALTHY_RESIDENTIAL:
				object_to_place = _get_random_building(wealthy_residential_buildings)
				zone_color = wealthy_residential_color
			Zone.COMMERCIAL:
				object_to_place = _get_random_building(commercial_buildings)
				zone_color = commercial_color
			Zone.ENTERTAINMENT:
				object_to_place = _get_random_building(entertainment_buildings)
				zone_color = entertainment_color
			Zone.FOOD:
				object_to_place = _get_random_building(food_buildings)
				zone_color = food_color
			Zone.TECHNOLOGY:
				object_to_place = _get_random_building(technology_buildings)
				zone_color = technology_color
			Zone.GOVERNMENT:
				object_to_place = _get_random_building(government_buildings)
				zone_color = government_color
			Zone.OUTSKIRT:
				object_to_place = _get_random_building(outskirt_objects)
				zone_color = outskirt_color
			_:
				continue

		var world_pos = Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

		if show_zone_colors:
			_create_zone_plane(world_pos, zone_color)

		if object_to_place:
			var instance = object_to_place.instantiate()
			instance.position = world_pos
			generated_city_node.add_child(instance)


func _create_zone_plane(pos: Vector3, color: Color):
	var plane_mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	var material = StandardMaterial3D.new()
	plane_mesh.size = Vector2(cell_size, cell_size)
	material.albedo_color = color
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	plane_mesh.material = material
	plane_mesh_instance.mesh = plane_mesh
	plane_mesh_instance.position = pos - Vector3(0, 0.01, 0)
	generated_city_node.add_child(plane_mesh_instance)


func _create_seeds(type: Zone, count: int, seed_array: Array):
	var attempts = 0
	var max_attempts = count * 20
	for i in range(count):
		while attempts < max_attempts:
			attempts += 1
			var random_pos = Vector2i(
				randi_range(0, grid_size.x - 1),
				randi_range(0, grid_size.y - 1)
			)
			if not grid_data.has(random_pos):
				seed_array.append({"pos": random_pos, "type": type})
				break


func _get_random_building(building_array: Array[PackedScene]) -> PackedScene:
	if building_array.is_empty():
		return null
	return building_array.pick_random()


func _clear_city():
	var old_city = find_child("GeneratedCity", false, false) # recursive=false, owned=false
	if is_instance_valid(old_city):
		# In the editor, we must remove and free immediately, not queue for deletion.
		# queue_free() would cause a name clash when regenerating in the same frame.
		remove_child(old_city)
		old_city.free()
	grid_data.clear()
