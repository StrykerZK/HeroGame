extends Node

signal score_updated(int)

var current_player_number: int = 0
var player_class: Enums.PlayerClass = Enums.PlayerClass.UNASSIGNED

var score_info: Dictionary = { }
var total_score: float = 0
var checkpoint_1: Dictionary = {
	"amount"  = 6000.0,
	"is_met" = false
}
var checkpoint_2: Dictionary = {
	"amount" = 2000.0,
	"is_met" = false
}
var checkpoint_3: Dictionary = {
	"amount" = 10000.0,
	"is_met" = false
	}

# Assign multiplayer_authority player to calculate score
func assign_player(number: int):
	current_player_number = number
	player_class = PlayerManager.player_list[number - 1].player_class

func update_score():
	
	match player_class:
		# Hero Scoring
		Enums.PlayerClass.HERO:
			total_score += score_info["happiness"] * 100
			total_score += score_info["infrastructure"] * 200
			# Other scores
		Enums.PlayerClass.VILLAIN:
			total_score += score_info["happiness"] * 100
			total_score += score_info["infrastructure"] * 200
			# Other scores
	
	score_updated.emit(total_score)
	match_checkpoint()

func match_checkpoint():
	if checkpoint_1.is_met == true:
		if checkpoint_2.is_met == true:
			if checkpoint_3.is_met == true:
				return
			else:
				if total_score > checkpoint_3.amount: checkpoint_3.is_met = true
		else:
			if total_score > checkpoint_2.amount: checkpoint_2.is_met = true
	else:
		if total_score > checkpoint_1.amount: checkpoint_1.is_met = true

func get_total_score() -> int:
	return int(total_score)
