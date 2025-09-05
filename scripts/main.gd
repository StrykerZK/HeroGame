extends Node3D

@onready var city_generator: Node3D = $CityGenerator
@onready var loading_screen: Control = $LoadingScreen

func _ready():
	# Connect the generator's signal to a new function
	city_generator.progress_updated.connect(_on_generator_progress)

	# Show the screen right before generation starts
	loading_screen.show_screen("Preparing City...")

func _on_generator_progress(percentage: float, message: String):
	loading_screen.update_progress(percentage, message)

	# Hide the screen once generation is complete
	if percentage >= 100:
		loading_screen.hide_screen()
