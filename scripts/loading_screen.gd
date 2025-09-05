extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func _ready():
	hide() # Start hidden

func update_progress(percentage: float, message: String):
	progress_bar.value = percentage
	label.text = message

func show_screen(initial_message: String):
	update_progress(0, initial_message)
	show()

func hide_screen():
	hide()
