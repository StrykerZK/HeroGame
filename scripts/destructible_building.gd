extends CSGCombiner3D

func take_damage(impact_position: Vector3, dmg_radius: float):
	print("Building taking damage at: ", impact_position)

	# 1. Create a new CSG shape for the hole
	var hole = CSGSphere3D.new()

	# 2. Set its properties
	hole.radius = dmg_radius * 1.5 # How big the hole should be
	
	# --- THIS IS THE CORRECTED LINE ---
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION # Make it subtractive

	# 3. Add it to the CSG tree
	add_child(hole)

	# 4. Position the hole AT the impact point.
	# The impact_position is in GLOBAL coordinates. We must convert it
	# to the LOCAL coordinate space of the csg_combiner.
	hole.global_position = impact_position
