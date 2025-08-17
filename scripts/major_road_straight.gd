# MajorRoadStraight.gd
# Attach this script to the root node of your new "smart" major road scene.

@tool
extends Node3D

# --- EXPORT VARIABLES ---
# In the Godot editor, drag the corresponding MeshInstance3D nodes from your
# scene tree into these slots.
@export_group("Mesh Components")
@export var left_pavement: MeshInstance3D
@export var left_yellow_line: MeshInstance3D
@export var left_dotted_line: MeshInstance3D
@export var right_pavement: MeshInstance3D
@export var right_yellow_line: MeshInstance3D
@export var right_dotted_line: MeshInstance3D

# This enum defines the possible types of lanes this scene can represent.
# The CityGenerator will tell the scene which type to be.
enum LaneType {
	EDGE,        # For 2-lane roads (curb + median)
	FAR_EDGE,    # Curb lane for 3+ lane roads
	MIDDLE,      # Lane between two same-direction lanes
	BORDER       # Lane next to opposite-direction traffic
}

# --- PUBLIC FUNCTIONS ---

# The CityGenerator will call this function immediately after instantiating the scene.
func setup_lane(type: LaneType):
	# First, hide all the optional mesh parts.
	_hide_all_meshes()

	# Based on the type provided by the generator, show the correct meshes.
	match type:
		LaneType.EDGE:
			# A 2-lane road has pavement on one side and a yellow line on the other.
			if left_pavement: left_pavement.show()
			if right_yellow_line: right_yellow_line.show()
		
		LaneType.FAR_EDGE:
			# The outer lane of a wide road has pavement and a dotted line.
			if left_pavement: left_pavement.show()
			if right_dotted_line: right_dotted_line.show()
			
		LaneType.MIDDLE:
			# A middle lane has dotted lines on both sides.
			if left_dotted_line: left_dotted_line.show()
			if right_dotted_line: right_dotted_line.show()
			
		LaneType.BORDER:
			# The lane next to oncoming traffic has a dotted line and a yellow line.
			if left_dotted_line: left_dotted_line.show()
			if right_yellow_line: right_yellow_line.show()

# --- HELPER FUNCTIONS ---

func _hide_all_meshes():
	# Helper to ensure we start with a clean slate.
	if left_pavement: left_pavement.hide()
	if left_yellow_line: left_yellow_line.hide()
	if left_dotted_line: left_dotted_line.hide()
	if right_pavement: right_pavement.hide()
	if right_yellow_line: right_yellow_line.hide()
	if right_dotted_line: right_dotted_line.hide()
