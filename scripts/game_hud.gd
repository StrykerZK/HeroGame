extends Control

@onready var score_label = $ScoreLabel
@onready var objective_label = $Objectivelabel

func _ready():
	GameManager.score_updated.connect(on_score_updated)
	GameManager.objective_updated.connect(on_objective_updated)
	
func on_score_updated(new_hero_score, new_villain_score):
	score_label.text = "Hero: %d | Villain: %d" % [new_hero_score, new_villain_score]

func on_objective_updated(new_text):
	objective_label.text = new_text
